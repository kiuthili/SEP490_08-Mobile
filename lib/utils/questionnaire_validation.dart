import '../models/ai_models.dart';

bool _isEmpty(dynamic value) =>
    value == null || value == '' || (value is List && value.isEmpty);

String? validateQuestionnaireField(
  QuestionnaireField field,
  Map<String, dynamic> values,
) {
  final raw = values[field.fieldKey];
  if (!field.required && _isEmpty(raw)) return null;

  switch (field.inputType) {
    case 'single_select':
      if (_isEmpty(raw)) return '${field.label} là bắt buộc';
      return null;
    case 'multi_select':
      final arr = raw is List ? raw : <dynamic>[];
      if (field.required && arr.isEmpty) {
        return 'Chọn ít nhất một sở thích du lịch';
      }
      return null;
    case 'date':
      if (_isEmpty(raw)) return '${field.label} là bắt buộc';
      if (raw is String && !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(raw)) {
        return 'Định dạng ngày: YYYY-MM-DD';
      }
      return null;
    case 'number':
      if (_isEmpty(raw)) {
        return field.required ? '${field.label} là bắt buộc' : null;
      }
      final n = num.tryParse(raw.toString());
      if (n == null || n < 0) return 'Giá trị phải là số không âm';
      if (field.fieldKey == 'adultCount' && n < 1)
        return 'Phải có ít nhất 1 người lớn';
      return null;
    case 'boolean':
      if (field.required && raw is! bool) {
        return '${field.label} là bắt buộc';
      }
      return null;
    case 'text':
      if (field.required && _isEmpty(raw)) {
        return '${field.label} là bắt buộc';
      }
      if (raw is String && raw.length > 100) {
        return 'Tối đa 100 ký tự';
      }
      return null;
    default:
      if (field.required && _isEmpty(raw)) {
        return '${field.label} là bắt buộc';
      }
      return null;
  }
}

Map<String, String> validateQuestionnaireStep(
  List<QuestionnaireField> fields,
  Map<String, dynamic> values,
) {
  final errors = <String, String>{};
  for (final field in fields) {
    final msg = validateQuestionnaireField(field, values);
    if (msg != null) errors[field.fieldKey] = msg;
  }

  final start = values['preferredStartDate']?.toString();
  final end = values['preferredEndDate']?.toString();
  if (start != null &&
      end != null &&
      end.isNotEmpty &&
      end.compareTo(start) < 0) {
    errors['preferredEndDate'] = 'Ngày kết thúc phải sau ngày bắt đầu';
  }

  return errors;
}

Map<String, dynamic> buildRecommendPayload(
  Map<String, dynamic> values,
  String sessionId,
) {
  final interests = values['travelInterests'];
  final travelInterests = interests is List
      ? interests.map((e) => e.toString()).toList()
      : interests != null
          ? [interests.toString()]
          : <String>[];

  final adultCount = int.tryParse(values['adultCount']?.toString() ?? '1') ?? 1;
  final elderlyCount =
      int.tryParse(values['elderlyCount']?.toString() ?? '0') ?? 0;
  final childrenCount =
      int.tryParse(values['childrenCount']?.toString() ?? '0') ?? 0;
  final total = adultCount + elderlyCount + childrenCount;

  String inferredCompanionType = 'group';
  if (total == 1) {
    inferredCompanionType = 'solo';
  } else if (childrenCount > 0) {
    inferredCompanionType = 'family';
  } else if (total == 2) {
    inferredCompanionType = 'couple';
  } else if (total <= 4) {
    inferredCompanionType = 'family';
  } else {
    inferredCompanionType = 'group';
  }

  final payload = <String, dynamic>{
    'companionType': inferredCompanionType,
    'preferredStartDate': values['preferredStartDate'],
    'travelInterests': travelInterests,
    'nationalityType': values['nationalityType'] ?? 'vietnamese',
    'sessionId': sessionId,
    'top': 10,
  };

  if (values['preferredEndDate'] != null &&
      values['preferredEndDate'].toString().isNotEmpty) {
    payload['preferredEndDate'] = values['preferredEndDate'];
  }
  if (values['maxBudgetPerPerson'] != null &&
      values['maxBudgetPerPerson'].toString().isNotEmpty) {
    final rawBudget = values['maxBudgetPerPerson']
        .toString()
        .replaceAll('.', '')
        .replaceAll(',', '');
    payload['maxBudgetPerPerson'] = int.tryParse(rawBudget);
  }
  if (values['travelPace'] != null &&
      values['travelPace'].toString().isNotEmpty) {
    payload['travelPace'] = values['travelPace'];
  } else {
    payload['travelPace'] = 'moderate';
  }
  if (values['adultCount'] != null) {
    payload['adultCount'] = int.tryParse(values['adultCount'].toString());
  }
  if (values['elderlyCount'] != null) {
    payload['elderlyCount'] = int.tryParse(values['elderlyCount'].toString());
  }
  if (values['childrenCount'] != null) {
    payload['childrenCount'] = int.tryParse(values['childrenCount'].toString());
  }
  if (values['preferredCity'] != null &&
      values['preferredCity'].toString().trim().isNotEmpty) {
    payload['preferredCity'] = values['preferredCity'].toString().trim();
  }
  if (values['preferredCountry'] != null &&
      values['preferredCountry'].toString().trim().isNotEmpty) {
    payload['preferredCountry'] = values['preferredCountry'].toString().trim();
  }

  return payload;
}

bool isAiModelsNotReadyMessage(String message) =>
    message.toLowerCase().contains('ai models are not ready');
