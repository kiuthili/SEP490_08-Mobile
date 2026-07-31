import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../controllers/feature_controllers.dart';
import '../../models/ai_models.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/ai_session.dart';
import '../../utils/questionnaire_validation.dart';
import '../../widgets/app_screen.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/loading_widget.dart';
import 'ai_chat_tab.dart';
import 'package:stayhub_mobile/theme/app_radius.dart';

const _stepsPerPage = 3;

class AiQuestionnaireScreen extends StatefulWidget {
  const AiQuestionnaireScreen({super.key});

  @override
  State<AiQuestionnaireScreen> createState() => _AiQuestionnaireScreenState();
}

class _AiQuestionnaireScreenState extends State<AiQuestionnaireScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: AppScreen(
        title: 'StayHub AI',
        bottom: TabBar(
          controller: _tabController,
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: AppColors.border,
          labelColor: AppColors.brand,
          unselectedLabelColor: AppColors.textSecondary,
          indicator: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: AppColors.brand, width: 2.5),
            ),
          ),
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.chat_bubble_outline, size: 18),
                  const SizedBox(width: 8),
                  Text('ai_tab_chatbot'.tr),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.assignment_outlined, size: 18),
                  const SizedBox(width: 8),
                  Text('ai_tab_form'.tr),
                ],
              ),
            ),
          ],
        ),
        body: ColoredBox(
          color: AppColors.surfaceGrouped,
          child: TabBarView(
            controller: _tabController,
            children: [
              AiChatTab(onSwitchToGuide: () => _tabController.animateTo(1)),
              AiQuestionnaireTab(
                onCompleted: () => Get.toNamed(AppRoutes.aiRecommendations),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AiQuestionnaireTab extends StatefulWidget {
  const AiQuestionnaireTab({super.key, this.onCompleted});

  final VoidCallback? onCompleted;

  @override
  State<AiQuestionnaireTab> createState() => _AiQuestionnaireTabState();
}

class _AiQuestionnaireTabState extends State<AiQuestionnaireTab> {
  late final AiController _ai;
  var _step = 0;
  final _values = <String, dynamic>{
    'adultCount': 1,
    'childrenCount': 0,
    'elderlyCount': 0,
    'top': 10,
  };
  final _errors = <String, String>{};
  final _textControllers = <String, TextEditingController>{};

  @override
  void initState() {
    super.initState();
    _ai = Get.find<AiController>();
    if (_ai.questionnaire.value == null) {
      _ai.loadQuestionnaire().then((_) => _initDefaults());
    } else {
      _initDefaults();
    }
  }

  void _initDefaults() {
    final q = _ai.questionnaire.value?.questions ?? [];
    setState(() {
      for (final field in q) {
        if (field.inputType == 'boolean' && _values[field.fieldKey] == null) {
          _values[field.fieldKey] = false;
        }
        if (field.inputType == 'multi_select' &&
            _values[field.fieldKey] == null) {
          _values[field.fieldKey] = <String>[];
        }
      }
    });
  }

  @override
  void dispose() {
    for (final c in _textControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  List<List<QuestionnaireField>> get _steps {
    final questions = _ai.questionnaire.value?.questions ?? [];
    final chunks = <List<QuestionnaireField>>[];
    for (var i = 0; i < questions.length; i += _stepsPerPage) {
      chunks.add(questions.sublist(
        i,
        i + _stepsPerPage > questions.length
            ? questions.length
            : i + _stepsPerPage,
      ));
    }
    return chunks;
  }

  bool get _isLastStep => _step >= _steps.length - 1;

  TextEditingController _controllerFor(String key) {
    return _textControllers.putIfAbsent(
      key,
      () => TextEditingController(text: _values[key]?.toString() ?? ''),
    );
  }

  Future<void> _pickDate(String key) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked != null) {
      final s = DateFormat('yyyy-MM-dd').format(picked);
      setState(() {
        _values[key] = s;
        _controllerFor(key).text = s;
        _errors.remove(key);
      });
    }
  }

  bool _validateCurrent() {
    final steps = _steps;
    final fieldErrors = validateQuestionnaireStep(steps[_step], _values);
    setState(() => _errors
      ..clear()
      ..addAll(fieldErrors));
    return fieldErrors.isEmpty;
  }

  Future<void> _next() async {
    if (!_validateCurrent()) return;
    if (_isLastStep) {
      final questions = _ai.questionnaire.value?.questions ?? [];
      final allErrors = {
        ...validateQuestionnaireStep(questions, _values),
      };
      if (allErrors.isNotEmpty) {
        setState(() => _errors
          ..clear()
          ..addAll(allErrors));
        return;
      }
      final payload = buildRecommendPayload(
        _values,
        getOrCreateAiSessionId(),
      );
      final ok = await _ai.submitQuestionnaire(payload);
      if (ok && mounted) {
        final onCompleted = widget.onCompleted;
        if (onCompleted != null) {
          onCompleted();
        } else {
          Get.offNamed(AppRoutes.aiRecommendations);
        }
      }
      return;
    }
    setState(() {
      _step++;
      _errors.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (_ai.questionnaireLoading.value && _ai.questionnaire.value == null) {
        return LoadingWidget(message: 'ai_loading_questionnaire'.tr);
      }
      final questions = _ai.questionnaire.value?.questions ?? [];
      if (questions.isEmpty) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('ai_error_loading'.tr),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _ai.loadQuestionnaire,
                  child: Text('ai_retry'.tr),
                ),
              ],
            ),
          ),
        );
      }

      final steps = _steps;
      final total = steps.length;
      final progress = ((_step + 1) / total).clamp(0.0, 1.0);

      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.auto_awesome, color: AppColors.brand),
                    const SizedBox(width: 8),
                    Text(
                      'ai_step'.trParams({
                        'current': (_step + 1).toString(),
                        'total': total.toString(),
                      }),
                      style: AppTextStyles.textTheme.titleSmall,
                    ),
                    const Spacer(),
                    Text(
                      '${(progress * 100).round()}%',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(100),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: AppColors.brandLight,
                    color: AppColors.brand,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              children: _buildFields(steps[_step]),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              8,
              20,
              MediaQuery.paddingOf(context).bottom + 12,
            ),
            child: Row(
              children: [
                if (_step > 0)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setState(() {
                        _step--;
                        _errors.clear();
                      }),
                      style: OutlinedButton.styleFrom(shape: const StadiumBorder()),
                      child: Text('ai_back'.tr, style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                if (_step > 0) const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: Obx(
                    () => CustomButton(
                      label: _isLastStep
                          ? 'ai_get_recommendations'.tr
                          : 'ai_continue'.tr,
                      isLoading: _ai.questionnaireSubmitting.value,
                      onPressed: _next,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    });
  }

  List<Widget> _buildFields(List<QuestionnaireField> fields) {
    return fields.map(_fieldWidget).toList();
  }

  Widget _fieldWidget(QuestionnaireField field) {
    final err = _errors[field.fieldKey];
    Widget input;
    switch (field.inputType) {
      case 'single_select':
        final selectedValue = _values[field.fieldKey] as String?;
        input = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RichText(
              text: TextSpan(
                text: field.label,
                style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: AppColors.textPrimary),
                children: [
                  if (field.required)
                    const TextSpan(
                        text: ' *', style: TextStyle(color: AppColors.error)),
                ],
              ),
            ),
            if (field.hint != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(field.hint!,
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textSecondary)),
              ),
            const SizedBox(height: 12),
            Builder(
              builder: (context) {
                final queryKey = 'search_query_${field.fieldKey}';
                final query = _values[queryKey] as String? ?? '';
                final showSearch = field.options.length > 8;
                final filteredOptions = showSearch
                    ? field.options
                        .where((o) =>
                            o.label.toLowerCase().contains(query.toLowerCase()))
                        .toList()
                    : field.options;

                final optionsList = Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: filteredOptions.map((o) {
                    final on = selectedValue == o.value;
                    return ChoiceChip(
                      label: Text(o.label),
                      selected: on,
                      selectedColor: AppColors.brand.withValues(alpha: 0.1),
                      labelStyle: TextStyle(
                        color: on ? AppColors.brand : AppColors.textSecondary,
                        fontWeight: on ? FontWeight.bold : FontWeight.normal,
                      ),
                      shape: const StadiumBorder(side: BorderSide.none),
                      backgroundColor: AppColors.surface,
                      onSelected: (v) => setState(() {
                        if (v) {
                          _values[field.fieldKey] = o.value;
                          _errors.remove(field.fieldKey);
                        }
                      }),
                    );
                  }).toList(),
                );

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showSearch) ...[
                      TextField(
                        decoration: InputDecoration(
                          hintText: 'Tìm kiếm địa điểm...',
                          prefixIcon: const Icon(Icons.search, size: 16),
                        ),
                        onChanged: (val) => setState(() {
                          _values[queryKey] = val;
                        }),
                      ),
                      const SizedBox(height: 10),
                    ],
                    showSearch
                        ? Container(
                            constraints: const BoxConstraints(maxHeight: 180),
                            child: SingleChildScrollView(
                              physics: const BouncingScrollPhysics(),
                              child: optionsList,
                            ),
                          )
                        : optionsList,
                  ],
                );
              },
            ),
            if (err != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(err,
                    style: const TextStyle(
                        color: AppColors.error,
                        fontSize: 12,
                        fontWeight: FontWeight.bold)),
              ),
          ],
        );
      case 'multi_select':
        final selected =
            (_values[field.fieldKey] as List?)?.cast<String>() ?? <String>[];
        input = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RichText(
              text: TextSpan(
                text: field.label,
                style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: AppColors.textPrimary),
                children: [
                  if (field.required)
                    const TextSpan(
                        text: ' *', style: TextStyle(color: AppColors.error)),
                ],
              ),
            ),
            if (field.hint != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(field.hint!,
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textSecondary)),
              ),
            const SizedBox(height: 12),
            Builder(
              builder: (context) {
                final queryKey = 'search_query_${field.fieldKey}';
                final query = _values[queryKey] as String? ?? '';
                final showSearch = field.options.length > 8;
                final filteredOptions = showSearch
                    ? field.options
                        .where((o) =>
                            o.label.toLowerCase().contains(query.toLowerCase()))
                        .toList()
                    : field.options;

                final optionsList = Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: filteredOptions.map((o) {
                    final on = selected.contains(o.value);
                    return FilterChip(
                      label: Text(o.label),
                      selected: on,
                      selectedColor: AppColors.brand.withValues(alpha: 0.1),
                      checkmarkColor: AppColors.brand,
                      labelStyle: TextStyle(
                        color: on ? AppColors.brand : AppColors.textSecondary,
                        fontWeight: on ? FontWeight.bold : FontWeight.normal,
                      ),
                      shape: const StadiumBorder(side: BorderSide.none),
                      backgroundColor: AppColors.surface,
                      onSelected: (v) => setState(() {
                        final list = List<String>.from(selected);
                        if (v) {
                          list.add(o.value);
                        } else {
                          list.remove(o.value);
                        }
                        _values[field.fieldKey] = list;
                        _errors.remove(field.fieldKey);
                      }),
                    );
                  }).toList(),
                );

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showSearch) ...[
                      TextField(
                        decoration: InputDecoration(
                          hintText: 'Tìm kiếm lựa chọn...',
                          prefixIcon: const Icon(Icons.search, size: 16),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide:
                                const BorderSide(color: AppColors.border),
                          ),
                        ),
                        onChanged: (val) => setState(() {
                          _values[queryKey] = val;
                        }),
                      ),
                      const SizedBox(height: 10),
                    ],
                    showSearch
                        ? Container(
                            constraints: const BoxConstraints(maxHeight: 180),
                            child: SingleChildScrollView(
                              physics: const BouncingScrollPhysics(),
                              child: optionsList,
                            ),
                          )
                        : optionsList,
                  ],
                );
              },
            ),
            if (err != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(err,
                    style: const TextStyle(
                        color: AppColors.error,
                        fontSize: 12,
                        fontWeight: FontWeight.bold)),
              ),
          ],
        );
      case 'date':
        input = GestureDetector(
          onTap: () => _pickDate(field.fieldKey),
          child: AbsorbPointer(
            child: CustomTextField(
              controller: _controllerFor(field.fieldKey),
              label: field.label,
              validator: (_) => err,
            ),
          ),
        );
      case 'number':
        if (['adultCount', 'childrenCount', 'elderlyCount']
            .contains(field.fieldKey)) {
          final count =
              int.tryParse(_values[field.fieldKey]?.toString() ?? '0') ?? 0;
          input = Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    field.label,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      color: count > (field.fieldKey == 'adultCount' ? 1 : 0)
                          ? AppColors.brand
                          : AppColors.textSecondary,
                      onPressed:
                          count > (field.fieldKey == 'adultCount' ? 1 : 0)
                              ? () => setState(() {
                                    _values[field.fieldKey] = count - 1;
                                    _errors.remove(field.fieldKey);
                                  })
                              : null,
                    ),
                    SizedBox(
                      width: 24,
                      child: Text(
                        '$count',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      color: count < 20
                          ? AppColors.brand
                          : AppColors.textSecondary,
                      onPressed: count < 20
                          ? () => setState(() {
                                _values[field.fieldKey] = count + 1;
                                _errors.remove(field.fieldKey);
                              })
                          : null,
                    ),
                  ],
                ),
              ],
            ),
          );
        } else if (field.fieldKey == 'maxBudgetPerPerson') {
          final numericValue =
              double.tryParse(_values[field.fieldKey]?.toString() ?? '0') ?? 0;
          final displayValue = numericValue > 0
              ? NumberFormat('#,###').format(numericValue)
              : 'ai_unlimited'.tr;
          input = Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      field.label,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: AppColors.textSecondary),
                    ),
                    Row(
                      children: [
                        Text(
                          displayValue,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: AppColors.brand),
                        ),
                        if (numericValue > 0)
                          const Padding(
                            padding: EdgeInsets.only(left: 4),
                            child: Text(
                              'VND',
                              style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 13,
                                  color: AppColors.textSecondary),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SliderTheme(
                  data: SliderThemeData(
                    activeTrackColor: AppColors.brand,
                    inactiveTrackColor: AppColors.border,
                    thumbColor: AppColors.brand,
                    trackHeight: 6,
                    overlayShape: SliderComponentShape.noOverlay,
                  ),
                  child: Slider(
                    min: 0,
                    max: 20000000,
                    divisions: 40,
                    value: numericValue.clamp(0, 20000000).toDouble(),
                    onChanged: (val) {
                      setState(() {
                        _values[field.fieldKey] =
                            val == 0 ? '' : val.toInt().toString();
                        _errors.remove(field.fieldKey);
                      });
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('ai_unlimited'.tr,
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary)),
                    const Text('20,000,000+ VND',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary)),
                  ],
                ),
                if (err != null) ...[
                  const SizedBox(height: 8),
                  Text(err,
                      style: const TextStyle(
                          color: AppColors.error,
                          fontSize: 12,
                          fontWeight: FontWeight.bold)),
                ]
              ],
            ),
          );
        } else {
          input = CustomTextField(
            controller: _controllerFor(field.fieldKey),
            label: field.label,
            keyboardType: TextInputType.number,
            onChanged: (v) => _values[field.fieldKey] = v,
            validator: (_) => err,
          );
        }
      case 'boolean':
        input = Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: SwitchListTile(
            title: Text(field.label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            value: _values[field.fieldKey] == true,
            activeColor: AppColors.brand,
            onChanged: (v) => setState(() {
              _values[field.fieldKey] = v;
              _errors.remove(field.fieldKey);
            }),
          ),
        );
      default:
        input = CustomTextField(
          controller: _controllerFor(field.fieldKey),
          label: field.label,
          onChanged: (v) => _values[field.fieldKey] = v,
          validator: (_) => err,
        );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: input,
    );
  }
}
