import 'package:flutter/material.dart';

import '../../core/models/mushaf_models.dart';
import '../../core/services/mushaf_repository.dart';
import '../../core/services/user_progress_service.dart';
import '../../core/theme/app_theme.dart';

/// Real page-by-page mushaf-style reading view (604 pages, genuine
/// ayah-to-page mapping), as an alternative to the continuous
/// per-surah list view in the Quran tab. Swipe left/right between pages.
class MushafViewScreen extends StatefulWidget {
  final int? initialPage;
  const MushafViewScreen({super.key, this.initialPage});

  @override
  State<MushafViewScreen> createState() => _MushafViewScreenState();
}

class _MushafViewScreenState extends State<MushafViewScreen> {
  late Future<List<MushafPage>> _future;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _future = MushafRepository.load();
    _pageController = PageController(initialPage: (widget.initialPage ?? 1) - 1);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('المصحف'), centerTitle: true),
      body: FutureBuilder<List<MushafPage>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError || snapshot.data == null || snapshot.data!.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.wifi_off_rounded, size: 48, color: AppColors.mutedText),
                    const SizedBox(height: 12),
                    const Text('تعذر تحميل صفحات المصحف. تأكد من اتصال الإنترنت.', textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => setState(() => _future = MushafRepository.load(forceRefresh: true)),
                      child: const Text('إعادة المحاولة'),
                    ),
                  ],
                ),
              ),
            );
          }

          final pages = snapshot.data!;

          return PageView.builder(
            controller: _pageController,
            reverse: true, // mushaf pages progress right-to-left
            itemCount: pages.length,
            onPageChanged: (index) {
              UserProgressService.saveLastReading(
                surahNumber: pages[index].ayahs.isNotEmpty ? pages[index].ayahs.first.surahNumber : 1,
                surahName: '',
                ayahNumber: pages[index].ayahs.isNotEmpty ? pages[index].ayahs.first.ayahNumber : 1,
              );
            },
            itemBuilder: (context, index) {
              final page = pages[index];
              return _MushafPageView(page: page);
            },
          );
        },
      ),
    );
  }
}

class _MushafPageView extends StatelessWidget {
  final MushafPage page;
  const _MushafPageView({required this.page});

  @override
  Widget build(BuildContext context) {
    // Group consecutive ayahs by surah so a page spanning two surahs
    // shows a clear divider, matching how a real mushaf page reads.
    final groups = <int, List<MushafAyahRef>>{};
    for (final ayah in page.ayahs) {
      groups.putIfAbsent(ayah.surahNumber, () => []).add(ayah);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final entry in groups.entries) ...[
            Text.rich(
              TextSpan(
                children: entry.value
                    .map((a) => TextSpan(text: '${a.text} ﴿${a.ayahNumber}﴾ '))
                    .toList(),
              ),
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.justify,
              style: const TextStyle(fontSize: 22, height: 2.1, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
          ],
          const Divider(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('الجزء ${page.juzNumber}', style: const TextStyle(color: AppColors.mutedText, fontSize: 12)),
              Text('صفحة ${page.pageNumber}', style: const TextStyle(color: AppColors.mutedText, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}
