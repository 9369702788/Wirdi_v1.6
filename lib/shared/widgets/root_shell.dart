import 'package:flutter/material.dart';

import '../../features/home/home_dashboard_screen.dart';
import '../../features/prayer/prayer_times_screen.dart';
import '../../features/tasbeeh/tasbeeh_screen.dart';
import '../../features/quran/quran_screen.dart';
import '../../features/azkar/azkar_screen.dart';
import '../../features/settings/settings_screen.dart';

class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;

  static final List<Widget> _screens = [
    const HomeDashboardScreen(),
    const QuranScreen(),
    const AzkarScreen(),
    const PrayerTimesScreen(),
    const TasbeehScreen(),
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) {
          setState(() {
            _index = i;
          });
        },
        type: BottomNavigationBarType.fixed,
        selectedFontSize: 11,
        unselectedFontSize: 11,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'الرئيسية',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.menu_book_outlined),
            activeIcon: Icon(Icons.menu_book),
            label: 'القرآن',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite_outline),
            activeIcon: Icon(Icons.favorite),
            label: 'الأذكار',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.access_time),
            activeIcon: Icon(Icons.access_time_filled),
            label: 'الصلاة',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.fingerprint),
            activeIcon: Icon(Icons.fingerprint),
            label: 'التسبيح',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: 'المزيد',
          ),
        ],
      ),
    );
  }
}
