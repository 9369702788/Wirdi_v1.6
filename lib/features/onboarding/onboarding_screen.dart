import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class _Slide {
  final IconData icon;
  final String title;
  const _Slide(this.icon, this.title);
}

const _slides = [
  _Slide(Icons.menu_book_outlined, 'اجعل القرآن جزءًا من يومك'),
  _Slide(Icons.check_circle_outline, 'تابع وردك اليومي وابنِ عادة'),
  _Slide(Icons.nightlight_outlined, 'ذكّر قلبك قبل أن يذكرك الوقت'),
];

/// Screen 2 — Onboarding: "تعريف المستخدم بالفكرة قبل الدخول"
class OnboardingScreen extends StatefulWidget {
  final VoidCallback onFinished;
  const OnboardingScreen({super.key, required this.onFinished});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: widget.onFinished,
                child: const Text('تخطي'),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) {
                  final slide = _slides[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: AppColors.primaryEmerald.withValues(alpha: 0.08),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(slide.icon,
                              size: 56, color: AppColors.primaryEmerald),
                        ),
                        const SizedBox(height: 32),
                        Text(
                          slide.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _slides.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: i == _index ? 20 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: i == _index
                        ? AppColors.primaryEmerald
                        : AppColors.primaryEmerald.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (_index == _slides.length - 1) {
                      widget.onFinished();
                    } else {
                      _controller.nextPage(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOut,
                      );
                    }
                  },
                  child: Text(
                    _index == _slides.length - 1 ? 'ابدأ رحلتك' : 'التالي',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
