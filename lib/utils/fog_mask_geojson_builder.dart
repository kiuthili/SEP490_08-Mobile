import 'dart:convert';
import 'dart:math' as dart_math;
import 'package:clipper2/clipper2.dart';

class FogMaskGeoJsonBuilder {
  // Bounding box cho Web Mercator
  static const double minLng = -180.0;
  static const double maxLng = 180.0;
  static const double minLat = -85.051129;
  static const double maxLat = 85.051129;

  static Future<Map<String, dynamic>> buildMaskIsolate(
      Map<String, dynamic> args) async {
    final int generationId = args['generationId'] as int;
    final double radius = args['radius'] as double;
    final int steps = args['steps'] as int;
    final int precision = args['precision'] as int;

    final double scale = dart_math.pow(10, precision).toDouble();

    final List<List<double>> rawFootprints =
        ((args['footprints'] as List<dynamic>?) ?? []).map((e) {
      final List<dynamic> pt = e as List<dynamic>;
      return [pt[0] as double, pt[1] as double];
    }).toList();

    List<double>? currentLocation;
    if (args['currentLocation'] != null) {
      final loc = args['currentLocation'] as List<dynamic>;
      currentLocation = [loc[0] as double, loc[1] as double];
    }

    // 0. Spatial Thinning (40m ~ 0.00036 degrees)
    final double gridSize = 0.00036;
    final Map<String, List<double>> thinnedMap = {};
    for (final fp in rawFootprints) {
      if (fp[0].isNaN || fp[1].isNaN || fp[0].isInfinite || fp[1].isInfinite)
        continue;
      final int gridX = (fp[0] / gridSize).floor();
      final int gridY = (fp[1] / gridSize).floor();
      final String key = '$gridX,$gridY';
      // Just keep one point per grid cell
      if (!thinnedMap.containsKey(key)) {
        thinnedMap[key] = fp;
      }
    }

    final List<List<double>> footprints = thinnedMap.values.toList();

    if (currentLocation != null) {
      final int gridX = (currentLocation[0] / gridSize).floor();
      final int gridY = (currentLocation[1] / gridSize).floor();
      final String key = '$gridX,$gridY';
      if (!thinnedMap.containsKey(key)) {
        footprints.add(currentLocation);
      }
    }

    // 1. Tạo Outer Mask (Toàn thế giới) bằng Point64
    final Path64 outerMask = <Point64>[];
    outerMask.add(Point64((minLng * scale).round(), (minLat * scale).round()));
    outerMask.add(Point64((maxLng * scale).round(), (minLat * scale).round()));
    outerMask.add(Point64((maxLng * scale).round(), (maxLat * scale).round()));
    outerMask.add(Point64((minLng * scale).round(), (maxLat * scale).round()));
    outerMask.add(Point64((minLng * scale).round(), (minLat * scale).round()));

    if (footprints.isEmpty) {
      return {
        "generationId": generationId,
        "geojson": jsonEncode({
          "type": "Polygon",
          "coordinates": [
            [
              [minLng, minLat],
              [maxLng, minLat],
              [maxLng, maxLat],
              [minLng, maxLat],
              [minLng, minLat]
            ]
          ]
        }),
      };
    }

    try {
      // 2. Union tất cả các footprint circles
      final Clipper64 unionClipper = Clipper64();

      for (final fp in footprints) {
        _addCircleToClipper(unionClipper, fp[0], fp[1], radius, steps, scale);
      }

      final Solution64? unionSolution =
          unionClipper.execute(ClipType.union, FillRule.nonZero);
      final Paths64 unionPaths = unionSolution?.closed ?? <Path64>[];

      // 3. Difference: Outer Mask trừ đi Union Paths
      final Clipper64 diffClipper = Clipper64();
      diffClipper.addPath(outerMask, PathType.subject);
      diffClipper.addPaths(unionPaths, PathType.clip);

      final SolutionTree64? diffSolution =
          diffClipper.executeTree(ClipType.difference, FillRule.nonZero);
      final PolyTree64? diffTree = diffSolution?.tree;

      // 4. Parse PolyTree64 sang GeoJSON chuẩn
      final Map<String, dynamic> geojson = _polyTreeToGeoJson(diffTree, scale);

      return {
        "generationId": generationId,
        "geojson": jsonEncode(geojson),
      };
    } catch (e) {
      return {
        "generationId": generationId,
        "geojson": jsonEncode({
          "type": "Polygon",
          "coordinates": [
            [
              [minLng, minLat],
              [maxLng, minLat],
              [maxLng, maxLat],
              [minLng, maxLat],
              [minLng, minLat]
            ]
          ]
        }),
        "error": e.toString(),
      };
    }
  }

  static void _addCircleToClipper(Clipper64 clipper, double lng, double lat,
      double radiusMeters, int steps, double scale) {
    if (lat < minLat ||
        lat > maxLat ||
        lng < minLng ||
        lng > maxLng ||
        lat.isNaN ||
        lng.isNaN) {
      return;
    }
    try {
      final Path64 path = <Point64>[];
      final double latRadian = lat * 3.141592653589793 / 180.0;
      final double metersPerDegreeLat = 111320.0;
      final double metersPerDegreeLng = 111320.0 * dart_math.cos(latRadian);

      final double latOffset = radiusMeters / metersPerDegreeLat;
      final double lngOffset = radiusMeters / metersPerDegreeLng;

      for (int i = 0; i < steps; i++) {
        final double angle = (i * 360.0 / steps) * 3.141592653589793 / 180.0;
        final double dy = latOffset * dart_math.sin(angle);
        final double dx = lngOffset * dart_math.cos(angle);
        path.add(Point64(
            ((lng + dx) * scale).round(), ((lat + dy) * scale).round()));
      }

      clipper.addPath(path, PathType.subject);
    } catch (_) {}
  }

  static Map<String, dynamic> _polyTreeToGeoJson(
      PolyTree64? tree, double scale) {
    if (tree == null || tree.children.isEmpty) {
      return {
        "type": "Polygon",
        "coordinates": [
          [
            [minLng, minLat],
            [maxLng, minLat],
            [maxLng, maxLat],
            [minLng, maxLat],
            [minLng, minLat]
          ]
        ]
      };
    }

    final List<List<List<List<double>>>> multiPolygonCoords = [];

    void processNode(PolyPath64 node, bool isOuter) {
      if (isOuter) {
        if (node.polygon != null && node.polygon!.isNotEmpty) {
          final outerCoords = _pathToCoords(node.polygon!, scale);
          if (outerCoords != null) {
            final List<List<List<double>>> polygonCoords = [];
            polygonCoords.add(outerCoords);

            for (final holeNode in node.children) {
              if (holeNode.polygon != null && holeNode.polygon!.isNotEmpty) {
                final holeCoords = _pathToCoords(holeNode.polygon!, scale);
                if (holeCoords != null) {
                  polygonCoords.add(holeCoords);
                }
              }
              for (final islandNode in holeNode.children) {
                processNode(islandNode, true);
              }
            }
            multiPolygonCoords.add(polygonCoords);
          }
        }
      }
    }

    for (final child in tree.children) {
      processNode(child, true);
    }

    if (multiPolygonCoords.isEmpty) {
      return {
        "type": "Polygon",
        "coordinates": [
          [
            [minLng, minLat],
            [maxLng, minLat],
            [maxLng, maxLat],
            [minLng, maxLat],
            [minLng, minLat]
          ]
        ]
      };
    }

    if (multiPolygonCoords.length == 1) {
      return {"type": "Polygon", "coordinates": multiPolygonCoords.first};
    } else {
      return {"type": "MultiPolygon", "coordinates": multiPolygonCoords};
    }
  }

  static List<List<double>>? _pathToCoords(Path64 path, double scale) {
    if (path.isEmpty) return null;

    final List<List<double>> distinctRing = [];
    for (final pt in path) {
      final double lng = pt.x / scale;
      final double lat = pt.y / scale;
      if (distinctRing.isEmpty) {
        distinctRing.add([lng, lat]);
      } else {
        final last = distinctRing.last;
        if (last[0] != lng || last[1] != lat) {
          distinctRing.add([lng, lat]);
        }
      }
    }

    if (distinctRing.length > 1 &&
        distinctRing.first[0] == distinctRing.last[0] &&
        distinctRing.first[1] == distinctRing.last[1]) {
      distinctRing.removeLast();
    }

    if (distinctRing.length < 3) return null;

    double area = 0;
    for (int i = 0; i < distinctRing.length; i++) {
      int j = (i + 1) % distinctRing.length;
      area += distinctRing[i][0] * distinctRing[j][1] -
          distinctRing[j][0] * distinctRing[i][1];
    }
    area = area.abs() / 2.0;

    if (area < 1e-12) return null;

    distinctRing.add([distinctRing.first[0], distinctRing.first[1]]);

    if (distinctRing.length < 4) return null;

    return distinctRing;
  }
}
