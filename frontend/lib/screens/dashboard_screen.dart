import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../widgets/hover_button.dart';
import '../services/api_service.dart';
import 'main_screen.dart';

class DashboardScreen extends StatefulWidget {
  final String userName;
  const DashboardScreen({super.key, required this.userName});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _storage = const FlutterSecureStorage();

  double _totalJarak = 0;
  String _durasiLabel = '0m';
  bool _statsLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchWeeklyStats();
  }

  Future<void> _fetchWeeklyStats() async {
    if (mounted) setState(() => _statsLoading = true);
    try {
      final token = await _storage.read(key: 'jwt_token');
      if (token == null) return;

      final response = await http
          .get(
            Uri.parse('${ApiService.baseUrl}/stats/weekly'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 && mounted) {
        final data = jsonDecode(response.body);
        setState(() {
          _totalJarak = (data['total_jarak_km'] as num).toDouble();
          _durasiLabel = data['durasi_label'] as String? ?? '0m';
          _statsLoading = false;
        });
      } else {
        if (mounted) setState(() => _statsLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _statsLoading = false);
    }
  }

  // Tab index: 0=Riwayat, 1=Peta, 2=Dashboard, 3=Berita, 4=Profil
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
                        widget.userName,
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
              const SizedBox(height: 20),

              // Hero Banner — gambar dashboard.jpeg
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  children: [
                    // Gambar
                    SizedBox(
                      width: double.infinity,
                      height: 160,
                      child: Image.asset(
                        'assets/images/dashboard.jpeg',
                        fit: BoxFit.cover,
                        alignment: Alignment.center,
                      ),
                    ),
                    // Overlay gradasi gelap agar teks terbaca
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.black.withValues(alpha: 0.6),
                              Colors.transparent,
                            ],
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                          ),
                        ),
                      ),
                    ),
                    // Teks di atas gambar
                    Positioned(
                      bottom: 14,
                      left: 16,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Siap Berlari Hari Ini?',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Temukan rute terbaikmu sekarang',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

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
                          onPressed: () => _navigateToTab(context, 1), // Peta
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

              // Statistik Minggu Ini
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Statistik Minggu Ini',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_statsLoading)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        color: accentColor,
                        strokeWidth: 2,
                      ),
                    )
                  else
                    GestureDetector(
                      onTap: _fetchWeeklyStats,
                      child: const Icon(
                        Icons.refresh_rounded,
                        color: Colors.white38,
                        size: 18,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      'Total Jarak',
                      _statsLoading
                          ? '...'
                          : '${_totalJarak.toStringAsFixed(1)} km',
                      Icons.route_rounded,
                      accentColor,
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: _buildStatCard(
                      'Waktu Tempuh',
                      _statsLoading ? '...' : _durasiLabel,
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
                      onPressed: () => _navigateToTab(context, 0), // Riwayat
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
                accentColor,
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
      onTap: () => _navigateToTab(context, 1), // Peta
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
