import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/data/app_sources.dart';
import '../../core/models/prayer_models.dart';
import '../../core/services/app_logger.dart';
import '../../core/services/prayer_service.dart';
import '../../core/services/settings_service.dart';
import '../../core/services/user_progress_service.dart';
import '../../core/theme/app_theme.dart';

class PrayerTimesScreen extends StatefulWidget {
  const PrayerTimesScreen({super.key});

  @override
  State<PrayerTimesScreen> createState() => _PrayerTimesScreenState();
}

class _PrayerTimesScreenState extends State<PrayerTimesScreen> {
  bool _loading = true;
  PrayerAvailability? _availabilityError;
  PrayerTimesResult? _result;
  String _countdown = '--:--:--';
  Timer? _timer;
  Set<String> _prayedToday = {};
  String? _remindedForPrayer; // avoids re-firing the reminder every second
  final AudioPlayer _adhanPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _load();
    _loadPrayedToday();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _adhanPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadPrayedToday() async {
    final prayed = await UserProgressService.prayedToday();
    if (mounted) setState(() => _prayedToday = prayed);
  }

  Future<void> _togglePrayed(String prayerName) async {
    final isPrayed = _prayedToday.contains(prayerName);
    await UserProgressService.setPrayed(prayerName, !isPrayed);
    await _loadPrayedToday();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _availabilityError = null;
    });

    try {
      final result = await PrayerService.fetchUsingSavedPreference();
      setState(() {
        _result = result;
        _loading = false;
      });
      _startCountdown();
    } on PrayerAvailability catch (e) {
      setState(() {
        _availabilityError = e;
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _availabilityError = PrayerAvailability.networkErrorNoCache;
        _loading = false;
      });
    }
  }

  Future<void> _useGpsLocation() async {
    setState(() => _loading = true);
    try {
      final result = await PrayerService.fetchPrayerTimes();
      setState(() {
        _result = result;
        _availabilityError = null;
        _loading = false;
      });
      _startCountdown();
    } on PrayerAvailability catch (e) {
      setState(() {
        _availabilityError = e;
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _availabilityError = PrayerAvailability.networkErrorNoCache;
        _loading = false;
      });
    }
  }

  Future<void> _pickCityManually() async {
    final controller = TextEditingController(text: _result?.locationLabel ?? '');

    final city = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تحديد المدينة يدويًا'),
        content: TextField(
          controller: controller,
          textDirection: TextDirection.rtl,
          textAlign: TextAlign.right,
          decoration: const InputDecoration(hintText: 'مثال: القاهرة، مصر'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('بحث')),
        ],
      ),
    );

    if (city == null || city.isEmpty) return;

    setState(() => _loading = true);
    try {
      final result = await PrayerService.fetchPrayerTimesForCity(city);
      setState(() {
        _result = result;
        _availabilityError = null;
        _loading = false;
      });
      _startCountdown();
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر العثور على "$city" — تحقق من الاسم وحاول مرة أخرى')),
        );
      }
    }
  }

  void _startCountdown() {
    _timer?.cancel();
    _remindedForPrayer = null;
    _updateCountdown();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateCountdown());
  }

  void _updateCountdown() {
    final result = _result;
    if (result == null) return;

    final diff = result.next.dateTime.difference(DateTime.now());
    if (diff.isNegative) {
      _load();
      return;
    }

    final hours = diff.inHours.toString().padLeft(2, '0');
    final minutes = (diff.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (diff.inSeconds % 60).toString().padLeft(2, '0');

    if (mounted) setState(() => _countdown = '$hours:$minutes:$seconds');

    _maybeFireReminder(diff, result.next.name);
  }

  void _maybeFireReminder(Duration remaining, String prayerName) {
    if (!appSettings.prayerReminderEnabled) return;
    if (appSettings.prayerReminderMode == 'off') return;
    if (_remindedForPrayer == prayerName) return;

    final thresholdSeconds = appSettings.prayerReminderMinutesBefore * 60;
    if (remaining.inSeconds <= thresholdSeconds) {
      _remindedForPrayer = prayerName;
      _fireReminder(prayerName);
    }
  }

  void _fireReminder(String prayerName) {
    final mode = appSettings.prayerReminderMode;

    if (mode == 'beep') {
      SystemSound.play(SystemSoundType.alert);
      HapticFeedback.heavyImpact();
    } else if (mode == 'adhan') {
      _playAdhan();
    }

    if (mode != 'off') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('اقترب وقت صلاة $prayerName بعد ${appSettings.prayerReminderMinutesBefore} دقائق'),
            duration: const Duration(seconds: 6),
            backgroundColor: AppColors.primaryEmerald,
          ),
        );
      }
    }
  }

  Future<void> _playAdhan() async {
    final option = AppSources.adhanOptions.firstWhere(
      (a) => a.id == appSettings.adhanId,
      orElse: () => AppSources.adhanOptions.first,
    );
    try {
      try {
        await _adhanPlayer.stop();
      } catch (_) {
        // Nothing loaded yet — expected on first play.
      }
      await _adhanPlayer.play(UrlSource(option.url));
    } catch (e, st) {
      AppLogger.error('Adhan playback failed', error: e, stackTrace: st);
    }
  }

  String _availabilityMessage(PrayerAvailability e) => switch (e) {
        PrayerAvailability.locationServiceDisabled =>
          'خدمة الموقع غير مفعّلة على جهازك. فعّلها أو حدد مدينتك يدويًا.',
        PrayerAvailability.permissionDenied =>
          'التطبيق يحتاج إذن الوصول إلى الموقع لعرض مواقيت صلاة دقيقة، أو يمكنك تحديد مدينتك يدويًا.',
        PrayerAvailability.permissionDeniedForever =>
          'تم رفض إذن الموقع بشكل دائم. فعّله من إعدادات النظام، أو حدد مدينتك يدويًا.',
        PrayerAvailability.networkErrorNoCache =>
          'تعذر الاتصال بالإنترنت ولا توجد مواقيت محفوظة مسبقًا.',
        PrayerAvailability.ok => '',
      };

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_availabilityError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('مواقيت الصلاة'), centerTitle: true),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.location_off_outlined, size: 52, color: AppColors.mutedText),
                const SizedBox(height: 16),
                Text(_availabilityMessage(_availabilityError!),
                    textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, color: AppColors.mutedText)),
                const SizedBox(height: 20),
                ElevatedButton(onPressed: _load, child: const Text('إعادة المحاولة')),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _pickCityManually,
                  icon: const Icon(Icons.location_city),
                  label: const Text('تحديد المدينة يدويًا'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final result = _result!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('مواقيت الصلاة'),
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'gps') _useGpsLocation();
              if (value == 'city') _pickCityManually();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'gps', child: Text('استخدام الموقع الحالي (GPS)')),
              PopupMenuItem(value: 'city', child: Text('تحديد المدينة يدويًا')),
            ],
            icon: const Icon(Icons.tune),
          ),
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh), tooltip: 'تحديث'),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (result.isFromCache)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.goldAccent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.wifi_off_rounded, size: 18, color: AppColors.goldAccent),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('لا يوجد اتصال — تُعرض آخر مواقيت محفوظة', style: TextStyle(fontSize: 13)),
                  ),
                ],
              ),
            ),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primaryEmerald, Color(0xFF115E56)],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                if (result.locationLabel != null) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.location_on, size: 16, color: Colors.white70),
                      const SizedBox(width: 4),
                      Text(result.locationLabel!, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
                const Text('الصلاة القادمة', style: TextStyle(color: Colors.white70, fontSize: 16)),
                const SizedBox(height: 10),
                Text(result.next.name, style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Text(_countdown, style: const TextStyle(color: AppColors.goldAccent, fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
                const SizedBox(height: 6),
                const Text('الوقت المتبقي', style: TextStyle(color: Colors.white70)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ...result.prayers.map((prayer) {
            final isNext = prayer.name == result.next.name;
            final isPrayed = _prayedToday.contains(prayer.name);
            final hasPassed = prayer.dateTime.isBefore(DateTime.now());
            return Card(
              color: isNext ? AppColors.primaryEmerald.withValues(alpha: 0.08) : null,
              child: ListTile(
                leading: Icon(Icons.mosque_outlined, color: isNext ? AppColors.primaryEmerald : AppColors.mutedText),
                title: Text(prayer.name, style: TextStyle(fontWeight: isNext ? FontWeight.bold : FontWeight.w600)),
                subtitle: Text(prayer.timeText, style: TextStyle(fontWeight: FontWeight.bold, color: isNext ? AppColors.primaryEmerald : null)),
                trailing: Semantics(
                  button: hasPassed,
                  label: !hasPassed
                      ? 'لم يحن وقت صلاة ${prayer.name} بعد'
                      : (isPrayed ? 'تم أداء صلاة ${prayer.name}' : 'صلاة ${prayer.name} لم تؤدَ بعد'),
                  child: Checkbox(
                    value: isPrayed,
                    activeColor: AppColors.primaryEmerald,
                    onChanged: hasPassed ? (_) => _togglePrayed(prayer.name) : null,
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 12),
          const Text(
            'ملاحظة: المواقيت تعتمد على موقعك أو المدينة المحددة، وخدمة AlAdhan بطريقة الحساب المصرية.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.mutedText),
          ),
        ],
      ),
    );
  }
}
