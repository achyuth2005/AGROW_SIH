import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class DownloadSettingsScreen extends StatelessWidget {
  final VoidCallback onBackToInfographics;
  final VoidCallback onBackToMenu;
  const DownloadSettingsScreen({
    super.key,
    required this.onBackToInfographics,
    required this.onBackToMenu,
  });

  @override
  Widget build(BuildContext context) {
    final brand = const Color(0xFF167339);

    return Scaffold(
      backgroundColor: const Color(0xFF0D986A),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              children: [
                // Top bar
                Padding(
                  padding: const EdgeInsets.all(18.0),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        backgroundColor: Colors.white,
                        child: Icon(Icons.person, color: Color(0xFF0D986A)),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Container(
                          height: 38,
                          decoration: BoxDecoration(
                            color: Colors.green.shade300,
                            borderRadius: BorderRadius.circular(22),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: const Row(
                            children: [
                              Icon(Icons.search, color: Color(0xFF167339)),
                              SizedBox(width: 8),
                              Text('Search', style: TextStyle(color: Color(0xFF167339))),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Icon(Icons.download, color: Colors.white),
                    ],
                  ),
                ).animate().fadeIn().slideY(begin: -0.5, end: 0),

                const Padding(
                  padding: EdgeInsets.only(bottom: 8.0),
                  child: Text(
                    'Infographics',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ).animate().fadeIn(delay: 200.ms),

                // Card
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 26),
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF003A2A), Color(0x00003A2A)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.circular(26),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Material(
                            color: Colors.green[200],
                            shape: const CircleBorder(),
                            child: SizedBox(
                              width: 50,
                              height: 50,
                              child: Icon(Icons.download_rounded, color: brand),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Download Settings',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Two big buttons
                      Row(
                        children: [
                          Expanded(
                            child: _bigOption(
                              title: 'Download All\nGraphs',
                              icon: Icons.cloud_download,
                              brand: brand,
                              onTap: () {},
                            ).animate().fadeIn(delay: 400.ms).scale(),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _bigOption(
                              title: 'Select the Graphs\nto be Downloaded',
                              icon: Icons.select_all,
                              brand: brand,
                              trailing: const Icon(Icons.arrow_drop_down, color: Color(0xFF167339)),
                              onTap: () {},
                            ).animate().fadeIn(delay: 500.ms).scale(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Select format button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green[200],
                            foregroundColor: brand,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                          ),
                          onPressed: () {},
                          child: const Text('Select Format'),
                        ),
                      ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.2, end: 0),
                      const SizedBox(height: 18),

                      // Back actions
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: brand.withOpacity(0.9),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                          ),
                          onPressed: onBackToInfographics,
                          child: const Text('Back to Infographics'),
                        ),
                      ).animate().fadeIn(delay: 700.ms).slideY(begin: 0.2, end: 0),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: brand.withOpacity(0.7),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                          ),
                          onPressed: onBackToMenu,
                          child: const Text('Back to Menu'),
                        ),
                      ).animate().fadeIn(delay: 800.ms).slideY(begin: 0.2, end: 0),
                    ],
                  ),
                ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.1, end: 0),

                const Spacer(),

                // Bottom home chip
                Container(
                  height: 56,
                  width: 96,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF003A2A), Color(0xFF167339)]),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: const Center(
                    child: Icon(Icons.home, color: Colors.white, size: 28),
                  ),
                ).animate().scale(delay: 900.ms, curve: Curves.easeOutBack),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _bigOption({
    required String title,
    required IconData icon,
    required Color brand,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return Material(
      color: Colors.green[200],
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(icon, color: brand, size: 30),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF0D3F2C),
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(height: 6),
                trailing,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
