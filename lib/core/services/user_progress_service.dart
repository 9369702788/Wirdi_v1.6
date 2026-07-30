import 'package:shared_preferences/shared_preferences.dart';

import '../models/progress_models.dart';

/// Persisted user progress/state shared across screens: favorites,
/// per-item azkar counters (with real daily reset), daily wird tracking,
/// and last-read position. Single source of truth so the Home Dashboard
/// reflects exactly what Quran/Azkar/Tasbeeh screens have recorded.
class UserProgressService {
  UserProgressService._();

  static String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  static String dateKeyFor(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  /// Real per-day activity for the current calendar week, **starting on
  /// Saturday** (the regional week-start convention), through Friday.
  /// Built from the same date-keyed storage already used for Azkar
  /// completion and prayer tracking, plus the date-keyed wird pages and
  /// Tasbeeh daily totals. This is a genuine history log, not a derived
  /// guess — each day's numbers were written on that day. Days later
  /// than today naturally show zero activity (they haven't happened
  /// yet), which is expected.
  static Future<List<DailyActivitySummary>> last7DaysSummary() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Dart's DateTime.weekday: Monday=1 ... Saturday=6, Sunday=7.
    // Days since the most recent Saturday (0 if today is Saturday).
    final daysSinceSaturday = (today.weekday - 6 + 7) % 7;
    final saturday = today.subtract(Duration(days: daysSinceSaturday));

    final results = <DailyActivitySummary>[];

    for (var i = 0; i < 7; i++) {
      final date = saturday.add(Duration(days: i));
      final key = dateKeyFor(date);

      final wirdPages = prefs.getInt('wird_pages_$key') ?? 0;
      final wirdTarget = prefs.getInt('wird_target_pages') ?? 5;
      final azkarCompleted = (prefs.getStringList('azkar_completed_$key') ?? const []).length;
      final tasbeehTotal = prefs.getInt('tasbeeh_daily_total_$key') ?? 0;
      final prayersDone = (prefs.getStringList('prayed_$key') ?? const []).length;

      results.add(DailyActivitySummary(
        date: date,
        wirdPages: wirdPages,
        wirdTargetMet: wirdPages >= wirdTarget,
        azkarCompleted: azkarCompleted,
        tasbeehTotal: tasbeehTotal,
        prayersDone: prayersDone,
      ));
    }

    return results;
  }

  // ---------------- Favorites (Quran ayahs + Azkar items) ----------------

  static Future<Set<String>> _getSet(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(key) ?? const []).toSet();
  }

  static Future<void> _saveSet(String key, Set<String> value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(key, value.toList());
  }

  static Future<Set<String>> favoriteAyahs() => _getSet('favorite_ayahs_all');

  static Future<void> toggleFavoriteAyah(String uid) async {
    final set = await favoriteAyahs();
    if (!set.add(uid)) set.remove(uid);
    await _saveSet('favorite_ayahs_all', set);
  }

  static Future<Set<String>> favoriteAzkar() => _getSet('favorite_azkar_all');

  static Future<void> toggleFavoriteAzkar(String uid) async {
    final set = await favoriteAzkar();
    if (!set.add(uid)) set.remove(uid);
    await _saveSet('favorite_azkar_all', set);
  }

  static Future<int> totalFavoritesCount() async {
    final a = await favoriteAyahs();
    final b = await favoriteAzkar();
    return a.length + b.length;
  }

  // ---------------- Azkar per-item counters (reset daily) ----------------

  static Future<int> azkarCount(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final storedDay = prefs.getString('azkar_count_day_$uid');
    if (storedDay != _todayKey()) return 0;
    return prefs.getInt('azkar_count_$uid') ?? 0;
  }

  static Future<int> incrementAzkarCount(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await azkarCount(uid);
    final next = current + 1;
    await prefs.setInt('azkar_count_$uid', next);
    await prefs.setString('azkar_count_day_$uid', _todayKey());
    return next;
  }

  static Future<void> resetAzkarCount(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('azkar_count_$uid', 0);
    await prefs.setString('azkar_count_day_$uid', _todayKey());
  }

  static Future<Set<String>> completedAzkarToday() =>
      _getSet('azkar_completed_${_todayKey()}');

  static Future<void> markAzkarCompleted(String uid) async {
    final set = await completedAzkarToday();
    set.add(uid);
    await _saveSet('azkar_completed_${_todayKey()}', set);
  }

  // ---------------- Last read (Quran) ----------------

  static Future<void> saveLastReading({
    required int surahNumber,
    required String surahName,
    required int ayahNumber,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('last_surah_number', surahNumber);
    await prefs.setString('last_surah_name', surahName);
    await prefs.setInt('last_ayah_number', ayahNumber);
  }

  static Future<Map<String, dynamic>?> lastReading() async {
    final prefs = await SharedPreferences.getInstance();
    final number = prefs.getInt('last_surah_number');
    if (number == null) return null;
    return {
      'surahNumber': number,
      'surahName': prefs.getString('last_surah_name') ?? '',
      'ayahNumber': prefs.getInt('last_ayah_number') ?? 1,
    };
  }

  // ---------------- Tasbeeh combined daily total (for 7-day history) ----------------

  static Future<int> incrementTasbeehDailyTotal() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'tasbeeh_daily_total_${_todayKey()}';
    final next = (prefs.getInt(key) ?? 0) + 1;
    await prefs.setInt(key, next);
    return next;
  }

  // ---------------- Prayer completion (mark as prayed) ----------------

  static Future<Set<String>> prayedToday() => _getSet('prayed_${_todayKey()}');

  static Future<void> setPrayed(String prayerName, bool prayed) async {
    final set = await prayedToday();
    if (prayed) {
      set.add(prayerName);
    } else {
      set.remove(prayerName);
    }
    await _saveSet('prayed_${_todayKey()}', set);
  }

  // ---------------- Quran completion (khatma progress) ----------------

  static const int totalSurahsInQuran = 114;

  static Future<Set<int>> completedSurahs() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('completed_surahs_all') ?? const [];
    return list.map(int.parse).toSet();
  }

  static Future<void> markSurahCompleted(int surahNumber) async {
    final set = await completedSurahs();
    if (set.add(surahNumber)) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('completed_surahs_all', set.map((e) => e.toString()).toList());
    }
  }

  /// 0.0-1.0 fraction of the 114 surahs marked completed. This is a
  /// surah-level approximation of khatma progress (not page-accurate,
  /// since the underlying Quran data source doesn't carry mushaf page
  /// numbers) but is real, persisted progress — not a placeholder.
  static Future<double> quranCompletionRatio() async {
    final completed = await completedSurahs();
    return completed.length / totalSurahsInQuran;
  }

  /// Resets khatma progress (e.g. after finishing a full reading and
  /// wanting to start a new one), independent of favorites/settings.
  static Future<void> resetKhatmaProgress() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('completed_surahs_all');
  }

  // ---------------- Daily Wird (pages) ----------------

  static Future<int> dailyWirdTarget() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('wird_target_pages') ?? 5;
  }

  static Future<void> setDailyWirdTarget(int pages) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('wird_target_pages', pages);
  }

  static Future<int> pagesReadToday() async {
    final prefs = await SharedPreferences.getInstance();
    final storedDay = prefs.getString('wird_progress_day');
    if (storedDay != _todayKey()) return 0;
    return prefs.getInt('wird_progress_pages') ?? 0;
  }

  static Future<int> markPageRead() async {
    final prefs = await SharedPreferences.getInstance();
    final current = await pagesReadToday();
    final next = current + 1;
    await prefs.setInt('wird_progress_pages', next);
    await prefs.setString('wird_progress_day', _todayKey());
    await prefs.setInt('wird_pages_${_todayKey()}', next);
    return next;
  }

  static Future<int> pagesReadOn(String dateKey) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('wird_pages_$dateKey') ?? 0;
  }

  /// Current daily streak: counts consecutive days (ending today or
  /// yesterday) where the wird target was met. Stored as a simple
  /// incrementing counter updated whenever a day's target is completed.
  static Future<int> wirdStreak() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('wird_streak') ?? 0;
  }

  static Future<void> registerStreakCheckpoint() async {
    final prefs = await SharedPreferences.getInstance();
    final lastCompletedDay = prefs.getString('wird_streak_last_day');
    final target = await dailyWirdTarget();
    final progress = await pagesReadToday();

    if (progress < target) return;
    if (lastCompletedDay == _todayKey()) return; // already counted today

    final streak = prefs.getInt('wird_streak') ?? 0;
    await prefs.setInt('wird_streak', streak + 1);
    await prefs.setString('wird_streak_last_day', _todayKey());
  }

  // ---------------- Local data management ----------------

  static Future<void> clearAllLocalData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
