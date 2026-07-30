import '../utils/json_utils.dart';

class UserStudyScenarioModel {
  final int scenarioId;
  final String title;
  final String vignette;
  final String comparisonPair;
  final String profileQueryKey;
  final String groupType;

  UserStudyScenarioModel({
    required this.scenarioId,
    required this.title,
    required this.vignette,
    required this.comparisonPair,
    required this.profileQueryKey,
    required this.groupType,
  });

  factory UserStudyScenarioModel.fromJson(Map<String, dynamic> json) =>
      UserStudyScenarioModel(
        scenarioId: JsonUtils.readInt(json['scenarioId']),
        title: JsonUtils.readString(json['title']) ?? '',
        vignette: JsonUtils.readString(json['vignette']) ?? '',
        comparisonPair: JsonUtils.readString(json['comparisonPair']) ?? '',
        profileQueryKey: JsonUtils.readString(json['profileQueryKey']) ?? '',
        groupType: JsonUtils.readString(json['groupType']) ?? '',
      );
}

class UserStudyTourItemModel {
  final int tourId;
  final String name;
  final String? city;
  final int? minPrice;
  final int? durationDays;
  final String highlight;

  UserStudyTourItemModel({
    required this.tourId,
    required this.name,
    this.city,
    this.minPrice,
    this.durationDays,
    required this.highlight,
  });

  factory UserStudyTourItemModel.fromJson(Map<String, dynamic> json) =>
      UserStudyTourItemModel(
        tourId: JsonUtils.readInt(json['tourId']),
        name: JsonUtils.readString(json['name']) ?? '',
        city: JsonUtils.readString(json['city']),
        minPrice: JsonUtils.readInt(json['minPrice']),
        durationDays: JsonUtils.readInt(json['durationDays']),
        highlight: JsonUtils.readString(json['highlight']) ?? '',
      );
}

class UserStudyBlindListModel {
  final String label;
  final List<UserStudyTourItemModel> tours;

  UserStudyBlindListModel({
    required this.label,
    required this.tours,
  });

  factory UserStudyBlindListModel.fromJson(Map<String, dynamic> json) {
    final rawTours = JsonUtils.readMapList(json['tours']);
    return UserStudyBlindListModel(
      label: JsonUtils.readString(json['label']) ?? '',
      tours: rawTours.map((t) => UserStudyTourItemModel.fromJson(t)).toList(),
    );
  }
}

class UserStudyComparisonModel {
  final int assignmentId;
  final int scenarioId;
  final String sessionId;
  final UserStudyScenarioModel scenario;
  final UserStudyBlindListModel listA;
  final UserStudyBlindListModel listB;
  final bool alreadySubmitted;

  UserStudyComparisonModel({
    required this.assignmentId,
    required this.scenarioId,
    required this.sessionId,
    required this.scenario,
    required this.listA,
    required this.listB,
    required this.alreadySubmitted,
  });

  factory UserStudyComparisonModel.fromJson(Map<String, dynamic> json) =>
      UserStudyComparisonModel(
        assignmentId: JsonUtils.readInt(json['assignmentId']),
        scenarioId: JsonUtils.readInt(json['scenarioId']),
        sessionId: JsonUtils.readString(json['sessionId']) ?? '',
        scenario: UserStudyScenarioModel.fromJson(
          json['scenario'] is Map<String, dynamic> ? json['scenario'] : {},
        ),
        listA: UserStudyBlindListModel.fromJson(
          json['listA'] is Map<String, dynamic> ? json['listA'] : {},
        ),
        listB: UserStudyBlindListModel.fromJson(
          json['listB'] is Map<String, dynamic> ? json['listB'] : {},
        ),
        alreadySubmitted: JsonUtils.readBool(json['alreadySubmitted']),
      );
}

class SubmitUserStudyResponseModel {
  final int assignmentId;
  final String sessionId;
  final String preferredList;
  final int fairnessListA;
  final int fairnessListB;
  final int satisfactionListA;
  final int satisfactionListB;
  final int groupFairnessListA;
  final int groupFairnessListB;
  final int wouldBookListA;
  final int wouldBookListB;
  final String? ageGroup;
  final String? travelExperience;
  final String? openComment;

  SubmitUserStudyResponseModel({
    required this.assignmentId,
    required this.sessionId,
    required this.preferredList,
    required this.fairnessListA,
    required this.fairnessListB,
    required this.satisfactionListA,
    required this.satisfactionListB,
    required this.groupFairnessListA,
    required this.groupFairnessListB,
    required this.wouldBookListA,
    required this.wouldBookListB,
    this.ageGroup,
    this.travelExperience,
    this.openComment,
  });

  Map<String, dynamic> toJson() => {
        'assignmentId': assignmentId,
        'sessionId': sessionId,
        'preferredList': preferredList,
        'fairnessListA': fairnessListA,
        'fairnessListB': fairnessListB,
        'satisfactionListA': satisfactionListA,
        'satisfactionListB': satisfactionListB,
        'groupFairnessListA': groupFairnessListA,
        'groupFairnessListB': groupFairnessListB,
        'wouldBookListA': wouldBookListA,
        'wouldBookListB': wouldBookListB,
        'ageGroup': ageGroup,
        'travelExperience': travelExperience,
        'openComment': openComment,
      };
}

class SubmitUserStudyResponseResultModel {
  final int responseId;
  final String message;

  SubmitUserStudyResponseResultModel({
    required this.responseId,
    required this.message,
  });

  factory SubmitUserStudyResponseResultModel.fromJson(
          Map<String, dynamic> json) =>
      SubmitUserStudyResponseResultModel(
        responseId: JsonUtils.readInt(json['responseId']),
        message: JsonUtils.readString(json['message']) ?? '',
      );
}
