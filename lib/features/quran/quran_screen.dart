import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/data/app_sources.dart';
import '../../core/data/juz_data.dart';
import '../../core/data/reciters.dart';
import '../../core/models/quran_models.dart';
import '../../core/services/app_logger.dart';
import '../../core/services/arabic_text_utils.dart';
import '../../core/services/quran_repository.dart';
import '../../core/services/settings_service.dart';
import '../../core/services/tafsir_repository.dart';
import '../../core/services/user_progress_service.dart';
import '../../core/theme/app_theme.dart';
import '../mushaf/mushaf_view_screen.dart';

class QuranScreen extends StatefulWidget {
  /// If set, the screen opens directly into the reader for this surah,
  /// scrolled to [initialAyah] — used by "continue reading".
  final int? initialSurahNumber;
  final int? initialAyah;

  const QuranScreen({super.key, this.initialSurahNumber, this.initialAyah});

  @override
  State<QuranScreen> createState() => _QuranScreenState();
}

class _QuranScreenState extends State<QuranScreen> with SingleTickerProviderStateMixin {
  late Future<List<SurahModel>> _future;
  late TabController _tabController;
  final TextEditingController _surahSearchController = TextEditingController();
  final TextEditingController _ayahSearchController = TextEditingController();
  bool _openedDeepLink = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _future = QuranRepository.load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _surahSearchController.dispose();
    _ayahSearchController.dispose();
    super.dispose();
  }

  void _maybeOpenDeepLink(List<SurahModel> surahs) {
    if (_openedDeepLink || widget.initialSurahNumber == null) return;
    _openedDeepLink = true;

    final surah = surahs.firstWhere(
      (s) => s.number == widget.initialSurahNumber,
      orElse: () => surahs.first,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SurahReaderScreen(
            surah: surah,
            allSurahs: surahs,
            scrollToAyah: widget.initialAyah,
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('القرآن الكريم'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'عرض المصحف',
            icon: const Icon(Icons.import_contacts_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MushafViewScreen()),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'السور'),
            Tab(text: 'الأجزاء'),
            Tab(text: 'البحث'),
            Tab(text: 'المفضلة'),
          ],
        ),
      ),
      body: FutureBuilder<List<SurahModel>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError || snapshot.data == null) {
            return _ErrorView(
              message: 'تعذر تحميل القرآن الكريم. تأكد من اتصال الإنترنت.',
              onRetry: () => setState(() => _future = QuranRepository.load(forceRefresh: true)),
            );
          }

          final allSurahs = snapshot.data!;
          _maybeOpenDeepLink(allSurahs);

          return TabBarView(
            controller: _tabController,
            children: [
              _SurahListTab(allSurahs: allSurahs, controller: _surahSearchController),
              _JuzListTab(allSurahs: allSurahs),
              _AyahSearchTab(allSurahs: allSurahs, controller: _ayahSearchController),
              _FavoritesTab(allSurahs: allSurahs),
            ],
          );
        },
      ),
    );
  }
}

class _SurahListTab extends StatefulWidget {
  final List<SurahModel> allSurahs;
  final TextEditingController controller;
  const _SurahListTab({required this.allSurahs, required this.controller});

  @override
  State<_SurahListTab> createState() => _SurahListTabState();
}

class _SurahListTabState extends State<_SurahListTab> {
  @override
  Widget build(BuildContext context) {
    final query = widget.controller.text.trim();
    final filtered = widget.allSurahs.where((surah) {
      if (query.isEmpty) return true;
      return ArabicTextUtils.contains(surah.name, query) ||
          surah.number.toString() == query ||
          surah.englishName.toLowerCase().contains(query.toLowerCase());
    }).toList();

    return Column(
      children: [
        FutureBuilder<double>(
          future: UserProgressService.quranCompletionRatio(),
          builder: (context, snapshot) {
            final ratio = snapshot.data ?? 0.0;
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Semantics(
                label: 'نسبة إتمام القرآن الكريم ${(ratio * 100).round()} بالمئة',
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(16)),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('تقدّم الختمة', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: ratio,
                                minHeight: 6,
                                backgroundColor: AppColors.primaryEmerald.withValues(alpha: 0.1),
                                valueColor: const AlwaysStoppedAnimation(AppColors.primaryEmerald),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text('${(ratio * 100).round()}%', style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primaryEmerald)),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: widget.controller,
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.right,
            decoration: InputDecoration(
              hintText: 'ابحث باسم السورة أو رقمها',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Theme.of(context).cardColor,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            itemCount: filtered.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final surah = filtered[index];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primaryEmerald.withValues(alpha: 0.12),
                    child: Text('${surah.number}', style: const TextStyle(color: Color(0xFF0F766E), fontWeight: FontWeight.bold)),
                  ),
                  title: Text(surah.name, textAlign: TextAlign.right, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                  subtitle: Text('${surah.englishName} - ${surah.ayahs.length} آية', textAlign: TextAlign.right),
                  trailing: const Icon(Icons.menu_book),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => SurahReaderScreen(surah: surah, allSurahs: widget.allSurahs)),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _JuzListTab extends StatelessWidget {
  final List<SurahModel> allSurahs;
  const _JuzListTab({required this.allSurahs});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: JuzData.all.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final juz = JuzData.all[index];
        final surah = allSurahs.firstWhere(
          (s) => s.number == juz.surahNumber,
          orElse: () => allSurahs.first,
        );

        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: AppColors.goldAccent.withValues(alpha: 0.15),
              child: Text('${juz.juzNumber}', style: const TextStyle(color: AppColors.goldAccent, fontWeight: FontWeight.bold)),
            ),
            title: Text('الجزء ${juz.juzNumber}', style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text('يبدأ من سورة ${surah.name} - آية ${juz.ayahNumber}'),
            trailing: const Icon(Icons.chevron_left),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SurahReaderScreen(surah: surah, allSurahs: allSurahs, scrollToAyah: juz.ayahNumber),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AyahSearchTab extends StatefulWidget {
  final List<SurahModel> allSurahs;
  final TextEditingController controller;
  const _AyahSearchTab({required this.allSurahs, required this.controller});

  @override
  State<_AyahSearchTab> createState() => _AyahSearchTabState();
}

class _AyahSearchTabState extends State<_AyahSearchTab> {
  @override
  Widget build(BuildContext context) {
    final query = widget.controller.text.trim();

    final results = <(SurahModel, AyahModel)>[];
    if (query.length >= 2) {
      for (final surah in widget.allSurahs) {
        for (final ayah in surah.ayahs) {
          if (ArabicTextUtils.contains(ayah.text, query)) {
            results.add((surah, ayah));
            if (results.length >= 100) break;
          }
        }
        if (results.length >= 100) break;
      }
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: widget.controller,
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.right,
            decoration: InputDecoration(
              hintText: 'ابحث في نص الآيات',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Theme.of(context).cardColor,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        if (query.isNotEmpty && query.length < 2)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('اكتب حرفين على الأقل للبحث', style: TextStyle(color: AppColors.mutedText)),
          ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
            itemCount: results.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final (surah, ayah) = results[index];
              return Card(
                child: ListTile(
                  title: Text(
                    ayah.text,
                    textDirection: TextDirection.rtl,
                    textAlign: TextAlign.right,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text('سورة ${surah.name} - آية ${ayah.number}', textAlign: TextAlign.right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SurahReaderScreen(surah: surah, allSurahs: widget.allSurahs, scrollToAyah: ayah.number),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _FavoritesTab extends StatelessWidget {
  final List<SurahModel> allSurahs;
  const _FavoritesTab({required this.allSurahs});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Set<String>>(
      future: UserProgressService.favoriteAyahs(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        final favUids = snapshot.data!;
        final results = <(SurahModel, AyahModel)>[];

        for (final surah in allSurahs) {
          for (final ayah in surah.ayahs) {
            if (favUids.contains('${surah.number}_${ayah.number}')) {
              results.add((surah, ayah));
            }
          }
        }

        if (results.isEmpty) {
          return const Center(child: Text('لا توجد آيات مفضلة بعد'));
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: results.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final (surah, ayah) = results[index];
            return Card(
              child: ListTile(
                title: Text(ayah.text, textDirection: TextDirection.rtl, textAlign: TextAlign.right, maxLines: 3, overflow: TextOverflow.ellipsis),
                subtitle: Text('سورة ${surah.name} - آية ${ayah.number}', textAlign: TextAlign.right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SurahReaderScreen(surah: surah, allSurahs: allSurahs, scrollToAyah: ayah.number),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class SurahReaderScreen extends StatefulWidget {
  final SurahModel surah;
  final List<SurahModel> allSurahs;
  final int? scrollToAyah;

  const SurahReaderScreen({super.key, required this.surah, required this.allSurahs, this.scrollToAyah});

  @override
  State<SurahReaderScreen> createState() => _SurahReaderScreenState();
}

class _SurahReaderScreenState extends State<SurahReaderScreen> {
  Set<String> _favoriteAyahs = {};
  final Map<int, GlobalKey> _ayahKeys = {};
  final AudioPlayer _player = AudioPlayer();
  final ScrollController _scrollController = ScrollController();

  double _fontScale = 1.0;
  late String _reciter = appSettings.reciterId;
  Map<String, String>? _tafsirData;
  final Set<int> _expandedTafsirAyahs = {};
  bool _loadingTafsir = false;
  int? _playingAyah; // ayah number currently playing, or null if playing whole surah / nothing
  bool _playingWholeSurah = false;
  bool _repeatCurrent = false;
  bool _isBuffering = false;

  late final int _surahAyahOffset; // sum of ayah counts of all surahs before this one

  String _uid(int ayahNumber) => '${widget.surah.number}_$ayahNumber';

  @override
  void initState() {
    super.initState();

    _surahAyahOffset = widget.allSurahs
        .where((s) => s.number < widget.surah.number)
        .fold(0, (sum, s) => sum + s.ayahs.length);

    for (final ayah in widget.surah.ayahs) {
      _ayahKeys[ayah.number] = GlobalKey();
    }

    _loadFavorites();
    _setupPlayer();

    if (widget.scrollToAyah != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToAyah(widget.scrollToAyah!));
    }
  }

  void _setupPlayer() {
    _player.onPlayerComplete.listen((_) {
      if (_repeatCurrent && _playingAyah != null) {
        _playAyah(_playingAyah!, keepRepeat: true);
      } else {
        setState(() {
          _playingAyah = null;
          _playingWholeSurah = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _player.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadFavorites() async {
    final favs = await UserProgressService.favoriteAyahs();
    if (mounted) setState(() => _favoriteAyahs = favs);
  }

  Future<void> _toggleFavorite(int ayahNumber) async {
    await UserProgressService.toggleFavoriteAyah(_uid(ayahNumber));
    final favs = await UserProgressService.favoriteAyahs();
    if (mounted) setState(() => _favoriteAyahs = favs);
  }

  /// [Scrollable.ensureVisible] silently does nothing if the target
  /// ayah's GlobalKey hasn't been built yet — and with a lazy
  /// [ListView.builder], any ayah outside the initially-visible range
  /// (e.g. jumping to ayah 200 of a 286-ayah surah from search) has no
  /// built context yet. Fix: jump to an estimated offset first so the
  /// target enters the built range, then retry ensureVisible across a
  /// few frames until it succeeds.
  Future<void> _scrollToAyah(int ayahNumber) async {
    if (_tryEnsureVisible(ayahNumber)) return;

    const estimatedItemExtent = 190.0;
    if (_scrollController.hasClients) {
      final maxScroll = _scrollController.position.maxScrollExtent;
      final targetOffset = (ayahNumber * estimatedItemExtent).clamp(0.0, maxScroll);
      _scrollController.jumpTo(targetOffset);
    }

    for (var attempt = 0; attempt < 6; attempt++) {
      await Future.delayed(const Duration(milliseconds: 80));
      if (!mounted) return;
      if (_tryEnsureVisible(ayahNumber)) return;
    }
  }

  bool _tryEnsureVisible(int ayahNumber) {
    final key = _ayahKeys[ayahNumber];
    final ctx = key?.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 300), alignment: 0.1);
      return true;
    }
    return false;
  }

  Future<void> _pickReciter() async {
    final chosen = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('اختر القارئ', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            ),
            for (final reciter in Reciters.all)
              ListTile(
                title: Text(reciter.displayName),
                trailing: reciter.id == _reciter ? const Icon(Icons.check, color: AppColors.primaryEmerald) : null,
                onTap: () => Navigator.pop(context, reciter.id),
              ),
          ],
        ),
      ),
    );

    if (chosen != null && chosen != _reciter) {
      await _stopAudio();
      setState(() => _reciter = chosen);
      await appSettings.setReciterId(chosen);
    }
  }

  Future<void> _toggleTafsir(int ayahNumber) async {
    if (_expandedTafsirAyahs.contains(ayahNumber)) {
      setState(() => _expandedTafsirAyahs.remove(ayahNumber));
      return;
    }

    if (_tafsirData == null) {
      setState(() => _loadingTafsir = true);
      try {
        _tafsirData = await TafsirRepository.load();
      } catch (e, st) {
        AppLogger.error('Failed to load tafsir', error: e, stackTrace: st);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تعذر تحميل التفسير — تحقق من الاتصال')),
          );
        }
        setState(() => _loadingTafsir = false);
        return;
      }
      setState(() => _loadingTafsir = false);
    }

    setState(() => _expandedTafsirAyahs.add(ayahNumber));
  }

  Future<void> _bookmark(int ayahNumber) async {
    await UserProgressService.saveLastReading(
      surahNumber: widget.surah.number,
      surahName: widget.surah.name,
      ayahNumber: ayahNumber,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('تم حفظ آخر قراءة: سورة ${widget.surah.name} - آية $ayahNumber')),
    );
  }

  void _copyAyah(AyahModel ayah) {
    Clipboard.setData(ClipboardData(text: '${ayah.text} (سورة ${widget.surah.name}: ${ayah.number})'));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم نسخ الآية')));
  }

  Future<void> _markSurahReadToday() async {
    await UserProgressService.markPageRead();
    await UserProgressService.registerStreakCheckpoint();
    await UserProgressService.markSurahCompleted(widget.surah.number);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أُضيفت هذه القراءة إلى وردك اليومي 🌿')));
  }

  Future<void> _playAyah(int ayahNumber, {bool keepRepeat = false}) async {
    final globalNumber = _surahAyahOffset + ayahNumber;
    setState(() {
      _playingAyah = ayahNumber;
      _playingWholeSurah = false;
      _isBuffering = true;
      if (!keepRepeat) _repeatCurrent = false;
    });

    // .stop() throws if nothing is currently loaded (e.g. the very first
    // playback attempt) — that exception was previously being caught
    // below and shown to the user as a false "playback failed" error on
    // every single attempt. Swallow it here specifically; it's not a
    // real failure.
    try {
      await _player.stop();
    } catch (_) {
      // Nothing was loaded — expected on first play, safe to ignore.
    }

    try {
      await _player.play(UrlSource(AppSources.ayahAudioUrl(globalNumber, reciter: _reciter)));
    } catch (e, st) {
      AppLogger.error('Ayah audio playback failed', error: e, stackTrace: st);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر تشغيل الصوت: $e')),
        );
        setState(() => _playingAyah = null);
      }
    } finally {
      if (mounted) setState(() => _isBuffering = false);
    }
  }

  Future<void> _playWholeSurah() async {
    setState(() {
      _playingWholeSurah = true;
      _playingAyah = null;
      _isBuffering = true;
    });

    try {
      await _player.stop();
    } catch (_) {
      // Nothing was loaded — expected on first play, safe to ignore.
    }

    // Surah-level audio isn't guaranteed to exist at every bitrate for
    // every reciter (unlike ayah-level audio) — try a few known-valid
    // bitrates in order rather than assuming one fixed value.
    const bitratesToTry = ['128', '64', '192', '32'];
    Object? lastError;

    for (final bitrate in bitratesToTry) {
      try {
        await _player.play(UrlSource(
          AppSources.surahAudioUrl(widget.surah.number, reciter: _reciter, bitrate: bitrate),
        ));
        lastError = null;
        break;
      } catch (e) {
        lastError = e;
        continue;
      }
    }

    if (lastError != null) {
      AppLogger.error('Surah audio playback failed at all bitrates', error: lastError);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر تشغيل صوت السورة كاملة لهذا القارئ — جرّب قارئًا آخر')),
        );
        setState(() => _playingWholeSurah = false);
      }
    }

    if (mounted) setState(() => _isBuffering = false);
  }

  Future<void> _stopAudio() async {
    try {
      await _player.stop();
    } catch (_) {
      // Already stopped/nothing loaded — fine, just reset UI state below.
    }
    if (mounted) {
      setState(() {
        _playingAyah = null;
        _playingWholeSurah = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final surah = widget.surah;

    return Scaffold(
      appBar: AppBar(
        title: Text('سورة ${surah.name}'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'اختيار القارئ (${Reciters.byId(_reciter).displayName})',
            onPressed: _pickReciter,
            icon: const Icon(Icons.record_voice_over_outlined),
          ),
          IconButton(
            tooltip: 'تصغير الخط',
            onPressed: () => setState(() => _fontScale = (_fontScale - 0.1).clamp(0.7, 1.6)),
            icon: const Icon(Icons.text_decrease),
          ),
          IconButton(
            tooltip: 'تكبير الخط',
            onPressed: () => setState(() => _fontScale = (_fontScale + 0.1).clamp(0.7, 1.6)),
            icon: const Icon(Icons.text_increase),
          ),
          IconButton(
            tooltip: 'أضف إلى الورد اليومي',
            onPressed: _markSurahReadToday,
            icon: const Icon(Icons.playlist_add_check),
          ),
        ],
      ),
      body: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount: surah.ayahs.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [AppColors.primaryEmerald, Color(0xFF115E56)]),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  children: [
                    Text('سورة ${surah.name}', style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('${surah.ayahs.length} آية', style: const TextStyle(color: AppColors.goldAccent, fontSize: 18)),
                    const SizedBox(height: 14),
                    Semantics(
                      button: true,
                      label: _playingWholeSurah ? 'إيقاف تلاوة السورة' : 'تشغيل تلاوة السورة كاملة',
                      child: ElevatedButton.icon(
                        onPressed: _playingWholeSurah ? _stopAudio : _playWholeSurah,
                        icon: Icon(_playingWholeSurah ? Icons.stop : Icons.play_arrow),
                        label: Text(_playingWholeSurah ? 'إيقاف' : 'تشغيل السورة كاملة'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppColors.primaryEmerald),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final ayah = surah.ayahs[index - 1];
          final isFavorite = _favoriteAyahs.contains(_uid(ayah.number));
          final isPlayingThis = _playingAyah == ayah.number;
          final isTafsirExpanded = _expandedTafsirAyahs.contains(ayah.number);
          final tafsirText = _tafsirData != null
              ? TafsirRepository.tafsirFor(_tafsirData!, surah.number, ayah.number)
              : null;

          return Card(
            key: _ayahKeys[ayah.number],
            margin: const EdgeInsets.only(bottom: 12),
            color: isPlayingThis ? AppColors.primaryEmerald.withValues(alpha: 0.06) : null,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '${ayah.text}  ﴿${ayah.number}﴾',
                    textDirection: TextDirection.rtl,
                    textAlign: TextAlign.right,
                    style: TextStyle(fontSize: 24 * _fontScale, height: 2, fontWeight: FontWeight.w600),
                  ),
                  if (isTafsirExpanded) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.goldAccent.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        tafsirText ?? 'لا يتوفر تفسير لهذه الآية',
                        textDirection: TextDirection.rtl,
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontSize: 14, height: 1.7, color: AppColors.mutedText),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Wrap(
                    alignment: WrapAlignment.start,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Semantics(
                        button: true,
                        label: isPlayingThis ? 'إيقاف تشغيل الآية' : 'تشغيل الآية ${ayah.number}',
                        child: IconButton(
                          tooltip: isPlayingThis ? 'إيقاف' : 'تشغيل الآية',
                          onPressed: () => isPlayingThis ? _stopAudio() : _playAyah(ayah.number),
                          icon: isPlayingThis && _isBuffering
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                              : Icon(isPlayingThis ? Icons.stop_circle_outlined : Icons.play_circle_outline,
                                  color: AppColors.primaryEmerald),
                        ),
                      ),
                      IconButton(
                        tooltip: 'تكرار هذه الآية',
                        onPressed: () => setState(() => _repeatCurrent = isPlayingThis ? !_repeatCurrent : false),
                        icon: Icon(
                          Icons.repeat,
                          color: isPlayingThis && _repeatCurrent ? AppColors.goldAccent : AppColors.mutedText,
                        ),
                      ),
                      IconButton(
                        tooltip: isTafsirExpanded ? 'إخفاء التفسير' : 'عرض التفسير الميسر',
                        onPressed: (_loadingTafsir && !isTafsirExpanded) ? null : () => _toggleTafsir(ayah.number),
                        icon: (_loadingTafsir && !isTafsirExpanded)
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : Icon(Icons.menu_book_outlined, color: isTafsirExpanded ? AppColors.goldAccent : AppColors.mutedText),
                      ),
                      IconButton(
                        tooltip: 'حفظ كآخر قراءة',
                        onPressed: () => _bookmark(ayah.number),
                        icon: const Icon(Icons.bookmark_border, color: AppColors.mutedText),
                      ),
                      IconButton(
                        tooltip: 'نسخ الآية',
                        onPressed: () => _copyAyah(ayah),
                        icon: const Icon(Icons.copy_outlined, color: AppColors.mutedText),
                      ),
                      Semantics(
                        button: true,
                        label: isFavorite ? 'إزالة من المفضلة' : 'إضافة للمفضلة',
                        child: IconButton(
                          tooltip: 'إضافة للمفضلة',
                          onPressed: () => _toggleFavorite(ayah.number),
                          icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border,
                              color: isFavorite ? AppColors.goldAccent : AppColors.mutedText),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 48, color: AppColors.mutedText),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onRetry, child: const Text('إعادة المحاولة')),
          ],
        ),
      ),
    );
  }
}
