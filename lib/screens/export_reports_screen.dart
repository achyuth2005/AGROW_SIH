import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:agroww_sih/widgets/adaptive_bottom_nav_bar.dart';

class ExportReportsScreen extends StatelessWidget {
  const ExportReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8F5F3), // Light mint background
      bottomNavigationBar: const AdaptiveBottomNavBar(page: ActivePage.home),
      body: Column(
        children: [
          // Header
          Stack(
            children: [
              Image.asset(
                'assets/backsmall.png',
                width: double.infinity,
                fit: BoxFit.fitWidth,
                alignment: Alignment.topCenter,
              ),
              Positioned(
                top: 50,
                left: 20,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                  ),
                ),
              ),
              Positioned(
                top: 50,
                left: 0,
                right: 0,
                child: Center(
                  child: Text(
                    "Export Reports",
                    style: GoogleFonts.manrope(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Section 1: Summarized Analytics
                  _buildSectionCard(
                    title: "Export Summarized Analytics",
                    buttons: [
                      _buildExportButton("Export all categories with standard reports."),
                      const SizedBox(height: 12),
                      _buildExportButton("Export all categories with anomaly reports."),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Section 2: Detailed Analytics
                  _buildSectionCard(
                    title: "Export Detailed Analytics",
                    buttons: [
                      _buildExportButton("Export all categories with standard reports."),
                      const SizedBox(height: 12),
                      _buildExportButton("Export all categories with anomaly reports."),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Section 3: Mapped Analytics (Standalone Button Style)
                  _buildExportButton(
                    "Export Mapped Analytics",
                    isStandalone: true,
                  ),
                  
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({required String title, required List<Widget> buttons}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.manrope(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF0F3C33),
            ),
          ),
          const SizedBox(height: 16),
          ...buttons,
        ],
      ),
    );
  }

  Widget _buildExportButton(String text, {bool isStandalone = false}) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 55),
      child: ElevatedButton(
        onPressed: () {
          // Placeholder for export logic
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF557C70), // Dark Slate Green
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                text,
                style: GoogleFonts.manrope(
                  fontSize: isStandalone ? 18 : 14,
                  fontWeight: FontWeight.w500,
                  height: 1.2,
                ),
              ),
            ),
            const SizedBox(width: 16),
            const Icon(Icons.download_rounded),
          ],
        ),
      ),
    );
  }
}
