import 'package:flutter/material.dart';
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
            padding: const EdgeInsets.all(16),
            itemCount: languages.length,
            itemBuilder: (context, index) {
              final lang = languages[index];
              final isSelected = lang['code'] == currentLanguageCode;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: isSelected ? const Color(0xFF000080) : Colors.transparent,
                    width: 2,
                  ),
                ),
                elevation: isSelected ? 4 : 1,
                shadowColor: isSelected
                    ? const Color(0xFF000080).withOpacity(0.3)
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
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Row(
                      children: [
                        Text(
                          lang['flag'],
                          style: const TextStyle(fontSize: 24),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                lang['nativeName'],
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF1E293B),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                lang['name'],
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          const Icon(
                            Icons.check_circle_rounded,
                            color: Color(0xFF000080),
                            size: 24,
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
                color: Colors.black.withOpacity(0.35),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF000080)),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          context.tr('Downloading translations...'),
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
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
