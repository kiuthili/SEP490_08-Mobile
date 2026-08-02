
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

class MarkerGenerator {
  /// Create a circle marker for a live location, optionally with avatar
  static Future<Uint8List> createLiveLocationMarker({String? avatarUrl}) async {
    final int size = 100;
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    final Paint borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0;

    final Paint fillPaint = Paint()..color = Colors.blue;

    final double radius = size / 2;
    final Offset center = Offset(radius, radius);

    canvas.drawCircle(center, radius - 3, fillPaint);
    canvas.drawCircle(center, radius - 3, borderPaint);

    ui.Image? avatarImg;
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      try {
        final uri = Uri.tryParse(avatarUrl);
        if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
          final response = await http.get(uri).timeout(const Duration(seconds: 3));
          if (response.statusCode == 200) {
            final codec = await ui.instantiateImageCodec(response.bodyBytes, targetWidth: size, targetHeight: size);
            final frame = await codec.getNextFrame();
            avatarImg = frame.image;
          }
        }
      } catch (_) {}
    }

    if (avatarImg != null) {
      canvas.save();
      canvas.clipPath(Path()..addOval(Rect.fromCircle(center: center, radius: radius - 6)));
      paintImage(
        canvas: canvas,
        rect: Rect.fromCircle(center: center, radius: radius - 6),
        image: avatarImg,
        fit: BoxFit.cover,
      );
      canvas.restore();
    } else {
      TextPainter painter = TextPainter(textDirection: TextDirection.ltr);
      painter.text = TextSpan(
        text: String.fromCharCode(Icons.person.codePoint),
        style: TextStyle(
          fontSize: 60,
          color: Colors.white,
          fontFamily: Icons.person.fontFamily,
          package: Icons.person.fontPackage,
        ),
      );
      painter.layout();
      painter.paint(canvas, Offset(radius - painter.width / 2, radius - painter.height / 2));
    }

    final img = await pictureRecorder.endRecording().toImage(size, size);
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }

  /// Create a cartoon cloud for Footprints
  static Future<({Uint8List data, int width, int height})>
      createCloudMarker() async {
    final int width = 120;
    final int height = 80;
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);

    final Paint fillPaint = Paint()
      ..color = const Color(0xFFC084FC)
          .withValues(alpha: 0.6) // Light purple 60% opacity
      ..style = PaintingStyle.fill;

    final Paint borderPaint = Paint()
      ..color = const Color(0xFF5B21B6).withValues(alpha: 0.8) // Dark purple
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    // Draw a simple cloud shape (composed of overlapping circles)
    canvas.drawCircle(const Offset(40, 50), 25, fillPaint);
    canvas.drawCircle(const Offset(65, 35), 30, fillPaint);
    canvas.drawCircle(const Offset(90, 50), 20, fillPaint);

    canvas.drawCircle(const Offset(40, 50), 25, borderPaint);
    canvas.drawCircle(const Offset(65, 35), 30, borderPaint);
    canvas.drawCircle(const Offset(90, 50), 20, borderPaint);

    final img = await pictureRecorder.endRecording().toImage(width, height);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    img.dispose();

    if (byteData == null) {
      throw Exception('Failed to encode cloud marker image data');
    }

    final data = byteData.buffer.asUint8List();
    if (data.length != width * height * 4) {
      throw Exception(
          'Cloud marker image byte length mismatch. Expected ${width * height * 4}, got ${data.length}');
    }

    return (data: data, width: width, height: height);
  }

  /// Create a circle with an icon (for Me marker)
  static Future<({Uint8List data, int width, int height})>
      createMeMarker() async {
    final int size = 120;
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    final Paint paint = Paint()..color = Colors.blue;
    final Paint borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8.0;

    final double radius = size / 2;
    canvas.drawCircle(Offset(radius, radius), radius - 4, paint);
    canvas.drawCircle(Offset(radius, radius), radius - 4, borderPaint);

    TextPainter painter = TextPainter(textDirection: TextDirection.ltr);
    painter.text = TextSpan(
      text: String.fromCharCode(Icons.navigation.codePoint),
      style: TextStyle(
        fontSize: 60,
        color: Colors.white,
        fontFamily: Icons.navigation.fontFamily,
        package: Icons.navigation.fontPackage,
      ),
    );
    painter.layout();
    painter.paint(canvas,
        Offset(radius - painter.width / 2, radius - painter.height / 2));

    final img = await pictureRecorder.endRecording().toImage(size, size);
    final data = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
    return (data: data!.buffer.asUint8List(), width: size, height: size);
  }

  // Helper to draw a pin with a tail
  static void _drawPinWithTail(Canvas canvas, Size size, Paint paint,
      {double radius = 12.0,
      double tailHeight = 16.0,
      double tailWidth = 24.0}) {
    final double width = size.width;
    final double height = size.height - tailHeight;

    final RRect rrect = RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, width, height), Radius.circular(radius));

    final Path path = Path()..addRRect(rrect);

    // Tail
    path.moveTo(width / 2 - tailWidth / 2, height);
    path.lineTo(width / 2, size.height);
    path.lineTo(width / 2 + tailWidth / 2, height);
    path.close();

    canvas.drawPath(path, paint);
  }

  /// Create a simple photo marker for Moments
  static Future<({Uint8List data, int width, int height})?>
      createMomentMarker([String? imageUrl]) async {
    ui.Image? img;
    ui.Image? photoImg;
    try {
      final double width = 120;
      final double tailHeight = 16;
      final double height = width + tailHeight; // total height
      final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(pictureRecorder);

      final Paint backgroundPaint = Paint()..color = Colors.grey[300]!;
      final Paint borderPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0;

      // Draw Avatar Image or Initial
      if (imageUrl != null && imageUrl.isNotEmpty) {
        try {
          final response = await http.get(Uri.parse(imageUrl)).timeout(const Duration(seconds: 3));
          if (response.statusCode == 200) {
            final codec = await ui.instantiateImageCodec(response.bodyBytes, targetWidth: width.toInt(), targetHeight: width.toInt());
            final frame = await codec.getNextFrame();
            photoImg = frame.image;
          }
        } catch (_) {}
      }

      if (photoImg != null) {
        // Draw the image clipped to the pin shape
        canvas.save();
        final RRect rrect = RRect.fromRectAndRadius(
            Rect.fromLTWH(0, 0, width, height - tailHeight), const Radius.circular(12.0));
        final Path path = Path()..addRRect(rrect);
        // Add tail
        path.moveTo(width / 2 - 24.0 / 2, height - tailHeight);
        path.lineTo(width / 2, height);
        path.lineTo(width / 2 + 24.0 / 2, height - tailHeight);
        path.close();
        
        canvas.clipPath(path);
        paintImage(
          canvas: canvas,
          rect: Rect.fromLTWH(0, 0, width, width),
          image: photoImg,
          fit: BoxFit.cover,
        );
        canvas.restore();
        
        // Draw border over it
        _drawPinWithTail(canvas, Size(width, height), borderPaint);
      } else {
        _drawPinWithTail(canvas, Size(width, height), backgroundPaint);
        _drawPinWithTail(canvas, Size(width, height), borderPaint);

        // Draw icon fallback
        TextPainter painter = TextPainter(textDirection: TextDirection.ltr);
        painter.text = TextSpan(
          text: String.fromCharCode(Icons.photo.codePoint),
          style: TextStyle(
            fontSize: 50,
            color: Colors.grey[600],
            fontFamily: Icons.photo.fontFamily,
            package: Icons.photo.fontPackage,
          ),
        );
        painter.layout();
        painter.paint(
            canvas,
            Offset((width - painter.width) / 2,
                ((height - tailHeight) - painter.height) / 2));
      }

      img = await pictureRecorder
          .endRecording()
          .toImage(width.toInt(), height.toInt());
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) return null;

      final data = byteData.buffer.asUint8List(
        byteData.offsetInBytes,
        byteData.lengthInBytes,
      );

      if (data.isEmpty || width <= 0 || height <= 0) {
        return null;
      }

      bool validSignature = false;
      if (data.length >= 8) {
        if (data[0] == 0x89 &&
            data[1] == 0x50 &&
            data[2] == 0x4E &&
            data[3] == 0x47 &&
            data[4] == 0x0D &&
            data[5] == 0x0A &&
            data[6] == 0x1A &&
            data[7] == 0x0A) {
          validSignature = true;
        }
      }

      if (!validSignature) return null;

      return (data: data, width: width.toInt(), height: height.toInt());
    } catch (e) {
      return null;
    } finally {
      img?.dispose();
    }
  }

  /// Create a marker with a network image (for Mapbox Moments)
  static Future<({Uint8List data, int width, int height})?>
      createNetworkImageMarker(String imageUrl) async {
    ui.Image? networkImage;
    ui.Codec? codec;
    ui.Image? img;

    try {
      if (imageUrl.isEmpty) return null;
      final uri = Uri.tryParse(imageUrl);
      if (uri == null ||
          (uri.scheme != 'http' && uri.scheme != 'https') ||
          uri.host.isEmpty) {
        return null;
      }

      final double width = 120;
      final double tailHeight = 16;
      final double height = width + tailHeight;
      final double imageMargin = 6;
      final double imageSize = width - imageMargin * 2;

      final response = await http.get(uri);
      if (response.statusCode != 200) return null;

      codec = await ui.instantiateImageCodec(
        response.bodyBytes,
        targetWidth: imageSize.toInt(),
        targetHeight: imageSize.toInt(),
      );
      final ui.FrameInfo frameInfo = await codec.getNextFrame();
      networkImage = frameInfo.image;

      final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(pictureRecorder);

      final Paint bgPaint = Paint()..color = Colors.white;

      _drawPinWithTail(canvas, Size(width, height), bgPaint, radius: 12.0);

      // Draw the downloaded image clipped inside
      final RRect imageRect = RRect.fromRectAndRadius(
          Rect.fromLTWH(imageMargin, imageMargin, imageSize, imageSize),
          const Radius.circular(8));

      canvas.save();
      canvas.clipRRect(imageRect);
      canvas.drawImage(networkImage, Offset(imageMargin, imageMargin), Paint());
      canvas.restore();

      img = await pictureRecorder
          .endRecording()
          .toImage(width.toInt(), height.toInt());
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) return null;

      final data = byteData.buffer.asUint8List(
        byteData.offsetInBytes,
        byteData.lengthInBytes,
      );

      if (data.isEmpty || width <= 0 || height <= 0) {
        return null;
      }

      bool validSignature = false;
      if (data.length >= 8) {
        if (data[0] == 0x89 &&
            data[1] == 0x50 &&
            data[2] == 0x4E &&
            data[3] == 0x47 &&
            data[4] == 0x0D &&
            data[5] == 0x0A &&
            data[6] == 0x1A &&
            data[7] == 0x0A) {
          validSignature = true;
        }
      }

      if (!validSignature) return null;

      return (data: data, width: width.toInt(), height: height.toInt());
    } catch (e) {
      return null;
    } finally {
      networkImage?.dispose();
      codec?.dispose();
      img?.dispose();
    }
  }

  /// Create a cluster marker
  static Future<({Uint8List data, int width, int height})> createClusterMarker(
      int count) async {
    final int size = 120; // total canvas size
    final double radius = 40;
    final Offset center = Offset(size / 2, size / 2);

    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);

    // Draw shadow
    final Path shadowPath = Path()
      ..addOval(Rect.fromCircle(center: center, radius: radius));
    canvas.drawShadow(shadowPath, Colors.black, 4.0, true);

    // Draw main circle (blue)
    final Paint mainPaint = Paint()..color = const Color(0xFF2196F3);
    final Paint borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    canvas.drawCircle(center, radius, mainPaint);
    canvas.drawCircle(center, radius, borderPaint);

    // Draw users icon
    TextPainter iconPainter = TextPainter(textDirection: TextDirection.ltr);
    iconPainter.text = TextSpan(
      text: String.fromCharCode(Icons.people.codePoint),
      style: TextStyle(
        fontSize: 40,
        color: Colors.white,
        fontFamily: Icons.people.fontFamily,
        package: Icons.people.fontPackage,
      ),
    );
    iconPainter.layout();
    iconPainter.paint(
        canvas,
        Offset(center.dx - iconPainter.width / 2,
            center.dy - iconPainter.height / 2));

    // Draw top-right badge if count > 1
    if (count > 1) {
      final double badgeRadius = 18;
      final Offset badgeCenter =
          Offset(center.dx + radius * 0.7, center.dy - radius * 0.7);

      final Paint badgePaint = Paint()..color = Colors.redAccent;
      canvas.drawCircle(badgeCenter, badgeRadius, badgePaint);
      canvas.drawCircle(
          badgeCenter,
          badgeRadius,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0);

      TextPainter textPainter = TextPainter(textDirection: TextDirection.ltr);
      textPainter.text = TextSpan(
        text: count > 99 ? '99+' : count.toString(),
        style: const TextStyle(
          fontSize: 18,
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      );
      textPainter.layout();
      textPainter.paint(
          canvas,
          Offset(badgeCenter.dx - textPainter.width / 2,
              badgeCenter.dy - textPainter.height / 2));
    }

    final img = await pictureRecorder.endRecording().toImage(size, size);
    final data = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
    return (data: data!.buffer.asUint8List(), width: size, height: size);
  }

  /// Create Schedule Stop Pin
  static Future<({Uint8List data, int width, int height})?>
      createScheduleStopMarker(String text) async {
    // 1. Measure text
    TextPainter textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '...',
    );
    textPainter.text = TextSpan(
      text: text,
      style: const TextStyle(
        fontSize: 18,
        color: Color(0xFF1E293B), // text-slate-800
        fontWeight: FontWeight.bold,
      ),
    );

    final double textPaddingX = 12.0;
    final double textPaddingY = 6.0;

    final double maxOutputWidth = 512.0;
    final double maxOutputHeight = 128.0;

    final double availableTextWidth = maxOutputWidth - (textPaddingX * 2);
    textPainter.layout(maxWidth: availableTextWidth);

    final double textBgWidth = textPainter.width + textPaddingX * 2;
    double textBgHeight = textPainter.height + textPaddingY * 2;

    // 2. Middle Circle (Blue pin)
    final double circleRadius = 16.0; // w-8 h-8 -> radius 16
    final double circleDiameter = circleRadius * 2;

    // 3. Bottom Dot
    final double dotRadius = 3.0; // w-1.5 h-1.5
    final double dotDiameter = dotRadius * 2;

    // Spacing
    final double gap1 = 8.0; // Between pill and circle (mb-2)
    final double gap2 = 4.0; // Between circle and dot (mt-1)

    final double totalHeight =
        textBgHeight + gap1 + circleDiameter + gap2 + dotDiameter;
    final double totalWidth =
        textBgWidth > circleDiameter ? textBgWidth : circleDiameter;

    final int finalWidth = totalWidth > maxOutputWidth
        ? maxOutputWidth.toInt()
        : totalWidth.toInt();
    final int finalHeight = totalHeight > maxOutputHeight
        ? maxOutputHeight.toInt()
        : totalHeight.toInt();

    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);

    // Center X
    final double centerX = finalWidth / 2;

    // Y offsets
    final double textY = 0;
    final double circleY = textY + textBgHeight + gap1;
    final double dotY = circleY + circleDiameter + gap2;

    // A. Draw Text Pill (glass-panel)
    final RRect textPill = RRect.fromRectAndRadius(
        Rect.fromLTWH(
            centerX - textBgWidth / 2, textY, textBgWidth, textBgHeight),
        const Radius.circular(12) // rounded-xl
        );
    // Draw shadow
    canvas.drawShadow(
        Path()..addRRect(textPill), Colors.black, 4.0, true); // shadow-lg
    // Draw fill (glass panel, white transparent)
    canvas.drawRRect(
        textPill, Paint()..color = Colors.white.withValues(alpha: 0.9));
    // Draw border
    canvas.drawRRect(
        textPill,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0);
    // Draw text
    textPainter.paint(
        canvas, Offset(centerX - textPainter.width / 2, textY + textPaddingY));

    // B. Draw Blue Circle
    final Offset circleCenter = Offset(centerX, circleY + circleRadius);
    canvas.drawShadow(
        Path()
          ..addOval(
              Rect.fromCircle(center: circleCenter, radius: circleRadius)),
        const Color(0xFF0068E0),
        4.0,
        true);
    // Fill
    final Paint circlePaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(centerX - circleRadius, circleY),
        Offset(centerX + circleRadius, circleY + circleDiameter),
        [
          const Color(0xFF0068E0),
          const Color(0xFF22D3EE)
        ], // from-brand to-cyan-400
      );
    canvas.drawCircle(circleCenter, circleRadius, circlePaint);
    // Border
    canvas.drawCircle(
        circleCenter,
        circleRadius,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0);

    // Icon in Circle
    TextPainter iconPainter = TextPainter(textDirection: TextDirection.ltr);
    iconPainter.text = TextSpan(
      text: String.fromCharCode(Icons.location_on.codePoint),
      style: TextStyle(
        fontSize: 18, // w-4 h-4
        color: Colors.white,
        fontFamily: Icons.location_on.fontFamily,
        package: Icons.location_on.fontPackage,
      ),
    );
    iconPainter.layout();
    iconPainter.paint(
        canvas,
        Offset(centerX - iconPainter.width / 2,
            circleCenter.dy - iconPainter.height / 2));

    // C. Draw Bottom Dot
    final Offset dotCenter = Offset(centerX, dotY + dotRadius);
    canvas.drawCircle(dotCenter, dotRadius,
        Paint()..color = const Color(0xFF0068E0).withValues(alpha: 0.8));

    final img =
        await pictureRecorder.endRecording().toImage(finalWidth, finalHeight);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    img.dispose();

    if (byteData == null) return null;

    final data = byteData.buffer.asUint8List(
      byteData.offsetInBytes,
      byteData.lengthInBytes,
    );

    if (data.isEmpty || finalWidth <= 0 || finalHeight <= 0) {
      return null;
    }

    bool validSignature = false;
    if (data.length >= 8) {
      if (data[0] == 0x89 &&
          data[1] == 0x50 &&
          data[2] == 0x4E &&
          data[3] == 0x47 &&
          data[4] == 0x0D &&
          data[5] == 0x0A &&
          data[6] == 0x1A &&
          data[7] == 0x0A) {
        validSignature = true;
      }
    }

    if (kDebugMode || kProfileMode) {
      debugPrint('WAYPOINT_PNG_WIDTH: $finalWidth');
      debugPrint('WAYPOINT_PNG_HEIGHT: $finalHeight');
      debugPrint('WAYPOINT_PNG_BYTE_LENGTH: ${data.length}');
      debugPrint('WAYPOINT_PNG_SIGNATURE_VALID: $validSignature');
    }

    if (!validSignature) {
      debugPrint('MAP_RENDER_ERROR: Invalid waypoint PNG signature');
      return null;
    }

    return (data: data, width: finalWidth, height: finalHeight);
  }

  static Future<({Uint8List data, int width, int height})>
      createLiveFriendMarker(String? avatarUrl, bool isStaff, {String? name}) async {
    final double avatarRadius = 28.0;
    final double borderSize = 3.5;
    final double totalRadius = avatarRadius + borderSize;

    // Simulate ping ring
    final double pingRadius = totalRadius + 12.0;

    final double tailHeight = 12.0;
    
    // Measure name text
    double textHeight = 0;
    double textWidth = 0;
    TextPainter? namePainter;
    if (name != null && name.isNotEmpty) {
      namePainter = TextPainter(textDirection: TextDirection.ltr);
      namePainter.text = TextSpan(
        text: name,
        style: const TextStyle(
          fontSize: 13,
          color: Colors.white,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.2,
        ),
      );
      namePainter.layout();
      textHeight = namePainter.height + 12.0; // vertical padding
      textWidth = namePainter.width + 16.0;   // horizontal padding
    }

    // Include space for the badge if staff
    final double badgeHeight = isStaff ? 20.0 : 0.0;

    // Canvas size
    final double totalWidth = math.max(pingRadius * 2, textWidth);
    final double totalHeight = pingRadius * 2 + tailHeight + textHeight + badgeHeight;

    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);

    final double centerX = totalWidth / 2;
    // Push the avatar down if there's a staff badge
    final double centerY = pingRadius + (isStaff ? 8.0 : 0.0);

    final Color ringColor = isStaff ? const Color(0xFF10B981) : const Color(0xFF3B82F6); // Emerald or Blue

    // 1. Draw Ping Ring (Pulse)
    canvas.drawCircle(Offset(centerX, centerY), pingRadius, Paint()..color = ringColor.withValues(alpha: 0.15));
    canvas.drawCircle(Offset(centerX, centerY), pingRadius - 6, Paint()..color = ringColor.withValues(alpha: 0.3));

    // 2. Draw Pin Tail
    Path tailPath = Path();
    tailPath.moveTo(centerX - 8, centerY + totalRadius - 2);
    tailPath.lineTo(centerX + 8, centerY + totalRadius - 2);
    tailPath.lineTo(centerX, centerY + totalRadius + tailHeight);
    tailPath.close();
    canvas.drawPath(tailPath, Paint()..color = Colors.white);

    Path tailInner = Path();
    tailInner.moveTo(centerX - 5, centerY + totalRadius - 2);
    tailInner.lineTo(centerX + 5, centerY + totalRadius - 2);
    tailInner.lineTo(centerX, centerY + totalRadius + tailHeight - 2);
    tailInner.close();
    canvas.drawPath(tailInner, Paint()..color = ringColor);

    // 3. Draw Shadow for avatar
    canvas.drawShadow(
        Path()..addOval(Rect.fromCircle(center: Offset(centerX, centerY), radius: totalRadius)),
        Colors.black, 12.0, true);
        
    // 4. Ring fill
    canvas.drawCircle(Offset(centerX, centerY), totalRadius, Paint()..color = ringColor);

    // 5. Draw image inside (or fallback icon)
    bool hasDrawnImage = false;
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      try {
        final response = await http
            .get(Uri.parse(avatarUrl))
            .timeout(const Duration(seconds: 3));
        if (response.statusCode == 200) {
          final ui.Codec codec = await ui.instantiateImageCodec(
              response.bodyBytes,
              targetWidth: (avatarRadius * 2).toInt(),
              targetHeight: (avatarRadius * 2).toInt());
          final ui.FrameInfo fi = await codec.getNextFrame();
          final ui.Image image = fi.image;
          Path clipPath = Path()
            ..addOval(Rect.fromCircle(center: Offset(centerX, centerY), radius: avatarRadius));
          canvas.save();
          canvas.clipPath(clipPath);
          paintImage(
              canvas: canvas,
              rect: Rect.fromLTWH(centerX - avatarRadius, centerY - avatarRadius, avatarRadius * 2, avatarRadius * 2),
              image: image,
              fit: BoxFit.cover);
          canvas.restore();
          hasDrawnImage = true;
        }
      } catch (_) {}
    }

    if (!hasDrawnImage) {
      canvas.drawCircle(Offset(centerX, centerY), avatarRadius, Paint()..color = Colors.white);
      TextPainter iconPainter = TextPainter(textDirection: TextDirection.ltr);
      String fallbackText = (name != null && name.isNotEmpty) ? name[0].toUpperCase() : String.fromCharCode(Icons.person.codePoint);
      iconPainter.text = TextSpan(
        text: fallbackText,
        style: TextStyle(
          fontSize: (name != null && name.isNotEmpty) ? 26 : 32,
          color: ringColor,
          fontWeight: FontWeight.bold,
          fontFamily: (name != null && name.isNotEmpty) ? null : Icons.person.fontFamily,
          package: (name != null && name.isNotEmpty) ? null : Icons.person.fontPackage,
        ),
      );
      iconPainter.layout();
      iconPainter.paint(canvas, Offset(centerX - iconPainter.width / 2, centerY - iconPainter.height / 2));
    }

    // 6. Draw white border ring
    canvas.drawCircle(
        Offset(centerX, centerY),
        totalRadius,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = borderSize);

    // 7. Draw status dot (Live pulse overlay)
    final double dotRadius = 7.0;
    final double offset = totalRadius * 0.7071;
    final Offset dotCenter = Offset(centerX + offset, centerY + offset);
    canvas.drawCircle(dotCenter, dotRadius, Paint()..color = ringColor);
    canvas.drawCircle(
        dotCenter,
        dotRadius,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0);

    // 8. Draw Staff Badge (if staff)
    if (isStaff) {
      TextPainter badgePainter = TextPainter(textDirection: TextDirection.ltr);
      badgePainter.text = const TextSpan(
        text: 'STAFF',
        style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w900),
      );
      badgePainter.layout();
      final double badgeWidth = badgePainter.width + 10.0;
      final double badgeHeight = badgePainter.height + 4.0;

      final RRect badgeRect = RRect.fromRectAndRadius(
          Rect.fromLTWH(centerX - badgeWidth / 2, 2, badgeWidth, badgeHeight),
          const Radius.circular(4));
      canvas.drawRRect(badgeRect, Paint()..color = const Color(0xFF059669));
      canvas.drawRRect(badgeRect, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 1.0);

      badgePainter.paint(canvas, Offset(centerX - badgePainter.width / 2, 4.0));
    }

    // 9. Draw Name Tag
    if (namePainter != null) {
      final double tagWidth = namePainter.width + 16.0;
      final double tagHeight = namePainter.height + 12.0;
      final double tagTop = centerY + totalRadius + tailHeight;

      final RRect tagRect = RRect.fromRectAndRadius(
          Rect.fromLTWH(centerX - tagWidth / 2, tagTop, tagWidth, tagHeight),
          const Radius.circular(6));

      // Draw shadow for name tag
      canvas.drawShadow(
          Path()..addRRect(tagRect),
          Colors.black, 4.0, false);
      
      canvas.drawRRect(tagRect, Paint()..color = ringColor);
      namePainter.paint(canvas, Offset(centerX - namePainter.width / 2, tagTop + 6.0));
    }

    final img = await pictureRecorder.endRecording().toImage(totalWidth.toInt(), totalHeight.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    final data = byteData!.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes);
    return (
      data: data,
      width: totalWidth.toInt(),
      height: totalHeight.toInt()
    );
  }
}
