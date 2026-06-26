import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/user_study_controller.dart';
import '../../models/user_study_models.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/snackbar_helper.dart';

class UserStudyScreen extends StatefulWidget {
  const UserStudyScreen({super.key});

  @override
  State<UserStudyScreen> createState() => _UserStudyScreenState();
}

class _UserStudyScreenState extends State<UserStudyScreen> {
  late final UserStudyController _controller;
  int? _selectedScenarioId;

  // Survey Form States
  int _fairnessA = 0;
  int _fairnessB = 0;
  int _groupFairnessA = 0;
  int _groupFairnessB = 0;
  int _satisfactionA = 0;
  int _satisfactionB = 0;
  int _wouldBookA = 0;
  int _wouldBookB = 0;
  String _preferredList = '';
  String? _ageGroup;
  String? _travelExperience;
  final _commentController = TextEditingController();

  final List<String> _ageGroups = [
    '< 18',
    '18-24',
    '25-34',
    '35-44',
    '45-54',
    '55-64',
    '65+'
  ];

  final List<String> _experiences = [
    'Chưa từng',
    'Thỉnh thoảng',
    'Thường xuyên'
  ];

  @override
  void initState() {
    super.initState();
    _controller = Get.find<UserStudyController>();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _resetSurvey() {
    setState(() {
      _fairnessA = 0;
      _fairnessB = 0;
      _groupFairnessA = 0;
      _groupFairnessB = 0;
      _satisfactionA = 0;
      _satisfactionB = 0;
      _wouldBookA = 0;
      _wouldBookB = 0;
      _preferredList = '';
      _ageGroup = null;
      _travelExperience = null;
      _commentController.clear();
    });
  }

  Future<void> _submitSurvey(UserStudyComparisonModel comparison) async {
    if (_fairnessA == 0 ||
        _fairnessB == 0 ||
        _groupFairnessA == 0 ||
        _groupFairnessB == 0 ||
        _satisfactionA == 0 ||
        _satisfactionB == 0 ||
        _wouldBookA == 0 ||
        _wouldBookB == 0 ||
        _preferredList.isEmpty) {
      SnackbarHelper.error(
        'Vui lòng đánh giá đủ 1–7 điểm cho cả 2 danh sách và chọn danh sách ưu tiên.',
      );
      return;
    }

    final success = await _controller.submitResponse(
      assignmentId: comparison.assignmentId,
      preferredList: _preferredList,
      fairnessListA: _fairnessA,
      fairnessListB: _fairnessB,
      satisfactionListA: _satisfactionA,
      satisfactionListB: _satisfactionB,
      groupFairnessListA: _groupFairnessA,
      groupFairnessListB: _groupFairnessB,
      wouldBookListA: _wouldBookA,
      wouldBookListB: _wouldBookB,
      ageGroup: _ageGroup,
      travelExperience: _travelExperience,
      openComment: _commentController.text,
    );

    if (success) {
      _resetSurvey();
    }
  }

  Widget _buildScenarioList() {
    return Obx(() {
      if (_controller.isLoadingScenarios.value) {
        return const Center(child: CircularProgressIndicator());
      }

      if (_controller.scenarios.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.quiz_outlined, size: 64, color: AppColors.textSecondary),
              const SizedBox(height: 16),
              Text(
                'Không tìm thấy kịch bản nào',
                style: AppTextStyles.textTheme.titleMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        );
      }

      return RefreshIndicator(
        onRefresh: _controller.loadScenarios,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _controller.scenarios.length,
          itemBuilder: (context, index) {
            final scenario = _controller.scenarios[index];
            // Since alreadySubmitted status is only returned when fetching a specific comparison,
            // we will fetch it when the scenario is clicked.
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: AppColors.border),
              ),
              elevation: 0,
              color: AppColors.surface,
              child: InkWell(
                onTap: () {
                  setState(() {
                    _selectedScenarioId = scenario.scenarioId;
                  });
                  _resetSurvey();
                  _controller.loadComparison(scenario.scenarioId);
                },
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.brandLight,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Nhóm: ${scenario.groupType.toUpperCase()}',
                              style: const TextStyle(
                                color: AppColors.brandDeep,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 14,
                            color: AppColors.textSecondary,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        scenario.title,
                        style: AppTextStyles.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        scenario.vignette,
                        style: AppTextStyles.textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );
    });
  }

  Widget _buildTourList(List<UserStudyTourItemModel> tours) {
    if (tours.isEmpty) {
      return const Center(child: Text('Không có tour nào trong danh sách'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: tours.length,
      itemBuilder: (context, index) {
        final tour = tours[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: AppColors.border),
          ),
          elevation: 0,
          color: AppColors.surface,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tour.name,
                  style: AppTextStyles.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    if (tour.city != null) ...[
                      const Icon(Icons.location_on_outlined, size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        tour.city!,
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                      const SizedBox(width: 16),
                    ],
                    const Icon(Icons.calendar_today_outlined, size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      tour.durationDays != null && tour.durationDays! > 0
                          ? '${tour.durationDays} ngày'
                          : 'Trong ngày',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      tour.minPrice != null
                          ? CurrencyFormatter.format(tour.minPrice!)
                          : 'Liên hệ',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.brand,
                      ),
                    ),
                  ],
                ),
                if (tour.highlight.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.backgroundSecondary,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      tour.highlight,
                      style: TextStyle(
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLikertRow({
    required String title,
    required int valueA,
    required int valueB,
    required ValueChanged<int> onChangedA,
    required ValueChanged<int> onChangedB,
    required String minLabel,
    required String maxLabel,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Danh sách A:',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.brandDeep),
        ),
        const SizedBox(height: 6),
        _LikertSelector(
          selectedValue: valueA,
          onChanged: onChangedA,
          minLabel: minLabel,
          maxLabel: maxLabel,
        ),
        const SizedBox(height: 12),
        const Text(
          'Danh sách B:',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.brandDeep),
        ),
        const SizedBox(height: 6),
        _LikertSelector(
          selectedValue: valueB,
          onChanged: onChangedB,
          minLabel: minLabel,
          maxLabel: maxLabel,
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Divider(height: 1, color: AppColors.separator),
        ),
      ],
    );
  }

  Widget _buildSurveyTab(UserStudyComparisonModel comparison) {
    if (comparison.alreadySubmitted) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.check_circle_outline_rounded,
                size: 64,
                color: Colors.green,
              ),
              const SizedBox(height: 16),
              const Text(
                'Cảm ơn bạn!',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Bạn đã hoàn thành đánh giá cho kịch bản này.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _selectedScenarioId = null;
                  });
                },
                icon: const Icon(Icons.arrow_back),
                label: const Text('Quay lại danh sách'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brand,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildLikertRow(
          title: '1. Mức công bằng với cá nhân bạn',
          valueA: _fairnessA,
          valueB: _fairnessB,
          onChangedA: (val) => setState(() => _fairnessA = val),
          onChangedB: (val) => setState(() => _fairnessB = val),
          minLabel: 'Rất không công bằng',
          maxLabel: 'Rất công bằng',
        ),
        _buildLikertRow(
          title: '2. Mức công bằng cho cả nhóm/couple/gia đình',
          valueA: _groupFairnessA,
          valueB: _groupFairnessB,
          onChangedA: (val) => setState(() => _groupFairnessA = val),
          onChangedB: (val) => setState(() => _groupFairnessB = val),
          minLabel: 'Rất không công bằng',
          maxLabel: 'Rất công bằng',
        ),
        _buildLikertRow(
          title: '3. Mức độ hài lòng với danh sách gợi ý',
          valueA: _satisfactionA,
          valueB: _satisfactionB,
          onChangedA: (val) => setState(() => _satisfactionA = val),
          onChangedB: (val) => setState(() => _satisfactionB = val),
          minLabel: 'Rất không hài lòng',
          maxLabel: 'Rất hài lòng',
        ),
        _buildLikertRow(
          title: '4. Khả năng bạn sẽ đặt một tour trong danh sách',
          valueA: _wouldBookA,
          valueB: _wouldBookB,
          onChangedA: (val) => setState(() => _wouldBookA = val),
          onChangedB: (val) => setState(() => _wouldBookB = val),
          minLabel: 'Chắc chắn không',
          maxLabel: 'Chắc chắn có',
        ),

        // Preferred List selection
        const Text(
          '5. Bạn thích danh sách gợi ý nào hơn?',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Column(
          children: [
            RadioListTile<String>(
              title: const Text('Danh sách A tốt hơn'),
              value: 'A',
              groupValue: _preferredList,
              onChanged: (val) => setState(() => _preferredList = val ?? ''),
              activeColor: AppColors.brand,
            ),
            RadioListTile<String>(
              title: const Text('Danh sách B tốt hơn'),
              value: 'B',
              groupValue: _preferredList,
              onChanged: (val) => setState(() => _preferredList = val ?? ''),
              activeColor: AppColors.brand,
            ),
            RadioListTile<String>(
              title: const Text('Cả hai như nhau / Không chọn'),
              value: 'NONE',
              groupValue: _preferredList,
              onChanged: (val) => setState(() => _preferredList = val ?? ''),
              activeColor: AppColors.brand,
            ),
          ],
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Divider(height: 1, color: AppColors.separator),
        ),

        // Demographics
        const Text(
          '6. Thông tin người tham gia (Tùy chọn)',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          decoration: const InputDecoration(
            labelText: 'Nhóm tuổi',
            border: OutlineInputBorder(),
          ),
          value: _ageGroup,
          items: _ageGroups
              .map((age) => DropdownMenuItem(
                    value: age,
                    child: Text(age),
                  ))
              .toList(),
          onChanged: (val) => setState(() => _ageGroup = val),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          decoration: const InputDecoration(
            labelText: 'Tần suất đi du lịch',
            border: OutlineInputBorder(),
          ),
          value: _travelExperience,
          items: _experiences
              .map((exp) => DropdownMenuItem(
                    value: exp,
                    child: Text(exp),
                  ))
              .toList(),
          onChanged: (val) => setState(() => _travelExperience = val),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _commentController,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Ý kiến đóng góp khác',
            border: OutlineInputBorder(),
            hintText: 'Nhập chia sẻ của bạn về gợi ý tour...',
          ),
        ),
        const SizedBox(height: 24),
        Obx(() {
          final isSubmitting = _controller.isSubmitting.value;
          return ElevatedButton(
            onPressed: isSubmitting ? null : () => _submitSurvey(comparison),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brand,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: isSubmitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Text(
                    'Gửi đánh giá',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
          );
        }),
        const SizedBox(height: 48),
      ],
    );
  }

  Widget _buildComparisonView() {
    return Obx(() {
      if (_controller.isLoadingComparison.value) {
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      }

      final comparison = _controller.currentComparison.value;
      if (comparison == null) {
        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => setState(() => _selectedScenarioId = null),
            ),
            title: const Text('Đang tải...'),
          ),
          body: const Center(child: Text('Không tìm thấy dữ liệu kịch bản so sánh.')),
        );
      }

      return DefaultTabController(
        length: 3,
        child: Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => setState(() => _selectedScenarioId = null),
            ),
            title: Text(comparison.scenario.title),
            bottom: const TabBar(
              labelColor: AppColors.brand,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: AppColors.brand,
              tabs: [
                Tab(text: 'Danh sách A'),
                Tab(text: 'Danh sách B'),
                Tab(text: 'Đánh giá'),
              ],
            ),
          ),
          body: Column(
            children: [
              // Scenario Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.brandLight.withValues(alpha: 0.5),
                  border: const Border(
                    bottom: BorderSide(color: AppColors.border),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Bối cảnh giả định:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: AppColors.brandDeep,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      comparison.scenario.vignette,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textPrimary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _buildTourList(comparison.listA.tours),
                    _buildTourList(comparison.listB.tours),
                    _buildSurveyTab(comparison),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedScenarioId != null) {
      return _buildComparisonView();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Khảo sát A/B (User Study)'),
      ),
      body: _buildScenarioList(),
    );
  }
}

class _LikertSelector extends StatelessWidget {
  final int selectedValue;
  final ValueChanged<int> onChanged;
  final String minLabel;
  final String maxLabel;

  const _LikertSelector({
    required this.selectedValue,
    required this.onChanged,
    required this.minLabel,
    required this.maxLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(7, (index) {
            final val = index + 1;
            final isSelected = selectedValue == val;
            return GestureDetector(
              onTap: () => onChanged(val),
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? AppColors.brand : AppColors.brandLight,
                  border: Border.all(
                    color: isSelected ? AppColors.brand : AppColors.border,
                    width: 1.5,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  val.toString(),
                  style: TextStyle(
                    color: isSelected ? Colors.white : AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                minLabel,
                style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
              ),
            ),
            Expanded(
              child: Text(
                maxLabel,
                textAlign: TextAlign.end,
                style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
