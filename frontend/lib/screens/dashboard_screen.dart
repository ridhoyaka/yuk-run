import 'package:flutter/material.dart';
import '../widgets/hover_button.dart';
import 'main_screen.dart';

class DashboardScreen extends StatelessWidget {
  final String userName;

  const DashboardScreen({super.key, required this.userName});

  void _navigateToTab(BuildContext context, int tabIndex) {
    final state = context.findAncestorStateOfType<MainScreenState>();
    state?.navigateTo(tabIndex);
  }

  @override
  Widget build(BuildContext context) {
    const accentColor = Color(0xFF00FF66);

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Selamat Datang,',
                        style: TextStyle(color: Colors.white54, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        userName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0x1FFFFFFF)),
                    ),
                    child: const Icon(
                      Icons.notifications_outlined,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 25),

              // Card Rencanakan Jalur Lari
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF1E1E1E),
                      accentColor.withValues(alpha: 0.15),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: accentColor.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.map_rounded, color: accentColor, size: 24),
                        SizedBox(width: 10),
                        Text(
                          'Rencanakan Jalur Lari',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Pilih titik awal dan akhir, temukan rute terbaikmu hari ini.',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 15),
                    SizedBox(
                      width: double.infinity,
                      height: 45,
                      child: HoverButton(
                        builder: (context, progress) => ElevatedButton.icon(
                          // Navigasi ke tab Map (index 1)
                          onPressed: () => _navigateToTab(context, 1),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color.lerp(
                              accentColor,
                              Colors.transparent,
                              progress,
                            ),
                            foregroundColor: Color.lerp(
                              Colors.black,
                              Colors.white,
                              progress,
                            ),
                            elevation: 0,
                            side: BorderSide(
                              color: Color.lerp(
                                Colors.transparent,
                                Colors.white,
                                progress,
                              )!,
                              width: 2.0,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: Icon(
                            Icons.search_rounded,
                            size: 18,
                            color: Color.lerp(
                              Colors.black,
                              Colors.white,
                              progress,
                            ),
                          ),
                          label: Text(
                            'CARI RUTE SEKARANG',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              letterSpacing: 1,
                              color: Color.lerp(
                                Colors.black,
                                Colors.white,
                                progress,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // Statistik
              const Text(
                'Statistik Minggu Ini',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      'Total Jarak',
                      '12.5 km',
                      Icons.route_rounded,
                      accentColor,
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: _buildStatCard(
                      'Waktu Tempuh',
                      '1j 15m',
                      Icons.timer_outlined,
                      Colors.blueAccent,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 30),

              // Rute Favorit Tersimpan
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Rute Favorit Tersimpan',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  HoverButton(
                    builder: (context, progress) => TextButton(
                      // Navigasi ke tab History (index 2)
                      onPressed: () => _navigateToTab(context, 2),
                      style: TextButton.styleFrom(
                        foregroundColor: Color.lerp(
                          accentColor,
                          Colors.white,
                          progress,
                        ),
                        backgroundColor: Colors.transparent,
                        side: progress > 0.01
                            ? BorderSide(
                                color: Colors.white.withValues(alpha: progress),
                                width: 2.0,
                              )
                            : null,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Lihat Semua'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              _buildFavoriteRouteCard(
                context,
                'Loop Stadion GBK',
                '4.2 km • Senayan',
                Icons.directions_run,
                accentColor,
              ),
              const SizedBox(height: 12),
              _buildFavoriteRouteCard(
                context,
                'Jalur Hijau Sudirman',
                '6.8 km • Sudirman',
                Icons.park_rounded,
                const Color(0xFF00FF66),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFavoriteRouteCard(
    BuildContext context,
    String routeName,
    String details,
    IconData icon,
    Color accentColor,
  ) {
    return GestureDetector(
      // Tap pada kartu rute → navigasi ke tab Map
      onTap: () => _navigateToTab(context, 1),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF2C2C2C),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: accentColor, size: 22),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    routeName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    details,
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.white24,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}
