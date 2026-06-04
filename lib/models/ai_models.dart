import '../utils/json_utils.dart';

class QuestionnaireOption {
  final String value;
  final String label;

  QuestionnaireOption({required this.value, required this.label});

  factory QuestionnaireOption.fromJson(Map<String, dynamic> json) =>
      QuestionnaireOption(
        value: JsonUtils.readString(json['value']) ?? '',
        label: JsonUtils.readString(json['label']) ?? '',
      );
}

class QuestionnaireField {
  final String fieldKey;
  final String label;
  final String inputType;
  final bool required;
  final String? hint;
  final List<QuestionnaireOption> options;

  QuestionnaireField({
    required this.fieldKey,
    required this.label,
    required this.inputType,
    required this.required,
    this.hint,
    this.options = const [],
  });

  factory QuestionnaireField.fromJson(Map<String, dynamic> json) {
    final rawOptions = JsonUtils.readMapList(json['options']);
    return QuestionnaireField(
      fieldKey: JsonUtils.readString(json['fieldKey']) ?? '',
      label: JsonUtils.readString(json['label']) ?? '',
      inputType: JsonUtils.readString(json['inputType']) ?? 'text',
      required: JsonUtils.readBool(json['required']),
      hint: JsonUtils.readString(json['hint']),
      options: rawOptions.map(QuestionnaireOption.fromJson).toList(),
    );
  }
}

class StandardQuestionnaire {
  final String version;
  final List<QuestionnaireField> questions;

  StandardQuestionnaire({
    required this.version,
    required this.questions,
  });

  factory StandardQuestionnaire.fromJson(Map<String, dynamic> json) {
    final raw = JsonUtils.readMapList(
      JsonUtils.pick(json, ['questions', 'Questions']),
    );
    return StandardQuestionnaire(
      version: JsonUtils.readString(json['version']) ?? '1.0',
      questions: raw.map(QuestionnaireField.fromJson).toList(),
    );
  }
}

class PublicLocationModel {
  final double lat;
  final double lng;
  final String fullName;

  PublicLocationModel({
    required this.lat,
    required this.lng,
    required this.fullName,
  });

  factory PublicLocationModel.fromJson(Map<String, dynamic> json) {
    return PublicLocationModel(
      lat: (json['lat'] as num?)?.toDouble() ??
          (json['latitude'] as num?)?.toDouble() ??
          0,
      lng: (json['lng'] as num?)?.toDouble() ??
          (json['longitude'] as num?)?.toDouble() ??
          0,
      fullName: JsonUtils.readString(
            JsonUtils.pick(json, ['fullName', 'FullName']),
          ) ??
          'Khách',
    );
  }
}
