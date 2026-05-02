import 'package:shared_preferences/shared_preferences.dart';

class SessionLockService {
  static const String _lockDateKey = 'lumi_sleep_date_';

  /// Locks the device for the specific child for the rest of the current day.
  static Future<void> lockDeviceForToday(int childId) async {
    final prefs = await SharedPreferences.getInstance();
    // Get today's date in YYYY-MM-DD format
    final today = DateTime.now().toIso8601String().substring(0, 10); 
    await prefs.setString('$_lockDateKey$childId', today);
  }

  /// Checks if the child is locked out for the current day.
  static Future<bool> isLockedToday(int childId) async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final lockedDate = prefs.getString('$_lockDateKey$childId');
    
    // If the locked date matches today's date, they are locked out.
    return lockedDate == today;
  }
}