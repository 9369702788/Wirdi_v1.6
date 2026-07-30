import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('عن التطبيق'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: AppColors.primaryEmerald.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.spa_outlined, color: AppColors.primaryEmerald, size: 40),
            ),
          ),
          const SizedBox(height: 16),
          const Center(
            child: Text('وردي | Wirdi', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 4),
          const Center(
            child: Text('رفيقك اليومي للذكر والقرآن', style: TextStyle(color: AppColors.mutedText)),
          ),
          const SizedBox(height: 4),
          const Center(
            child: Text('الإصدار 1.0.0', style: TextStyle(color: AppColors.mutedText, fontSize: 12)),
          ),
          const SizedBox(height: 28),
          const Text(
            'وردي تطبيق إسلامي يومي يساعدك على متابعة قراءة القرآن، وأذكارك، '
            'ومواقيت صلاتك، وتسبيحك، في مكان واحد بتصميم هادئ وبسيط. '
            'لا يحتوي التطبيق على إعلانات أو تتبع، وجميع بياناتك تبقى على جهازك.',
            style: TextStyle(height: 1.8),
          ),
        ],
      ),
    );
  }
}
