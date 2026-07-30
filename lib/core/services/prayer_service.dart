import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../data/app_sources.dart';
import '../models/prayer_models.dart';
import 'app_logger.dart';

const List<String> _kOrderedNames = ['الفجر', 'الظهر', 'العصر', 'المغرب', 'العشاء'];
const List<String> _kOrderedApiKeys = ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];

/// Single source of truth for prayer times: real GPS + AlAdhan API, with
/// an offline fallback to the last successful response (clearly marked
/// as cached, never presented as live), an optional manually-entered
/// city, and a resolved human-readable location label. Used by both the
/// Prayer Times screen and the Home Dashboard so "next prayer" always
/// agrees.
class PrayerService {
  PrayerService._();

  static const _cacheTimingsKey = 'cache_prayer_timings_v2';
  static const _cacheDateKey = 'cache_prayer_timings_date_v2';
  static const _cacheLocationLabelKey = 'cache_prayer_location_label_v2';
  static const _cacheModeKey = 'cache_prayer_mode_v2'; // 'gps' | 'manual'
  static const _cacheManualCityKey = 'cache_prayer_manual_city_v2';

  /// Whether the user last used GPS or a manually-entered city, so the
  /// app can restore the right mode on next launch without re-asking.
  static Future<String> savedMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_cacheModeKey) ?? 'gps';
  }

  static Future<String?> savedManualCity() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_cacheManualCityKey);
  }

  /// Throws a [PrayerAvailability] (not an Exception) on failure so the
  /// UI can render an exact, real reason rather than a generic message.
  static Future<PrayerTimesResult> fetchPrayerTimes() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      final cached = await _tryLoadCache();
      if (cached != null) return cached;
      throw PrayerAvailability.locationServiceDisabled;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      final cached = await _tryLoadCache();
      if (cached != null) return cached;
      throw PrayerAvailability.permissionDeniedForever;
    }
    if (permission != LocationPermission.always &&
        permission != LocationPermission.whileInUse) {
      final cached = await _tryLoadCache();
      if (cached != null) return cached;
      throw PrayerAvailability.permissionDenied;
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      ).timeout(const Duration(seconds: 15));

      final url = AppSources.prayerTimesUrl(
        latitude: position.latitude,
        longitude: position.longitude,
      );

      final response =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }

      final decoded = jsonDecode(response.body);
      final timings = decoded['data']['timings'] as Map<String, dynamic>;

      final locationLabel = await _reverseGeocode(position.latitude, position.longitude);

      await _saveCache(
        timings: timings,
        locationLabel: locationLabel,
        mode: 'gps',
        manualCity: null,
      );

      return _buildResult(timings, isFromCache: false, cachedAt: DateTime.now(), locationLabel: locationLabel);
    } catch (e, st) {
      AppLogger.error('Prayer times fetch failed, falling back to cache', error: e, stackTrace: st);
      final cached = await _tryLoadCache();
      if (cached != null) return cached;
      throw PrayerAvailability.networkErrorNoCache;
    }
  }

  /// Fetches prayer times for a manually-entered city/address using
  /// AlAdhan's geocoding-enabled `timingsByAddress` endpoint — no GPS
  /// involved. Throws a plain [Exception] with a message on failure
  /// (city not found / network error) since this is a user-initiated
  /// action with its own error path in the UI, not the app-startup flow.
  static Future<PrayerTimesResult> fetchPrayerTimesForCity(String city) async {
    final trimmed = city.trim();
    if (trimmed.isEmpty) {
      throw Exception('يرجى إدخال اسم مدينة');
    }

    try {
      final url = AppSources.prayerTimesByAddressUrl(trimmed);
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        throw Exception('لم يتم العثور على هذه المدينة');
      }

      final decoded = jsonDecode(response.body);
      final timings = decoded['data']['timings'] as Map<String, dynamic>;

      await _saveCache(timings: timings, locationLabel: trimmed, mode: 'manual', manualCity: trimmed);

      return _buildResult(timings, isFromCache: false, cachedAt: DateTime.now(), locationLabel: trimmed);
    } catch (e, st) {
      AppLogger.error('Manual city prayer times fetch failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Restores the last-used mode (GPS or manual city) on app start,
  /// falling back to cache if a fresh fetch isn't possible right now.
  static Future<PrayerTimesResult> fetchUsingSavedPreference() async {
    final mode = await savedMode();
    if (mode == 'manual') {
      final city = await savedManualCity();
      if (city != null && city.isNotEmpty) {
        try {
          return await fetchPrayerTimesForCity(city);
        } catch (_) {
          final cached = await _tryLoadCache();
          if (cached != null) return cached;
          rethrow;
        }
      }
    }
    return fetchPrayerTimes();
  }

  static Future<String?> _reverseGeocode(double lat, double lon) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=$lat&lon=$lon&accept-language=ar&zoom=10',
      );
      final response = await http.get(
        url,
        headers: {'User-Agent': 'WirdiApp/1.0 (Islamic daily companion app)'},
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) return null;

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final address = decoded['address'] as Map<String, dynamic>?;
      if (address == null) return null;

      final city = address['city'] ?? address['town'] ?? address['village'] ?? address['county'];
      final country = address['country'];

      if (city != null && country != null) return '$city، $country';
      if (city != null) return city.toString();
      return decoded['display_name']?.toString();
    } catch (e, st) {
      // Reverse geocoding is a nice-to-have label, not critical — log
      // and continue without it rather than failing the whole fetch.
      AppLogger.error('Reverse geocoding failed', error: e, stackTrace: st);
      return null;
    }
  }

  static Future<void> _saveCache({
    required Map<String, dynamic> timings,
    required String? locationLabel,
    required String mode,
    required String? manualCity,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cacheTimingsKey, jsonEncode(timings));
    await prefs.setString(_cacheDateKey, DateTime.now().toIso8601String());
    await prefs.setString(_cacheModeKey, mode);
    if (locationLabel != null) {
      await prefs.setString(_cacheLocationLabelKey, locationLabel);
    }
    if (manualCity != null) {
      await prefs.setString(_cacheManualCityKey, manualCity);
    } else if (mode == 'gps') {
      await prefs.remove(_cacheManualCityKey);
    }
  }

  static Future<PrayerTimesResult?> _tryLoadCache() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheTimingsKey);
    final dateRaw = prefs.getString(_cacheDateKey);
    if (raw == null) return null;

    final timings = jsonDecode(raw) as Map<String, dynamic>;
    final cachedAt = dateRaw != null ? DateTime.tryParse(dateRaw) : null;
    final locationLabel = prefs.getString(_cacheLocationLabelKey);

    // Clock times (HH:mm) are re-applied to *today's* date. This is a
    // reasonable offline approximation (times shift by only ~1-2 min/day)
    // and is always labeled isFromCache=true in the UI, never presented
    // as a live reading.
    return _buildResult(timings, isFromCache: true, cachedAt: cachedAt, locationLabel: locationLabel);
  }

  static PrayerTimesResult _buildResult(
    Map<String, dynamic> timings, {
    required bool isFromCache,
    DateTime? cachedAt,
    String? locationLabel,
  }) {
    final now = DateTime.now();

    final prayers = <PrayerItem>[];
    for (var i = 0; i < _kOrderedNames.length; i++) {
      final timeText = _cleanTime(timings[_kOrderedApiKeys[i]]);
      prayers.add(PrayerItem(
        name: _kOrderedNames[i],
        timeText: timeText,
        dateTime: _timeToday(timeText, now),
      ));
    }

    final next = _nextPrayer(prayers, now);

    return PrayerTimesResult(
      prayers: prayers,
      next: next,
      isFromCache: isFromCache,
      cachedAt: cachedAt,
      locationLabel: locationLabel,
    );
  }

  static PrayerItem _nextPrayer(List<PrayerItem> prayers, DateTime now) {
    for (final prayer in prayers) {
      if (prayer.dateTime.isAfter(now)) return prayer;
    }
    final fajrTomorrow = prayers.first.dateTime.add(const Duration(days: 1));
    return PrayerItem(
      name: prayers.first.name,
      timeText: prayers.first.timeText,
      dateTime: fajrTomorrow,
    );
  }

  static String _cleanTime(dynamic value) {
    final text = value.toString();
    if (text.contains(' ')) return text.split(' ').first;
    return text;
  }

  static DateTime _timeToday(String value, DateTime now) {
    final parts = value.split(':');
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    return DateTime(now.year, now.month, now.day, hour, minute);
  }
}
