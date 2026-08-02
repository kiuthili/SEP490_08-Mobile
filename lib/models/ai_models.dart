import '../utils/json_utils.dart';
import 'package:get/get.dart';
import 'tour_model.dart';

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

class AiChatResponseModel {
  final String sessionId;
  final String intent;
  final String reply;
  final List<String> suggestedQuestions;
  final List<TourRecommendationModel> recommendedTours;

  AiChatResponseModel({
    required this.sessionId,
    required this.intent,
    required this.reply,
    this.suggestedQuestions = const [],
    this.recommendedTours = const [],
  });

  factory AiChatResponseModel.fromJson(Map<String, dynamic> json) {
    final suggestions = JsonUtils.pick(json, [
      'suggestedQuestions',
      'SuggestedQuestions',
    ]);
    final tours = JsonUtils.readMapList(
      JsonUtils.pick(json, ['recommendedTours', 'RecommendedTours']),
    );
    return AiChatResponseModel(
      sessionId: JsonUtils.readString(
            JsonUtils.pick(json, ['sessionId', 'SessionId']),
          ) ??
          '',
      intent:
          JsonUtils.readString(JsonUtils.pick(json, ['intent', 'Intent'])) ??
              '',
      reply:
          JsonUtils.readString(JsonUtils.pick(json, ['reply', 'Reply'])) ?? '',
      suggestedQuestions: suggestions is List
          ? suggestions.map((e) => e.toString()).toList()
          : const [],
      recommendedTours: tours.map(TourRecommendationModel.fromJson).toList(),
    );
  }
}

class AiChatMessageModel {
  final String id;
  final String role;
  final String text;
  final AiChatResponseModel? response;

  AiChatMessageModel({
    required this.id,
    required this.role,
    required this.text,
    this.response,
  });
}

class TourPreferenceQuestionnaireModel {
  final String companionType;
  final String preferredStartDate;
  final String? preferredEndDate;
  final int? maxBudgetPerPerson;
  final bool hasElderly;
  final bool hasChildren;
  final int? elderlyCount;
  final int? childrenCount;
  final List<String> travelInterests;
  final String nationalityType;
  final String? preferredCity;
  final String? preferredCountry;

  TourPreferenceQuestionnaireModel({
    required this.companionType,
    required this.preferredStartDate,
    this.preferredEndDate,
    this.maxBudgetPerPerson,
    required this.hasElderly,
    required this.hasChildren,
    this.elderlyCount,
    this.childrenCount,
    this.travelInterests = const [],
    required this.nationalityType,
    this.preferredCity,
    this.preferredCountry,
  });

  factory TourPreferenceQuestionnaireModel.fromJson(Map<String, dynamic> json) {
    return TourPreferenceQuestionnaireModel(
      companionType: JsonUtils.readString(
              JsonUtils.pick(json, ['companionType', 'CompanionType'])) ??
          'solo',
      preferredStartDate: JsonUtils.readString(JsonUtils.pick(
              json, ['preferredStartDate', 'PreferredStartDate'])) ??
          '',
      preferredEndDate: JsonUtils.readString(
          JsonUtils.pick(json, ['preferredEndDate', 'PreferredEndDate'])),
      maxBudgetPerPerson: JsonUtils.readInt(
          JsonUtils.pick(json, ['maxBudgetPerPerson', 'MaxBudgetPerPerson'])),
      hasElderly: JsonUtils.readBool(
          JsonUtils.pick(json, ['hasElderly', 'HasElderly'])),
      hasChildren: JsonUtils.readBool(
          JsonUtils.pick(json, ['hasChildren', 'HasChildren'])),
      elderlyCount: JsonUtils.readInt(
          JsonUtils.pick(json, ['elderlyCount', 'ElderlyCount'])),
      childrenCount: JsonUtils.readInt(
          JsonUtils.pick(json, ['childrenCount', 'ChildrenCount'])),
      travelInterests: _readStringList(
          JsonUtils.pick(json, ['travelInterests', 'TravelInterests'])),
      nationalityType: JsonUtils.readString(
              JsonUtils.pick(json, ['nationalityType', 'NationalityType'])) ??
          'vietnamese',
      preferredCity: JsonUtils.readString(
          JsonUtils.pick(json, ['preferredCity', 'PreferredCity'])),
      preferredCountry: JsonUtils.readString(
          JsonUtils.pick(json, ['preferredCountry', 'PreferredCountry'])),
    );
  }
}

class PersonalizedRecommendationModel {
  final String sessionId;
  final String summary;
  final TourPreferenceQuestionnaireModel? appliedProfile;
  final WeatherAdviceModel? weatherAdvice;
  final ScheduleAvailabilityModel? scheduleAvailability;
  final List<String> generalTips;
  final List<String> foreignVisitorTips;
  final List<String> elderlyCompanionTips;
  final List<String> childrenCompanionTips;
  final List<TourRecommendationModel> recommendedTours;
  final List<TourRecommendationModel> nearbyScheduleTours;
  final List<TourismInsightModel> relatedInsights;
  final List<CulturalFactModel> culturalFacts;
  final RecommenderMetaModel? recommenderMeta;

  PersonalizedRecommendationModel({
    required this.sessionId,
    required this.summary,
    this.appliedProfile,
    this.weatherAdvice,
    this.scheduleAvailability,
    this.generalTips = const [],
    this.foreignVisitorTips = const [],
    this.elderlyCompanionTips = const [],
    this.childrenCompanionTips = const [],
    this.recommendedTours = const [],
    this.nearbyScheduleTours = const [],
    this.relatedInsights = const [],
    this.culturalFacts = const [],
    this.recommenderMeta,
  });

  factory PersonalizedRecommendationModel.fromJson(Map<String, dynamic> json) {
    final profile = JsonUtils.pick(json, ['appliedProfile', 'AppliedProfile']);
    final weather = JsonUtils.pick(json, ['weatherAdvice', 'WeatherAdvice']);
    final schedule = JsonUtils.pick(json, [
      'scheduleAvailability',
      'ScheduleAvailability',
    ]);
    final meta = JsonUtils.pick(json, ['recommenderMeta', 'RecommenderMeta']);
    final tours = JsonUtils.readMapList(
      JsonUtils.pick(json, ['recommendedTours', 'RecommendedTours']),
    );
    final nearbyTours = JsonUtils.readMapList(
      JsonUtils.pick(json, ['nearbyScheduleTours', 'NearbyScheduleTours']),
    );
    final insights = JsonUtils.readMapList(
      JsonUtils.pick(json, ['relatedInsights', 'RelatedInsights']),
    );
    final facts = JsonUtils.readMapList(
      JsonUtils.pick(json, ['culturalFacts', 'CulturalFacts']),
    );

    return PersonalizedRecommendationModel(
      sessionId: JsonUtils.readString(
            JsonUtils.pick(json, ['sessionId', 'SessionId']),
          ) ??
          '',
      summary: JsonUtils.readString(
            JsonUtils.pick(json, ['summary', 'Summary']),
          ) ??
          '',
      appliedProfile: profile is Map<String, dynamic>
          ? TourPreferenceQuestionnaireModel.fromJson(profile)
          : null,
      weatherAdvice: weather is Map<String, dynamic>
          ? WeatherAdviceModel.fromJson(weather)
          : null,
      scheduleAvailability: schedule is Map<String, dynamic>
          ? ScheduleAvailabilityModel.fromJson(schedule)
          : null,
      generalTips: _readStringList(
        JsonUtils.pick(json, ['generalTips', 'GeneralTips']),
      ),
      foreignVisitorTips: _readStringList(
        JsonUtils.pick(json, ['foreignVisitorTips', 'ForeignVisitorTips']),
      ),
      elderlyCompanionTips: _readStringList(
        JsonUtils.pick(json, ['elderlyCompanionTips', 'ElderlyCompanionTips']),
      ),
      childrenCompanionTips: _readStringList(
        JsonUtils.pick(
            json, ['childrenCompanionTips', 'ChildrenCompanionTips']),
      ),
      recommendedTours: tours.map(TourRecommendationModel.fromJson).toList(),
      nearbyScheduleTours:
          nearbyTours.map(TourRecommendationModel.fromJson).toList(),
      relatedInsights: insights.map(TourismInsightModel.fromJson).toList(),
      culturalFacts: facts.map(CulturalFactModel.fromJson).toList(),
      recommenderMeta: meta is Map<String, dynamic>
          ? RecommenderMetaModel.fromJson(meta)
          : null,
    );
  }
}

class WeatherAdviceModel {
  final String city;
  final String dataSource;
  final DateTime? periodStart;
  final DateTime? periodEnd;
  final double? avgMaxTempC;
  final double? avgMinTempC;
  final double? totalRainMm;
  final String summary;
  final String impactOnTours;

  WeatherAdviceModel({
    required this.city,
    required this.dataSource,
    this.periodStart,
    this.periodEnd,
    this.avgMaxTempC,
    this.avgMinTempC,
    this.totalRainMm,
    required this.summary,
    required this.impactOnTours,
  });

  factory WeatherAdviceModel.fromJson(Map<String, dynamic> json) {
    return WeatherAdviceModel(
      city: JsonUtils.readString(JsonUtils.pick(json, ['city', 'City'])) ?? '',
      dataSource: JsonUtils.readString(
            JsonUtils.pick(json, ['dataSource', 'DataSource']),
          ) ??
          '',
      periodStart: JsonUtils.readDateTime(
        JsonUtils.pick(json, ['periodStart', 'PeriodStart']),
      ),
      periodEnd: JsonUtils.readDateTime(
        JsonUtils.pick(json, ['periodEnd', 'PeriodEnd']),
      ),
      avgMaxTempC: JsonUtils.readDouble(
        JsonUtils.pick(json, ['avgMaxTempC', 'AvgMaxTempC']),
      ),
      avgMinTempC: JsonUtils.readDouble(
        JsonUtils.pick(json, ['avgMinTempC', 'AvgMinTempC']),
      ),
      totalRainMm: JsonUtils.readDouble(
        JsonUtils.pick(json, ['totalRainMm', 'TotalRainMm']),
      ),
      summary: JsonUtils.readString(
            JsonUtils.pick(json, ['summary', 'Summary']),
          ) ??
          '',
      impactOnTours: JsonUtils.readString(
            JsonUtils.pick(json, ['impactOnTours', 'ImpactOnTours']),
          ) ??
          '',
    );
  }
}

class ScheduleAvailabilityModel {
  final bool hasToursInPreferredWindow;
  final String preferredStartDate;
  final String preferredEndDate;
  final String customerMessage;

  ScheduleAvailabilityModel({
    required this.hasToursInPreferredWindow,
    required this.preferredStartDate,
    required this.preferredEndDate,
    required this.customerMessage,
  });

  factory ScheduleAvailabilityModel.fromJson(Map<String, dynamic> json) {
    return ScheduleAvailabilityModel(
      hasToursInPreferredWindow: JsonUtils.readBool(
        JsonUtils.pick(
          json,
          ['hasToursInPreferredWindow', 'HasToursInPreferredWindow'],
        ),
      ),
      preferredStartDate: JsonUtils.readString(
            JsonUtils.pick(json, ['preferredStartDate', 'PreferredStartDate']),
          ) ??
          '',
      preferredEndDate: JsonUtils.readString(
            JsonUtils.pick(json, ['preferredEndDate', 'PreferredEndDate']),
          ) ??
          '',
      customerMessage: JsonUtils.readString(
            JsonUtils.pick(json, ['customerMessage', 'CustomerMessage']),
          ) ??
          '',
    );
  }
}

class TourismInsightModel {
  final int id;
  final String name;
  final String type;
  final String? description;
  final String? city;
  final String? sourceName;
  final String? sourceUrl;
  final String? authorityLevel;

  TourismInsightModel({
    required this.id,
    required this.name,
    required this.type,
    this.description,
    this.city,
    this.sourceName,
    this.sourceUrl,
    this.authorityLevel,
  });

  factory TourismInsightModel.fromJson(Map<String, dynamic> json) {
    return TourismInsightModel(
      id: JsonUtils.readInt(JsonUtils.pick(json, ['id', 'Id'])),
      name: JsonUtils.readString(JsonUtils.pick(json, ['name', 'Name'])) ?? '',
      type: JsonUtils.readString(JsonUtils.pick(json, ['type', 'Type'])) ?? '',
      description: JsonUtils.readString(
        JsonUtils.pick(json, ['description', 'Description']),
      ),
      city: JsonUtils.readString(JsonUtils.pick(json, ['city', 'City'])),
      sourceName: JsonUtils.readString(
        JsonUtils.pick(json, ['sourceName', 'SourceName']),
      ),
      sourceUrl: JsonUtils.readString(
        JsonUtils.pick(json, ['sourceUrl', 'SourceUrl']),
      ),
      authorityLevel: JsonUtils.readString(
        JsonUtils.pick(json, ['authorityLevel', 'AuthorityLevel']),
      ),
    );
  }
}

class CulturalFactModel {
  final String fact;
  final String sourceName;
  final String sourceUrl;
  final String authorityLevel;
  final String provider;
  final String? city;

  CulturalFactModel({
    required this.fact,
    required this.sourceName,
    required this.sourceUrl,
    required this.authorityLevel,
    required this.provider,
    this.city,
  });

  factory CulturalFactModel.fromJson(Map<String, dynamic> json) {
    return CulturalFactModel(
      fact: JsonUtils.readString(JsonUtils.pick(json, ['fact', 'Fact'])) ?? '',
      sourceName: JsonUtils.readString(
            JsonUtils.pick(json, ['sourceName', 'SourceName']),
          ) ??
          '',
      sourceUrl: JsonUtils.readString(
            JsonUtils.pick(json, ['sourceUrl', 'SourceUrl']),
          ) ??
          '',
      authorityLevel: JsonUtils.readString(
            JsonUtils.pick(json, ['authorityLevel', 'AuthorityLevel']),
          ) ??
          '',
      provider: JsonUtils.readString(
            JsonUtils.pick(json, ['provider', 'Provider']),
          ) ??
          '',
      city: JsonUtils.readString(JsonUtils.pick(json, ['city', 'City'])),
    );
  }
}

class RecommenderMetaModel {
  final String modelVersion;
  final String modelFamily;
  final String aggregationFormula;
  final double fairnessAlpha;
  final List<String> personaTypesUsed;
  final Map<String, double> dimensionWeights;

  RecommenderMetaModel({
    required this.modelVersion,
    required this.modelFamily,
    required this.aggregationFormula,
    required this.fairnessAlpha,
    this.personaTypesUsed = const [],
    this.dimensionWeights = const {},
  });

  factory RecommenderMetaModel.fromJson(Map<String, dynamic> json) {
    final weights = JsonUtils.pick(json, [
      'dimensionWeights',
      'DimensionWeights',
    ]);
    return RecommenderMetaModel(
      modelVersion: JsonUtils.readString(
            JsonUtils.pick(json, ['modelVersion', 'ModelVersion']),
          ) ??
          '',
      modelFamily: JsonUtils.readString(
            JsonUtils.pick(json, ['modelFamily', 'ModelFamily']),
          ) ??
          '',
      aggregationFormula: JsonUtils.readString(
            JsonUtils.pick(json, ['aggregationFormula', 'AggregationFormula']),
          ) ??
          '',
      fairnessAlpha: JsonUtils.readDouble(
            JsonUtils.pick(json, ['fairnessAlpha', 'FairnessAlpha']),
          ) ??
          0,
      personaTypesUsed: _readStringList(
        JsonUtils.pick(json, ['personaTypesUsed', 'PersonaTypesUsed']),
      ),
      dimensionWeights: weights is Map
          ? weights.map(
              (key, value) => MapEntry(
                key.toString(),
                JsonUtils.readDouble(value) ?? 0,
              ),
            )
          : const {},
    );
  }
}

class PublicLocationModel {
  final double lat;
  final double lng;
  final String fullName;
  final String? avatarUrl;

  PublicLocationModel({
    required this.lat,
    required this.lng,
    required this.fullName,
    this.avatarUrl,
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
          'sc_pts_guest'.tr,
      avatarUrl: JsonUtils.readString(
            JsonUtils.pick(json, ['avatarUrl', 'AvatarUrl']),
          ),
    );
  }
}

List<String> _readStringList(dynamic value) {
  if (value is! List) return const [];
  return value
      .map((item) => JsonUtils.readString(item)?.trim())
      .whereType<String>()
      .where((item) => item.isNotEmpty)
      .toList();
}
