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

const _stepsPerPage = 3;

class AiQuestionnaireScreen extends StatefulWidget {
  const AiQuestionnaireScreen({super.key});

  @override
  State<AiQuestionnaireScreen> createState() => _AiQuestionnaireScreenState();
}

class _AiQuestionnaireScreenState extends State<AiQuestionnaireScreen> {
  late final AiController _ai;
  var _step = 0;
  final _values = <String, dynamic>{
    'hasElderly': false,
    'hasChildren': false,
    'top': 8,
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
        if (field.inputType == 'multi_select' && _values[field.fieldKey] == null) {
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
        i + _stepsPerPage > questions.length ? questions.length : i + _stepsPerPage,
      ));
    }
    chunks.add([]); // extra step
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
    final fieldErrors = _isLastStep
        ? validateExtraCounts(_values)
        : validateQuestionnaireStep(steps[_step], _values);
    if (!_isLastStep) {
      fieldErrors.addAll(validateExtraCounts(_values));
    }
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
        ...validateExtraCounts(_values),
      };
      if (allErrors.isNotEmpty) {
        setState(() => _errors..clear()..addAll(allErrors));
        return;
      }
      final payload = buildRecommendPayload(
        _values,
        getOrCreateAiSessionId(),
      );
      final ok = await _ai.submitQuestionnaire(payload);
      if (ok && mounted) {
        Get.offNamed(AppRoutes.aiRecommendations);
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
    return AppScreen(
      title: 'Trợ lý AI',
      body: Obx(() {
        if (_ai.questionnaireLoading.value &&
            _ai.questionnaire.value == null) {
          return const LoadingWidget(message: 'Đang tải khảo sát...');
        }
        final questions = _ai.questionnaire.value?.questions ?? [];
        if (questions.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Không tải được khảo sát AI'),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _ai.loadQuestionnaire,
                    child: const Text('Thử lại'),
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
                        'Bước ${_step + 1}/$total',
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
                  LinearProgressIndicator(
                    value: progress,
                    backgroundColor: AppColors.brandLight,
                    color: AppColors.brand,
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                children: _isLastStep
                    ? _buildExtraStep()
                    : _buildFields(steps[_step]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Row(
                children: [
                  if (_step > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => setState(() {
                          _step--;
                          _errors.clear();
                        }),
                        child: const Text('Quay lại'),
                      ),
                    ),
                  if (_step > 0) const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: Obx(
                      () => CustomButton(
                        label: _isLastStep ? 'Nhận gợi ý tour' : 'Tiếp tục',
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
      }),
    );
  }

  List<Widget> _buildFields(List<QuestionnaireField> fields) {
    return fields.map(_fieldWidget).toList();
  }

  Widget _fieldWidget(QuestionnaireField field) {
    final err = _errors[field.fieldKey];
    Widget input;
    switch (field.inputType) {
      case 'single_select':
        input = DropdownButtonFormField<String>(
          initialValue: _values[field.fieldKey] as String?,
          decoration: InputDecoration(
            labelText: field.label,
            errorText: err,
          ),
          items: field.options
              .map(
                (o) => DropdownMenuItem(value: o.value, child: Text(o.label)),
              )
              .toList(),
          onChanged: (v) => setState(() {
            _values[field.fieldKey] = v;
            _errors.remove(field.fieldKey);
          }),
        );
      case 'multi_select':
        final selected = (_values[field.fieldKey] as List?)?.cast<String>() ??
            <String>[];
        input = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(field.label, style: const TextStyle(fontWeight: FontWeight.w600)),
            if (field.hint != null)
              Text(field.hint!, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: field.options.map((o) {
                final on = selected.contains(o.value);
                return FilterChip(
                  label: Text(o.label),
                  selected: on,
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
            ),
            if (err != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(err, style: const TextStyle(color: Colors.red)),
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
        input = CustomTextField(
          controller: _controllerFor(field.fieldKey),
          label: field.label,
          keyboardType: TextInputType.number,
          onChanged: (v) => _values[field.fieldKey] = v,
          validator: (_) => err,
        );
      case 'boolean':
        input = SwitchListTile(
          title: Text(field.label),
          value: _values[field.fieldKey] == true,
          onChanged: (v) => setState(() {
            _values[field.fieldKey] = v;
            _errors.remove(field.fieldKey);
          }),
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

  List<Widget> _buildExtraStep() {
    return [
      Text(
        'Thông tin bổ sung',
        style: AppTextStyles.textTheme.titleMedium,
      ),
      const SizedBox(height: 8),
      Text(
        'Số người cao tuổi/trẻ em và số tour gợi ý (tuỳ chọn).',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      const SizedBox(height: 16),
      SwitchListTile(
        title: const Text('Có người cao tuổi'),
        value: _values['hasElderly'] == true,
        onChanged: (v) => setState(() => _values['hasElderly'] = v),
      ),
      if (_values['hasElderly'] == true)
        CustomTextField(
          controller: _controllerFor('elderlyCount'),
          label: 'Số người cao tuổi',
          keyboardType: TextInputType.number,
          onChanged: (v) => _values['elderlyCount'] = v,
          validator: (_) => _errors['elderlyCount'],
        ),
      SwitchListTile(
        title: const Text('Có trẻ em'),
        value: _values['hasChildren'] == true,
        onChanged: (v) => setState(() => _values['hasChildren'] = v),
      ),
      if (_values['hasChildren'] == true)
        CustomTextField(
          controller: _controllerFor('childrenCount'),
          label: 'Số trẻ em',
          keyboardType: TextInputType.number,
          onChanged: (v) => _values['childrenCount'] = v,
          validator: (_) => _errors['childrenCount'],
        ),
      CustomTextField(
        controller: _controllerFor('top'),
        label: 'Số tour gợi ý (1–30)',
        keyboardType: TextInputType.number,
        onChanged: (v) => _values['top'] = v,
        validator: (_) => _errors['top'],
      ),
    ];
  }
}
