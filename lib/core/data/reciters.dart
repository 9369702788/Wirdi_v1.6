class ReciterOption {
  final String id; // islamic.network / AlQuran.Cloud edition identifier
  final String displayName;
  const ReciterOption(this.id, this.displayName);
}

/// Verified real reciter edition identifiers from the AlQuran.Cloud /
/// islamic.network CDN (https://api.alquran.cloud/v1/edition?format=audio).
class Reciters {
  Reciters._();

  static const List<ReciterOption> all = [
    ReciterOption('ar.alafasy', 'مشاري راشد العفاسي'),
    ReciterOption('ar.husary', 'محمود خليل الحصري'),
    ReciterOption('ar.minshawi', 'محمد صديق المنشاوي'),
    ReciterOption('ar.abdulbasitmurattal', 'عبد الباسط عبد الصمد'),
    ReciterOption('ar.abdurrahmaansudais', 'عبد الرحمن السديس'),
    ReciterOption('ar.mahermuaiqly', 'ماهر المعيقلي'),
  ];

  static ReciterOption byId(String id) =>
      all.firstWhere((r) => r.id == id, orElse: () => all.first);
}
