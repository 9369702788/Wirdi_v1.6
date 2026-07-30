import 'adhan_option.dart';

class AppSources {
  AppSources._();

  static const String quranJsonUrl =
      'https://cdn.jsdelivr.net/npm/quran-json@3.1.2/dist/quran.json';

  static const String azkarJsonUrl =
      'https://raw.githubusercontent.com/YousefAsalya/Islamic-Pro-azkar-API/main/data/ar.json';

  /// Tafsir Al-Muyassar (Arabic), one concise commentary entry per ayah,
  /// 6236 entries. Verified real dataset — checked structure and HTTP
  /// 200 before wiring in.
  static const String tafsirJsonUrl =
      'https://raw.githubusercontent.com/00AhmedMokhtar00/QuranTafseer-ar-json/master/tafseer.json';

  /// Real 604-page Madani Mushaf ayah-to-page mapping. Verified
  /// structure and HTTP 200 before wiring in.
  static const String mushafPagesJsonUrl =
      'https://raw.githubusercontent.com/hamzakat/madani-muhsaf-json/main/madani-muhsaf.json';

  /// Adhan audio recordings, officially hosted by AlAdhan (the same
  /// provider already used for prayer times), listed at
  /// https://aladhan.com/download-adhans
  static const List<AdhanOption> adhanOptions = [
    AdhanOption('a9', 'مشاري راشد العفاسي', 'https://cdn.aladhan.com/audio/adhans/a9.mp3'),
    AdhanOption('a4', 'أذان دبي (مشاري العفاسي)', 'https://cdn.aladhan.com/audio/adhans/a4.mp3'),
    AdhanOption('a7', 'مشاري راشد العفاسي (نسخة أخرى)', 'https://cdn.aladhan.com/audio/adhans/a7.mp3'),
    AdhanOption('a1', 'أحمد النفيس', 'https://cdn.aladhan.com/audio/adhans/a1.mp3'),
    AdhanOption('a11', 'منصور الزهراني', 'https://cdn.aladhan.com/audio/adhans/a11-mansour-al-zahrani.mp3'),
    AdhanOption('a2', 'حافظ مصطفى أوزجان (تركيا)', 'https://cdn.aladhan.com/audio/adhans/a2.mp3'),
  ];

  static String prayerTimesUrl({
    required double latitude,
    required double longitude,
  }) {
    return 'https://api.aladhan.com/v1/timings?latitude=$latitude&longitude=$longitude&method=5';
  }

  /// Documented AlAdhan endpoint that geocodes the address server-side,
  /// so no separate geocoding call is needed for manual city entry.
  static String prayerTimesByAddressUrl(String address) {
    final encoded = Uri.encodeComponent(address);
    return 'https://api.aladhan.com/v1/timingsByAddress?address=$encoded&method=5';
  }

  // Recitation. Verified reciter identifiers from the islamic.network CDN
  // docs (https://alquran.cloud/cdn). Default kept as Alafasy for
  // backward compatibility with existing cached audio behavior.
  static const String _audioBitrate = '128';

  static String surahAudioUrl(int surahNumber, {String reciter = 'ar.alafasy', String bitrate = '128'}) =>
      'https://cdn.islamic.network/quran/audio-surah/$bitrate/$reciter/$surahNumber.mp3';

  /// [globalAyahNumber] is the ayah's position across the whole Quran
  /// (1-6236), not its position within its surah.
  static String ayahAudioUrl(int globalAyahNumber, {String reciter = 'ar.alafasy'}) =>
      'https://cdn.islamic.network/quran/audio/$_audioBitrate/$reciter/$globalAyahNumber.mp3';

  static const String sourcesAndLicenses = '''
المصادر والتراخيص

نص القرآن الكريم:
Quran JSON
https://github.com/risan/quran-json

مصدر نص القرآن:
Tanzil Project
https://tanzil.net

الأذكار:
Hisn Al-Muslim / Islamic Pro Azkar API
https://github.com/YousefAsalya/Islamic-Pro-azkar-API

مواقيت الصلاة:
AlAdhan Prayer Times API
https://aladhan.com/prayer-times-api

تلاوة القرآن الكريم:
عدة قراء (راجع قائمة القراء داخل شاشة القراءة)
عبر شبكة Islamic Network CDN
https://alquran.cloud/cdn

التفسير الميسر:
مصدر بيانات JSON مفتوح على GitHub
https://github.com/00AhmedMokhtar00/QuranTafseer-ar-json

ترقيم صفحات المصحف (604 صفحة):
مصدر بيانات JSON مفتوح على GitHub
https://github.com/hamzakat/madani-muhsaf-json

أصوات الأذان:
AlAdhan (Islamic Network)
https://aladhan.com/download-adhans

ملاحظات مهمة:
- يجب عدم تعديل نص القرآن الكريم.
- يجب ذكر مصدر Tanzil داخل صفحة المصادر والتراخيص.
- مواقيت الصلاة قد تختلف عن توقيت المسجد المحلي إذا كانت هناك تعديلات محلية.
''';
}
