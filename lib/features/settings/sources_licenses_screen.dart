import 'package:flutter/material.dart';

import '../../core/data/app_sources.dart';

class SourcesLicensesScreen extends StatelessWidget {
  const SourcesLicensesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('المصادر والتراخيص'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            AppSources.sourcesAndLicenses.trim(),
            style: const TextStyle(height: 1.8, fontSize: 15),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => showLicensePage(
              context: context,
              applicationName: 'وردي | Wirdi',
            ),
            icon: const Icon(Icons.description_outlined),
            label: const Text('تراخيص حزم البرمجيات مفتوحة المصدر'),
          ),
        ],
      ),
    );
  }
}
