// lib/models/map_models.dart
//
// Các model phụ trợ riêng cho màn hình Bản đồ Social.
// Tách riêng để không phụ thuộc cấu trúc nội bộ của TourItineraryModel,
// đồng thời giữ dữ liệu mà flutter_map cần (lat/lng/weight) ở dạng tối giản.

import '../utils/json_utils.dart';

/// Một "Ngày" trong lộ trình của Tour (Day 1, Day 2 ...).
/// Dùng để render danh sách chip chọn ngày trên bản đồ.
class RouteDayModel {
  final int dayNumber;
  final String title; // ví dụ: "Ngày 1: Cần Thơ → Hậu Giang"
  final DateTime? date;

  const RouteDayModel({
    required this.dayNumber,
    required this.title,
    this.date,
  });

  factory RouteDayModel.fromJson(Map<String, dynamic> json) => RouteDayModel(
    dayNumber: JsonUtils.readInt(
      JsonUtils.pick(json, ['dayNumber', 'DayNumber', 'day', 'Day']),
    ),
    title: JsonUtils.readString(
      JsonUtils.pick(json, ['title', 'Title', 'name', 'Name']),
    ) ??
        'Ngày ${JsonUtils.readInt(JsonUtils.pick(json, ['dayNumber', 'day']))}',
    date: JsonUtils.readDateTime(
      JsonUtils.pick(json, ['date', 'Date', 'visitDate']),
    ),
  );
}

/// Một điểm đến trên lộ trình (đã có toạ độ để vẽ Polyline).
/// `dayNumber` cho phép gom điểm theo ngày ngay tại client.
class RoutePointModel {
  final int dayNumber;
  final int order;
  final String name; // ví dụ: "Cần Thơ"
  final double lat;
  final double lng;
  final DateTime? arrivalTime;

  const RoutePointModel({
    required this.dayNumber,
    required this.order,
    required this.name,
    required this.lat,
    required this.lng,
    this.arrivalTime,
  });

  factory RoutePointModel.fromJson(Map<String, dynamic> json) =>
      RoutePointModel(
        dayNumber: JsonUtils.readInt(
          JsonUtils.pick(json, ['dayNumber', 'DayNumber', 'day', 'Day']),
        ),
        order: JsonUtils.readInt(
          JsonUtils.pick(
            json,
            ['order', 'Order', 'sequence', 'Sequence', 'sortOrder', 'id', 'Id'],
          ),
        ),
        name: JsonUtils.readString(
          JsonUtils.pick(json, [
            'name', 'Name',
            'locationName', 'LocationName',
            'title', 'Title',
            'place',
          ]),
        ) ??
            '',
        lat: JsonUtils.readDouble(
          JsonUtils.pick(json, [
            'locationLat', 'LocationLat',
            'lat', 'Lat', 'latitude', 'Latitude',
          ]),
        ) ??
            0,
        lng: JsonUtils.readDouble(
          JsonUtils.pick(json, [
            'locationLng', 'LocationLng',
            'lng', 'Lng', 'longitude', 'Longitude',
          ]),
        ) ??
            0,
        arrivalTime: JsonUtils.readDateTime(
          JsonUtils.pick(json, ['arrivalTime', 'ArrivalTime', 'time']),
        ),
      );

  bool get hasCoordinates => lat != 0 && lng != 0;
}

/// Một điểm dữ liệu cho Heatmap (toạ độ + cường độ/số lượt qua lại).
class HeatPointModel {
  final double lat;
  final double lng;
  final double weight; // 0..1 hoặc số lượt; sẽ được normalize ở UI

  const HeatPointModel({
    required this.lat,
    required this.lng,
    this.weight = 1,
  });

  factory HeatPointModel.fromJson(Map<String, dynamic> json) => HeatPointModel(
    lat: JsonUtils.readDouble(
      JsonUtils.pick(json, ['lat', 'Lat', 'latitude']),
    ) ??
        0,
    lng: JsonUtils.readDouble(
      JsonUtils.pick(json, ['lng', 'Lng', 'longitude']),
    ) ??
        0,
    weight: JsonUtils.readDouble(
      JsonUtils.pick(json, ['weight', 'Weight', 'count', 'intensity']),
    ) ??
        1,
  );
}
