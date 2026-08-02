import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../routes/app_routes.dart';
import '../services/tutorial_service.dart';
import '../theme/app_colors.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, dynamic>> _onboardingData = [
    {
      'icon': Icons.explore_rounded,
      'title': 'onboarding_title_1',
      'desc': 'onboarding_desc_1',
      'color': const Color(0xFF4FC3F7),
    },
    {
      'icon': Icons.book_online_rounded,
      'title': 'onboarding_title_2',
      'desc': 'onboarding_desc_2',
      'color': const Color(0xFF81C784),
    },
    {
      'icon': Icons.map_rounded,
      'title': 'onboarding_title_3',
      'desc': 'onboarding_desc_3',
      'color': const Color(0xFFFFB74D),
    },
  ];

  void _onNext() {
    if (_currentPage == _onboardingData.length - 1) {
      _finishOnboarding();
    } else {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _finishOnboarding() {
    Get.find<TutorialService>().completeOnboarding();
    Get.offAllNamed(AppRoutes.home);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // PageView
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemCount: _onboardingData.length,
                itemBuilder: (context, index) {
                  final data = _onboardingData[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Icon Circle
                        Container(
                          width: 200,
                          height: 200,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: data['color'].withOpacity(0.15),
                          ),
                          child: Center(
                            child: Icon(
                              data['icon'],
                              size: 100,
                              color: data['color'],
                            ),
                          ),
                        ),
                        const SizedBox(height: 60),
                        // Title
                        Text(
                          data['title'].toString().tr,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: AppColors.navy,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Description
                        Text(
                          data['desc'].toString().tr,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Bottom Controls
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Skip Button
                  TextButton(
                    onPressed: _finishOnboarding,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey.shade600,
                    ),
                    child: Text(
                      'tutorial_skip'.tr,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),

                  // Dots Indicator
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(
                      _onboardingData.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        height: 8,
                        width: _currentPage == index ? 24 : 8,
                        decoration: BoxDecoration(
                          color: _currentPage == index ? AppColors.brand : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),

                  // Next / Start Button
                  ElevatedButton(
                    onPressed: _onNext,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brand,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: Text(
                      _currentPage == _onboardingData.length - 1
                          ? 'onboarding_start'.tr
                          : 'onboarding_next'.tr,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
