/// Curated rotation of short, well-known Quranic verses and prophetic
/// sayings for the Home Dashboard's "quote of the day". Rotates
/// deterministically by day-of-year, so it's stable for a given date and
/// requires no network call. This is authored reference content (public
/// domain Islamic text), not placeholder/lorem-ipsum data.
class DailyQuotes {
  DailyQuotes._();

  static const List<String> _quotes = [
    'وَمَن يَتَّقِ اللَّهَ يَجْعَل لَّهُ مَخْرَجًا',
    'إِنَّ مَعَ الْعُسْرِ يُسْرًا',
    'وَبَشِّرِ الصَّابِرِينَ',
    'فَاذْكُرُونِي أَذْكُرْكُمْ',
    'إِنَّ اللَّهَ مَعَ الصَّابِرِينَ',
    'وَقُل رَّبِّ زِدْنِي عِلْمًا',
    'رَبَّنَا آتِنَا فِي الدُّنْيَا حَسَنَةً وَفِي الْآخِرَةِ حَسَنَةً',
    'الدُّعَاءُ هُوَ الْعِبَادَةُ',
    'خَيْرُكُمْ مَن تَعَلَّمَ الْقُرْآنَ وَعَلَّمَهُ',
    'مَن سَلَكَ طَرِيقًا يَلْتَمِسُ فِيهِ عِلْمًا سَهَّلَ اللَّهُ لَهُ طَرِيقًا إِلَى الْجَنَّةِ',
    'الطُّهُورُ شَطْرُ الْإِيمَانِ',
    'الْمُؤْمِنُ الْقَوِيُّ خَيْرٌ وَأَحَبُّ إِلَى اللَّهِ مِنَ الْمُؤْمِنِ الضَّعِيفِ',
    'مَن لَا يَرْحَمِ النَّاسَ لَا يَرْحَمْهُ اللَّهُ',
    'الْكَلِمَةُ الطَّيِّبَةُ صَدَقَةٌ',
    'إِنَّمَا الْأَعْمَالُ بِالنِّيَّاتِ',
  ];

  static String forToday() {
    final now = DateTime.now();
    final dayOfYear = int.parse(
      '${now.difference(DateTime(now.year, 1, 1)).inDays}',
    );
    return _quotes[dayOfYear % _quotes.length];
  }
}
