import 'package:flutter/material.dart';
import 'download_settings_screen.dart';

class InfographicsScreen extends StatefulWidget {
  const InfographicsScreen({super.key});
  @override
  State<InfographicsScreen> createState() => _InfographicsScreenState();
}

class _InfographicsScreenState extends State<InfographicsScreen> {
  final PageController _pageController = PageController();
  int _index = 0;

  final List<_MetricTab> tabs = const [
    _MetricTab(code: 'NDVI', label: 'NDVI Interactive Map'),
    _MetricTab(code: 'OSAVI', label: 'OSAVI Interactive Map'),
    _MetricTab(code: 'ARVI', label: 'ARVI Interactive Map'),
    _MetricTab(code: 'NDWI', label: 'NDWI Interactive Map'),
  ];

  void _goDownload() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DownloadSettingsScreen(
          onBackToInfographics: () => Navigator.pop(context),
          onBackToMenu: () => Navigator.popUntil(context, (r) => r.isFirst),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const greenBg = Color(0xFF0D986A);
    const brand = Color(0xFF167339);

    return Scaffold(
      backgroundColor: greenBg,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
              child: Row(
                children: const [
                  CircleAvatar(
                    backgroundColor: Colors.white,
                    child: Icon(Icons.person, color: greenBg),
                  ),
                  SizedBox(width: 12),
                  _SearchBar(),
                  SizedBox(width: 10),
                  _DownloadButton(),
                ],
              ),
            ),

            // Title
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'Infographics',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  height: 1.1,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),

            // Main container
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(26),
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF083D2C), Color(0x00083D2C)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    child: Row(
                      children: [
                        // Content card with pager
                        Expanded(
                          child: Container(
                            margin: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.green[50],
                              borderRadius: BorderRadius.circular(22),
                            ),
                            child: Column(
                              children: [
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                                    child: PageView.builder(
                                      controller: _pageController,
                                      onPageChanged: (i) => setState(() => _index = i),
                                      itemCount: tabs.length,
                                      physics: const BouncingScrollPhysics(),
                                      itemBuilder: (context, i) {
                                        final tab = tabs[i];
                                        return _MetricPanel(
                                          code: tab.code,
                                          brand: brand,
                                        );
                                      },
                                    ),
                                  ),
                                ),

                                // Info box under content
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: brand.withOpacity(0.2)),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.06),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        )
                                      ],
                                    ),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Icon(Icons.info_outline, color: brand.withOpacity(0.9), size: 18),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            '${tabs[_index].code} insights and interactive charts are coming soon.',
                                            style: const TextStyle(
                                              color: brand,
                                              fontWeight: FontWeight.w600,
                                              height: 1.2,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                // Pager dots
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: List.generate(tabs.length, (i) {
                                      final active = i == _index;
                                      return AnimatedContainer(
                                        duration: const Duration(milliseconds: 200),
                                        width: active ? 8 : 6,
                                        height: active ? 8 : 6,
                                        margin: const EdgeInsets.symmetric(horizontal: 4),
                                        decoration: BoxDecoration(
                                          color: active ? brand : brand.withOpacity(0.35),
                                          shape: BoxShape.circle,
                                        ),
                                      );
                                    }),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Right rail
                        _RightRail(
                          label: tabs[_index].label,
                          brand: brand,
                          onDownload: _goDownload,
                          onBack: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Bottom home chip
            const SizedBox(height: 8),
            Container(
              height: 56,
              width: 96,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF003A2A), brand]),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.18),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(Icons.home, color: Colors.white, size: 26),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar();

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: Colors.green.shade300,
          borderRadius: BorderRadius.circular(24),
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
    );
  }
}

class _DownloadButton extends StatelessWidget {
  const _DownloadButton();

  @override
  Widget build(BuildContext context) {
    return Builder(builder: (ctx) {
      return IconButton(
        onPressed: () {
          final state = ctx.findAncestorStateOfType<_InfographicsScreenState>();
          state?._goDownload();
        },
        icon: const Icon(Icons.download_for_offline, color: Colors.white),
        tooltip: 'Download',
      );
    });
  }
}

class _MetricTab {
  final String code;
  final String label;
  const _MetricTab({required this.code, required this.label});
}

class _MetricPanel extends StatelessWidget {
  final String code;
  final Color brand;
  const _MetricPanel({required this.code, required this.brand});

  @override
  Widget build(BuildContext context) {
    // 6 tiles to better fill space
    final tiles = List.generate(6, (i) => _MockChartCard(index: i + 1, brand: brand));

    return Column(
      children: [
        // Header with metric badge and spark icon
        Padding(
          padding: const EdgeInsets.only(bottom: 8, left: 2, right: 2),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: brand.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: brand.withOpacity(0.4)),
                ),
                child: Text(
                  code,
                  style: TextStyle(
                    color: brand,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              const Spacer(),
              Icon(Icons.trending_up, color: brand),
            ],
          ),
        ),

        // Grid of mock charts
        Expanded(
          child: GridView.builder(
            itemCount: tiles.length,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 2),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.05,
            ),
            itemBuilder: (context, i) => tiles[i],
          ),
        ),
      ],
    );
  }
}

class _MockChartCard extends StatelessWidget {
  final int index;
  final Color brand;
  const _MockChartCard({required this.index, required this.brand});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 2.5,
      shadowColor: Colors.black.withOpacity(0.12),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: brand.withOpacity(0.14)),
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(10),
        child: CustomPaint(
          painter: _MockChartPainter(color: brand.withOpacity(0.95)),
          child: Center(
            child: Text(
              'Chart $index',
              style: TextStyle(
                color: brand,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MockChartPainter extends CustomPainter {
  final Color color;
  _MockChartPainter({required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final axis = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = color.withOpacity(0.45);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = color;

    const pad = 10.0;
    final left = pad;
    final bottom = size.height - pad;

    // Axes
    canvas.drawLine(Offset(left, bottom), Offset(size.width - pad, bottom), axis);
    canvas.drawLine(Offset(left, bottom), Offset(left, pad), axis);

    // Line
    final w = size.width - pad * 2;
    final h = size.height - pad * 2;
    final path = Path()
      ..moveTo(left, bottom)
      ..lineTo(left + w * 0.22, bottom - h * 0.42)
      ..lineTo(left + w * 0.38, bottom - h * 0.30)
      ..lineTo(left + w * 0.58, bottom - h * 0.70)
      ..lineTo(left + w * 0.80, bottom - h * 0.52)
      ..lineTo(left + w, bottom - h * 0.86);
    canvas.drawPath(path, p);
  }
  @override
  bool shouldRepaint(covariant _MockChartPainter oldDelegate) => false;
}

class _RightRail extends StatelessWidget {
  final String label;
  final Color brand;
  final VoidCallback onDownload;
  final VoidCallback onBack;
  const _RightRail({
    required this.label,
    required this.brand,
    required this.onDownload,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      margin: const EdgeInsets.only(right: 10),
      child: Column(
        children: [
          const SizedBox(height: 6),
          Material(
            color: Colors.green[200],
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: onDownload,
              child: const SizedBox(
                width: 46,
                height: 46,
                child: Icon(Icons.download, color: Color(0xFF167339)),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.green[200],
                borderRadius: BorderRadius.circular(16),
              ),
              child: RotatedBox(
                quarterTurns: 3,
                child: Center(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF0D3F2C),
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _railRound(icon: Icons.add, brand: brand, onTap: () {}),
          const SizedBox(height: 10),
          _railRound(icon: Icons.remove, brand: brand, onTap: () {}),
          const SizedBox(height: 10),
          Material(
            color: Colors.green[200],
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: onBack,
              child: const SizedBox(
                width: 46,
                height: 58,
                child: Center(
                  child: RotatedBox(
                    quarterTurns: 3,
                    child: Text(
                      'Back',
                      style: TextStyle(
                        color: Color(0xFF0D3F2C),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _railRound({required IconData icon, required Color brand, required VoidCallback onTap}) {
    return Material(
      color: Colors.green[200],
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 38,
          height: 38,
          child: Icon(icon, size: 18, color: brand),
        ),
      ),
    );
  }
}
