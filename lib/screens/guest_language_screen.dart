import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:agroww_sih/services/localization_service.dart';

/// Guest Language Selection Screen
/// Shown after guest login to let user choose Hindi or English
class GuestLanguageScreen extends StatelessWidget {
  const GuestLanguageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const Color primaryDark = Color(0xFF0F3C33);
    const Color limeGreen = Color(0xFF9FE870);
    const Color backgroundLight = Color(0xFFE8F5F3);

    return Scaffold(
      backgroundColor: backgroundLight,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 60),
            
            // Header with decorative bars (similar to intro screen)
            _buildHeader(context, limeGreen, primaryDark),
            
            const Spacer(flex: 1),
            
            // Main Content
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  // Question Text
                  const Text(
                    "Choose Your Language",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: primaryDark,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "अपनी भाषा चुनें",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: primaryDark,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),
                  
                  // Language Options
                  _buildLanguageOption(
                    context,
                    title: "English",
                    subtitle: "Continue in English",
                    icon: "🇬🇧",
                    language: AppLanguage.english,
                    primaryDark: primaryDark,
                    limeGreen: limeGreen,
                  ),
                  const SizedBox(height: 16),
                  _buildLanguageOption(
                    context,
                    title: "हिंदी",
                    subtitle: "हिंदी में जारी रखें",
                    icon: "🇮🇳",
                    language: AppLanguage.hindi,
                    primaryDark: primaryDark,
                    limeGreen: limeGreen,
                  ),
                ],
              ),
            ),
            
            const Spacer(flex: 2),
            
            // Footer hint
            Padding(
              padding: const EdgeInsets.only(bottom: 40),
              child: Text(
                "You can change this later in Settings",
                style: TextStyle(
                  fontSize: 14,
                  color: primaryDark.withOpacity(0.6),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, Color limeGreen, Color primaryDark) {
    // Decorative bars similar to intro screen
    final List<Color> barColors = [
      const Color(0xFFA8D5BA),
      const Color(0xFFC5E898),
      limeGreen,
    ];
    final List<double> barWidths = [0.35, 0.55, 0.75];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(barColors.length, (index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          height: 30,
          width: MediaQuery.of(context).size.width * barWidths[index],
          decoration: BoxDecoration(
            color: barColors[index],
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(15),
              bottomLeft: Radius.circular(15),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildLanguageOption(
    BuildContext context, {
    required String title,
    required String subtitle,
    required String icon,
    required AppLanguage language,
    required Color primaryDark,
    required Color limeGreen,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          // Set the language
          final locProvider = context.read<LocalizationProvider>();
          await locProvider.setLanguage(language);
          
          // Navigate to Locate Farmland
          if (context.mounted) {
            Navigator.pushReplacementNamed(context, '/locate-farmland');
          }
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: primaryDark.withOpacity(0.1), width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Icon
              Text(
                icon,
                style: const TextStyle(fontSize: 36),
              ),
              const SizedBox(width: 16),
              // Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: primaryDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: primaryDark.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
              // Arrow
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: limeGreen,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.arrow_forward,
                  color: primaryDark,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
