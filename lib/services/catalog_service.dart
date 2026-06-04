import 'package:get/get.dart';
import '../constants/api_constants.dart';
import 'base_service.dart';

class CategoryModel {
  final int id;
  final String name;

  CategoryModel({required this.id, required this.name});

  factory CategoryModel.fromJson(Map<String, dynamic> json) => CategoryModel(
        id: json['id'] as int,
        name: json['name'] as String? ?? json['categoryName'] as String? ?? '',
      );
}

class BannerModel {
  final int id;
  final String? title;
  final String? imageUrl;
  final String? linkUrl;

  BannerModel({
    required this.id,
    this.title,
    this.imageUrl,
    this.linkUrl,
  });

  factory BannerModel.fromJson(Map<String, dynamic> json) => BannerModel(
        id: json['id'] as int,
        title: json['title'] as String?,
        imageUrl: json['imageUrl'] as String? ?? json['image'] as String?,
        linkUrl: json['linkUrl'] as String?,
      );
}

class TourItineraryModel {
  final int id;
  final String? title;
  final String? description;
  final int? dayNumber;

  TourItineraryModel({
    required this.id,
    this.title,
    this.description,
    this.dayNumber,
  });

  factory TourItineraryModel.fromJson(Map<String, dynamic> json) =>
      TourItineraryModel(
        id: json['id'] as int,
        title: json['title'] as String? ?? json['locationName'] as String?,
        description: json['description'] as String?,
        dayNumber: json['dayNumber'] as int? ?? json['day'] as int?,
      );
}

class CatalogService extends GetxService with BaseServiceMixin {
  Future<List<CategoryModel>> getCategories() async {
    return request(() async {
      final response = await api.dio.get(ApiConstants.categories);
      return parseList(response.data, CategoryModel.fromJson);
    });
  }

  Future<List<BannerModel>> getBanners() async {
    return request(() async {
      final response = await api.dio.get(ApiConstants.banners);
      return parseList(response.data, BannerModel.fromJson);
    });
  }

  Future<List<TourItineraryModel>> getTourItineraries(int tourId) async {
    return request(() async {
      final response =
          await api.dio.get('${ApiConstants.tours}/$tourId/itineraries');
      return parseList(response.data, TourItineraryModel.fromJson);
    });
  }
}
