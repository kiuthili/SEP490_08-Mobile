import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

class TutorialService extends GetxService {
  final _storage = GetStorage();
  
  static const _onboardingKey = 'hasSeenOnboarding';
  static const _homeTutorialKey = 'isHomeTutorialDone';
  static const _loginTutorialKey = 'isLoginTutorialDone';

  // Global Keys for cross-screen targeting
  final GlobalKey loginTabKey = GlobalKey();

  // Biến observable
  final RxBool hasSeenOnboarding = false.obs;
  final RxBool isHomeTutorialDone = false.obs;
  final RxBool isLoginTutorialDone = false.obs;

  @override
  void onInit() {
    super.onInit();
    hasSeenOnboarding.value = _storage.read<bool>(_onboardingKey) ?? false;
    isHomeTutorialDone.value = _storage.read<bool>(_homeTutorialKey) ?? false;
    isLoginTutorialDone.value = _storage.read<bool>(_loginTutorialKey) ?? false;
  }

  Future<void> completeOnboarding() async {
    await _storage.write(_onboardingKey, true);
    hasSeenOnboarding.value = true;
  }

  Future<void> completeHomeTutorial() async {
    await _storage.write(_homeTutorialKey, true);
    isHomeTutorialDone.value = true;
  }

  Future<void> completeLoginTutorial() async {
    await _storage.write(_loginTutorialKey, true);
    isLoginTutorialDone.value = true;
  }
}
