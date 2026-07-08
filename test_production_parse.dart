import 'dart:convert';
import 'dart:io';
import 'package:stayhub_mobile/models/ai_models.dart';

void main() {
  try {
    final file = File('/home/kiuthi/Projects/Mobile/SEP490_08-Mobile/recommend_response.json');
    final jsonStr = file.readAsStringSync();
    final data = json.decode(jsonStr) as Map<String, dynamic>;
    final model = PersonalizedRecommendationModel.fromJson(data);
    print('Fully parsed PersonalizedRecommendationModel successfully!');
    print('Recommended tours: ${model.recommendedTours.length}');
  } catch (e, stack) {
    print('Error: $e');
    print(stack);
  }
}
