import 'package:shared_preferences/shared_preferences.dart';

/// Persists parent-led onboarding and per-child distance setup flags.
class OnboardingService {
  OnboardingService._();
  static final OnboardingService instance = OnboardingService._();

  static const _parentDoneKey = 'lumi_parent_onboarding_done';
  static String _calibKey(int childId) => 'lumi_calib_done_$childId';

  Future<bool> isParentOnboardingDone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_parentDoneKey) ?? false;
  }

  Future<void> markParentOnboardingDone() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_parentDoneKey, true);
  }

  Future<bool> isCalibrationDone(int childId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_calibKey(childId)) ?? false;
  }

  Future<void> markCalibrationDone(int childId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_calibKey(childId), true);
  }

  /// Child may use the app once parent finished onboarding (camera setup).
  Future<bool> isChildReadyToUse() async {
    return isParentOnboardingDone();
  }
}
