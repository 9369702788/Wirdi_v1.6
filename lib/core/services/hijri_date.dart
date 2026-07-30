class HijriDate {
  final int day;
  final int month; // 1-12
  final int year;

  const HijriDate(this.day, this.month, this.year);

  static const List<String> monthNames = [
    'محرم',
    'صفر',
    'ربيع الأول',
    'ربيع الآخر',
    'جمادى الأولى',
    'جمادى الآخرة',
    'رجب',
    'شعبان',
    'رمضان',
    'شوال',
    'ذو القعدة',
    'ذو الحجة',
  ];

  String get monthName => monthNames[month - 1];

  @override
  String toString() => '$day $monthName $year هـ';

  /// Standard tabular/civil Hijri conversion (widely used arithmetic
  /// approximation, epoch-aligned to the Kuwaiti algorithm). This is an
  /// approximation of the *civil* calendar, not a moon-sighting-based
  /// one — real observed Hijri dates can differ by a day depending on
  /// region and lunar sighting, same caveat that applies to any
  /// arithmetic Hijri calculation without an official lookup table.
  factory HijriDate.fromGregorian(DateTime date) {
    final jd = _gregorianToJulianDay(date.year, date.month, date.day);

    var l = jd - 1948440 + 10632;
    final n = (l - 1) ~/ 10631;
    l = l - 10631 * n + 354;
    final j = ((10985 - l) ~/ 5316) * ((50 * l) ~/ 17719) + (l ~/ 5670) * ((43 * l) ~/ 15238);
    l = l - ((30 - j) ~/ 15) * ((17719 * j) ~/ 50) - (j ~/ 16) * ((15238 * j) ~/ 43) + 29;
    final month = (24 * l) ~/ 709;
    final day = l - (709 * month) ~/ 24;
    final year = 30 * n + j - 30;

    return HijriDate(day, month, year);
  }

  static int _gregorianToJulianDay(int year, int month, int day) {
    final a = (14 - month) ~/ 12;
    final y = year + 4800 - a;
    final m = month + 12 * a - 3;
    return day +
        (153 * m + 2) ~/ 5 +
        365 * y +
        y ~/ 4 -
        y ~/ 100 +
        y ~/ 400 -
        32045;
  }
}
