import 'package:hive/hive.dart';

/// Kept separately from todos so replaying the guide never clears user data.
class GuidePreferences {
  static const boxName = 'preferences';
  static const seenKey = 'usageGuideSeen';

  static bool get hasSeenGuide =>
      Hive.box<dynamic>(boxName).get(seenKey, defaultValue: false) == true;

  static Future<void> markSeen() async {
    final box = Hive.box<dynamic>(boxName);
    await box.put(seenKey, true);
    await box.flush();
  }
}
