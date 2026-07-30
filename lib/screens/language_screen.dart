import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';

class LanguageScreen extends StatelessWidget {
  const LanguageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final languageProvider = context.watch<LanguageProvider>();
    final currentLanguageCode = languageProvider.locale.languageCode;

    final List<Map<String, dynamic>> languages = [
      {
        'code': 'en',
        'name': 'English',
        'nativeName': 'English',
        'flag': '🇬🇧',
      },
      {
        'code': 'hi',
        'name': 'Hindi',
        'nativeName': 'हिन्दी',
        'flag': '🇮🇳',
      },
      {
        'code': 'ml',
        'name': 'Malayalam',
        'nativeName': 'മലയാളം',
        'flag': '🇮🇳',
      },
      {
        'code': 'te',
        'name': 'Telugu',
        'nativeName': 'తెలుగు',
        'flag': '🇮🇳',
      },
      {
        'code': 'ta',
        'name': 'Tamil',
        'nativeName': 'தமிழ்',
        'flag': '🇮🇳',
      },
      {
        'code': 'kn',
        'name': 'Kannada',
        'nativeName': 'ಕನ್ನಡ',
        'flag': '🇮🇳',
      },
      {
        'code': 'or',
        'name': 'Odia',
        'nativeName': 'ଓଡ଼ିଆ',
        'flag': '🇮🇳',
      },
      {
        'code': 'ar',
        'name': 'Arabic',
        'nativeName': 'العربية',
        'flag': '🇦🇪',
      },
      {
        'code': 'ur',
        'name': 'Urdu',
        'nativeName': 'اردو',
        'flag': '🇵🇰',
      },
      {
        'code': 'bn',
        'name': 'Bengali',
        'nativeName': 'বাংলা',
        'flag': '🇧🇩',
      },
      {
        'code': 'si',
        'name': 'Sinhala (Sri Lanka)',
        'nativeName': 'සිංහල',
        'flag': '🇱🇰',
      },
      {
        'code': 'ps',
        'name': 'Pashto (Afghanistan)',
        'nativeName': 'پښتو',
        'flag': '🇦🇫',
      },
      {
        'code': 'fa',
        'name': 'Dari (Afghanistan)',
        'nativeName': 'دری',
        'flag': '🇦🇫',
      },
      {
        'code': 'ru',
        'name': 'Russian',
        'nativeName': 'Русский',
        'flag': '🇷🇺',
      },
      {
        'code': 'zh',
        'name': 'Chinese',
        'nativeName': '中文 (简体)',
        'flag': '🇨🇳',
      },
      {
        'code': 'vi',
        'name': 'Vietnamese',
        'nativeName': 'Tiếng Việt',
        'flag': '🇻🇳',
      },
      {
        'code': 'th',
        'name': 'Thai',
        'nativeName': 'ไทย',
        'flag': '🇹🇭',
      },
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Text(
          context.translate('select_language'),
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
      ),
      body: Stack(
        children: [
          ListView.builder(
            padding: REdgeInsets.all(16),
            itemCount: languages.length,
            itemBuilder: (context, index) {
              final lang = languages[index];
              final isSelected = lang['code'] == currentLanguageCode;

              return Card(
                margin: EdgeInsets.only(bottom: 12.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.r),
                  side: BorderSide(
                    color: isSelected ? const Color(0xFF000080) : Colors.transparent,
                    width: 2.w,
                  ),
                ),
                elevation: isSelected ? 4 : 1,
                shadowColor: isSelected
                    ? const Color(0xFF000080).withValues(alpha: 0.3)
                    : Colors.black12,
                child: InkWell(
                  onTap: languageProvider.isLoading
                      ? null
                      : () async {
                          try {
                            await languageProvider.setLanguage(lang['code']);
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('${context.tr('Failed to download translations')}: $e. ${context.tr('Using local fallback.')}'),
                                  backgroundColor: Colors.amber[800],
                                ),
                              );
                            }
                          }
                        },
                  borderRadius: BorderRadius.circular(16.r),
                  child: Padding(
                    padding: REdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Row(
                      children: [
                        Text(
                          lang['flag'],
                          style: TextStyle(fontSize: 24.sp),
                        ),
                        SizedBox(width: 16.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                lang['nativeName'],
                                style: GoogleFonts.inter(
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF1E293B),
                                ),
                              ),
                              SizedBox(height: 2.h),
                              Text(
                                lang['name'],
                                style: GoogleFonts.inter(
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          Icon(
                            Icons.check_circle_rounded,
                            color: const Color(0xFF000080),
                            size: 24.r,
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          if (languageProvider.isLoading)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.35),
                child: Center(
                  child: Container(
                    padding: REdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16.r),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 10.r,
                          offset: Offset(0, 4.h),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF000080)),
                        ),
                        SizedBox(height: 16.h),
                        Text(
                          context.tr('Downloading translations...'),
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            fontSize: 14.sp,
                            color: const Color(0xFF1E293B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
