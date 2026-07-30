import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../core/data/app_sources.dart';
import '../../core/data/adhan_option.dart';
import '../../core/services/azkar_repository.dart';
import '../../core/services/quran_repository.dart';
import '../../core/services/settings_service.dart';
import '../../core/services/user_progress_service.dart';
import '../../core/theme/app_theme.dart';
import 'about_screen.dart';
import 'privacy_policy_screen.dart';
import 'sources_licenses_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _wirdTarget = 5;
  final AudioPlayer _previewPlayer = AudioPlayer();
  String? _previewingAdhanId;
  DateTime? _quranCachedAt;
  DateTime? _azkarCachedAt;

  @override
  void initState() {
    super.initState();
    _loadWirdTarget();
    _loadCacheInfo();
    _previewPlayer.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _previewingAdhanId = null);
    });
  }

  @override
  void dispose() {
    _previewPlayer.dispose();
    super.dispose();
  }

  Future<void> _togglePreviewAdhan(AdhanOption option) async {
    if (_previewingAdhanId == option.id) {
      try {
        await _previewPlayer.stop();
      } catch (_) {
        // Nothing loaded — fine.
      }
      setState(() => _previewingAdhanId = null);
      return;
    }

    setState(() => _previewingAdhanId = option.id);
    try {
      try {
        await _previewPlayer.stop();
      } catch (_) {
        // Nothing loaded yet — expected on first preview, safe to ignore.
      }
      await _previewPlayer.play(UrlSource(option.url));
    } catch (e) {
      if (mounted) {
        setState(() => _previewingAdhanId = null);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر تشغيل المعاينة — تحقق من الاتصال')),
        );
      }
    }
  }

  Future<void> _loadCacheInfo() async {
    final quranAt = await QuranRepository.cachedAt();
    final azkarAt = await AzkarRepository.cachedAt();
    if (mounted) {
      setState(() {
        _quranCachedAt = quranAt;
        _azkarCachedAt = azkarAt;
      });
    }
  }

  String _formatCacheDate(DateTime? date) {
    if (date == null) return 'لم يتم التحميل بعد';
    return DateFormat('d MMMM y، h:mm a', 'ar').format(date);
  }

  Future<void> _loadWirdTarget() async {
    final target = await UserProgressService.dailyWirdTarget();
    if (mounted) setState(() => _wirdTarget = target);
  }

  Future<void> _setWirdTarget(int value) async {
    if (value < 1) return;
    await UserProgressService.setDailyWirdTarget(value);
    setState(() => _wirdTarget = value);
  }

  Future<void> _confirmClearData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف البيانات المحلية'),
        content: const Text(
          'سيتم حذف المفضلة وإحصاءات التسبيح وتقدم الورد اليومي وكل الإعدادات المحفوظة على هذا الجهاز. لا يمكن التراجع عن هذا الإجراء.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await UserProgressService.clearAllLocalData();
      await appSettings.load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حذف جميع البيانات المحلية')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات'), centerTitle: true),
      body: ListenableBuilder(
        listenable: appSettings,
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _SectionLabel('المظهر'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('الوضع', style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 10),
                      SegmentedButton<ThemeMode>(
                        segments: const [
                          ButtonSegment(value: ThemeMode.light, label: Text('فاتح'), icon: Icon(Icons.light_mode_outlined)),
                          ButtonSegment(value: ThemeMode.dark, label: Text('داكن'), icon: Icon(Icons.dark_mode_outlined)),
                          ButtonSegment(value: ThemeMode.system, label: Text('تلقائي'), icon: Icon(Icons.brightness_auto_outlined)),
                        ],
                        selected: {appSettings.themeMode},
                        onSelectionChanged: (set) => appSettings.setThemeMode(set.first),
                      ),
                      const SizedBox(height: 20),
                      const Text('حجم الخط', style: TextStyle(fontWeight: FontWeight.w700)),
                      Slider(
                        value: appSettings.fontScale,
                        min: 0.85,
                        max: 1.4,
                        divisions: 11,
                        label: '${(appSettings.fontScale * 100).round()}%',
                        onChanged: (value) => appSettings.setFontScale(value),
                      ),
                      Text(
                        'نص تجريبي لمعاينة حجم الخط',
                        textDirection: TextDirection.rtl,
                        style: TextStyle(fontSize: 16 * appSettings.fontScale),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              _SectionLabel('تذكير الصلاة'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('تفعيل تذكير اقتراب الصلاة'),
                        subtitle: const Text('يعمل التذكير أثناء فتح التطبيق فقط'),
                        value: appSettings.prayerReminderEnabled,
                        activeTrackColor: AppColors.primaryEmerald,
                        onChanged: (value) => appSettings.setPrayerReminderEnabled(value),
                      ),
                      if (appSettings.prayerReminderEnabled) ...[
                        const SizedBox(height: 8),
                        const Text('التذكير قبل الصلاة بـ (دقائق)', style: TextStyle(fontWeight: FontWeight.w700)),
                        Slider(
                          value: appSettings.prayerReminderMinutesBefore.toDouble(),
                          min: 5,
                          max: 30,
                          divisions: 5,
                          label: '${appSettings.prayerReminderMinutesBefore} دقيقة',
                          onChanged: (value) => appSettings.setPrayerReminderMinutesBefore(value.round()),
                        ),
                        const SizedBox(height: 8),
                        const Text('طريقة التذكير', style: TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(value: 'banner', label: Text('إشعار فقط'), icon: Icon(Icons.notifications_outlined)),
                            ButtonSegment(value: 'beep', label: Text('نغمة تنبيه'), icon: Icon(Icons.volume_up_outlined)),
                            ButtonSegment(value: 'adhan', label: Text('أذان كامل'), icon: Icon(Icons.campaign_outlined)),
                          ],
                          selected: {appSettings.prayerReminderMode},
                          onSelectionChanged: (set) => appSettings.setPrayerReminderMode(set.first),
                        ),
                        if (appSettings.prayerReminderMode == 'beep') ...[
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: () => SystemSound.play(SystemSoundType.alert),
                            icon: const Icon(Icons.volume_up_outlined),
                            label: const Text('تجربة النغمة'),
                          ),
                        ],
                        if (appSettings.prayerReminderMode == 'adhan') ...[
                          const SizedBox(height: 12),
                          const Text('صوت الأذان', style: TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 6),
                          Column(
                            children: AppSources.adhanOptions.map((option) {
                              final isSelected = appSettings.adhanId == option.id;
                              final isPreviewing = _previewingAdhanId == option.id;
                              return RadioListTile<String>(
                                contentPadding: EdgeInsets.zero,
                                value: option.id,
                                groupValue: appSettings.adhanId,
                                activeColor: AppColors.primaryEmerald,
                                title: Text(option.displayName),
                                onChanged: (value) {
                                  if (value != null) appSettings.setAdhanId(value);
                                },
                                secondary: IconButton(
                                  tooltip: isPreviewing ? 'إيقاف المعاينة' : 'استماع',
                                  icon: Icon(
                                    isPreviewing ? Icons.stop_circle_outlined : Icons.play_circle_outline,
                                    color: isSelected ? AppColors.primaryEmerald : AppColors.mutedText,
                                  ),
                                  onPressed: () => _togglePreviewAdhan(option),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                        const SizedBox(height: 8),
                        const Text(
                          'ملاحظة: هذا التذكير يعمل فقط أثناء فتح شاشة مواقيت الصلاة أو التطبيق. '
                          'إشعارات حقيقية تعمل والتطبيق مغلق تحتاج خدمة إشعارات نظام منفصلة، '
                          'وهي ميزة مخطط لها لإصدار قادم.',
                          style: TextStyle(fontSize: 12, color: AppColors.mutedText),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              _SectionLabel('الورد اليومي'),
              Card(
                child: ListTile(
                  title: const Text('الهدف اليومي (صفحات/سور)'),
                  subtitle: Text('$_wirdTarget في اليوم'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(onPressed: () => _setWirdTarget(_wirdTarget - 1), icon: const Icon(Icons.remove_circle_outline)),
                      IconButton(onPressed: () => _setWirdTarget(_wirdTarget + 1), icon: const Icon(Icons.add_circle_outline)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              _SectionLabel('حول ودعم'),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.info_outline),
                      title: const Text('عن التطبيق'),
                      trailing: const Icon(Icons.chevron_left),
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutScreen())),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.source_outlined),
                      title: const Text('المصادر والتراخيص'),
                      trailing: const Icon(Icons.chevron_left),
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SourcesLicensesScreen())),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.privacy_tip_outlined),
                      title: const Text('سياسة الخصوصية'),
                      trailing: const Icon(Icons.chevron_left),
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen())),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              _SectionLabel('إدارة البيانات'),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.menu_book_outlined, color: AppColors.mutedText),
                      title: const Text('آخر تحديث للقرآن الكريم'),
                      subtitle: Text(_formatCacheDate(_quranCachedAt)),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.favorite_outline, color: AppColors.mutedText),
                      title: const Text('آخر تحديث للأذكار'),
                      subtitle: Text(_formatCacheDate(_azkarCachedAt)),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.refresh, color: AppColors.primaryEmerald),
                      title: const Text('تحديث البيانات الآن'),
                      subtitle: const Text('يتطلب اتصالاً بالإنترنت'),
                      onTap: () async {
                        await QuranRepository.load(forceRefresh: true);
                        await AzkarRepository.load(forceRefresh: true);
                        await _loadCacheInfo();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('تم تحديث بيانات القرآن والأذكار')),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.restart_alt, color: Colors.orange),
                      title: const Text('إعادة تعيين تقدّم الختمة'),
                      subtitle: const Text('لبدء ختمة جديدة من الصفر'),
                      onTap: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('إعادة تعيين تقدّم الختمة'),
                            content: const Text('سيتم اعتبار كل السور غير مقروءة من جديد لبدء ختمة جديدة. لن يتأثر وردك اليومي أو المفضلة.'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
                              TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('إعادة التعيين')),
                            ],
                          ),
                        );
                        if (confirmed == true) {
                          await UserProgressService.resetKhatmaProgress();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('تم بدء ختمة جديدة، بالتوفيق 🌿')),
                            );
                          }
                        }
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.delete_outline, color: Colors.red),
                      title: const Text('حذف جميع البيانات المحلية', style: TextStyle(color: Colors.red)),
                      onTap: _confirmClearData,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.mutedText, fontSize: 13),
      ),
    );
  }
}
