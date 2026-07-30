import 'package:flutter/material.dart';

/// Genuine privacy policy text describing exactly what this codebase does
/// as of this version: local-only storage, location used solely for
/// prayer-time calculation via AlAdhan, no accounts, no ads, no analytics
/// SDKs. Keep this in sync with the actual data flows if any are added
/// (e.g. if an analytics or ads SDK is introduced later, this text and
/// the Data Safety form in Play Console both need updating).
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static const _sections = [
    (
      'البيانات التي يجمعها التطبيق',
      'لا ينشئ التطبيق حسابًا للمستخدم ولا يجمع اسمك أو بريدك الإلكتروني. '
          'يُستخدم موقعك الجغرافي (خطوط الطول والعرض) فقط عند فتح شاشة مواقيت '
          'الصلاة، لحساب أوقات الصلاة عبر خدمة AlAdhan الخارجية، ولا يُخزَّن '
          'هذا الموقع أو يُشارك لأي غرض آخر.'
    ),
    (
      'أين تُخزَّن بياناتك',
      'كل بيانات الاستخدام — المفضلة، عدادات الأذكار، إحصاءات التسبيح، '
          'آخر قراءة، إعدادات الوضع الليلي وحجم الخط — تُخزَّن محليًا على '
          'جهازك فقط باستخدام SharedPreferences، ولا تُرسَل إلى أي خادم '
          'تابع للتطبيق. حذف التطبيق أو استخدام خيار "حذف البيانات المحلية" '
          'في الإعدادات يمسحها نهائيًا.'
    ),
    (
      'خدمات خارجية يتصل بها التطبيق',
      '• نص القرآن الكريم: يُحمَّل من مصدر Quran JSON (المبني على بيانات '
          'Tanzil).\n'
          '• الأذكار: تُحمَّل من مصدر Hisn Al-Muslim / Islamic Pro Azkar API.\n'
          '• مواقيت الصلاة: تُحسب عبر AlAdhan Prayer Times API باستخدام '
          'موقعك الحالي.\n'
          'هذه الطلبات تذهب مباشرة من جهازك إلى تلك الخدمات؛ يُرجى مراجعة '
          'سياسات الخصوصية الخاصة بها لمزيد من التفاصيل حول كيفية معالجتها '
          'للطلبات.'
    ),
    (
      'الإعلانات والتحليلات',
      'لا يحتوي التطبيق على إعلانات، ولا يستخدم أي أداة تحليلات أو تتبع '
          'لسلوك المستخدم في هذا الإصدار.'
    ),
    (
      'أذونات الجهاز',
      'يطلب التطبيق إذن الموقع فقط لعرض مواقيت صلاة دقيقة، ويمكنك رفضه '
          'أو إلغاءه في أي وقت من إعدادات النظام؛ ستظل بقية ميزات التطبيق '
          'تعمل بدونه.'
    ),
    (
      'تواصل معنا',
      'لأي استفسار بخصوص هذه السياسة، يرجى التواصل عبر معلومات المطوّر '
          'الموضحة في صفحة التطبيق على المتجر.'
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('سياسة الخصوصية'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'آخر تحديث: يوليو 2026',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 16),
          for (final (title, body) in _sections) ...[
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
            const SizedBox(height: 6),
            Text(body, style: const TextStyle(height: 1.7)),
            const SizedBox(height: 20),
          ],
        ],
      ),
    );
  }
}
