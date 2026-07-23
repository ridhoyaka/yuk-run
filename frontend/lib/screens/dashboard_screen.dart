import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../services/api_service.dart';
import '../widgets/hover_button.dart';
import 'main_screen.dart';

class DashboardScreen extends StatefulWidget {
  final String userName;

  const DashboardScreen({super.key, required this.userName});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  static const Color _accentColor = Color(0xFF00FF66);

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // Statistik mingguan.
  double _totalJarak = 0;
  String _durasiLabel = '0m';
  bool _statsLoading = true;

  // Rute favorit.
  List<Map<String, dynamic>> _routes = [];
  bool _routesLoading = true;
  String? _routesError;

  // false = maksimal 3 rute
  // true = tampilkan seluruh rute
  bool _showAllRoutes = false;

  @override
  void initState() {
    super.initState();

    _fetchWeeklyStats();
    _fetchRoutes();
  }

  // ============================================================
  // MENGAMBIL STATISTIK MINGGUAN
  // ============================================================
  Future<void> _fetchWeeklyStats() async {
    if (mounted) {
      setState(() {
        _statsLoading = true;
      });
    }

    try {
      final token = await _storage.read(key: 'jwt_token');

      if (token == null || token.trim().isEmpty) {
        if (!mounted) return;

        setState(() {
          _totalJarak = 0;
          _durasiLabel = '0m';
          _statsLoading = false;
        });

        return;
      }

      final response = await http
          .get(
            Uri.parse('${ApiService.baseUrl}/stats/weekly'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        if (decoded is Map<String, dynamic>) {
          final totalJarak =
              double.tryParse(decoded['total_jarak_km']?.toString() ?? '') ?? 0;

          final durasiLabel = decoded['durasi_label']?.toString() ?? '0m';

          setState(() {
            _totalJarak = totalJarak;
            _durasiLabel = durasiLabel;
            _statsLoading = false;
          });

          return;
        }
      }

      setState(() {
        _totalJarak = 0;
        _durasiLabel = '0m';
        _statsLoading = false;
      });
    } catch (error) {
      debugPrint('Dashboard weekly stats error: $error');

      if (!mounted) return;

      setState(() {
        _totalJarak = 0;
        _durasiLabel = '0m';
        _statsLoading = false;
      });
    }
  }

  // ============================================================
  // MENGAMBIL RUTE FAVORIT DARI DATABASE
  // ============================================================
  Future<void> _fetchRoutes() async {
    if (!mounted) return;

    setState(() {
      _routesLoading = true;
      _routesError = null;
    });

    try {
      final result = await ApiService.getSavedRoutes();

      debugPrint('HASIL GET RUTE FAVORIT: $result');

      if (!mounted) return;

      if (result['success'] == true) {
        final rawRoutes = result['routes'];

        final parsedRoutes = <Map<String, dynamic>>[];

        if (rawRoutes is List) {
          for (final item in rawRoutes) {
            if (item is Map<String, dynamic>) {
              parsedRoutes.add(item);
            } else if (item is Map) {
              parsedRoutes.add(Map<String, dynamic>.from(item));
            }
          }
        }

        setState(() {
          _routes = parsedRoutes;
          _routesLoading = false;
          _routesError = null;

          // Matikan mode "Lihat Semua" jika jumlah rute
          // setelah refresh tidak lebih dari tiga.
          if (_routes.length <= 3) {
            _showAllRoutes = false;
          }
        });

        debugPrint(
          'TOTAL RUTE FAVORIT DASHBOARD: '
          '${parsedRoutes.length}',
        );

        return;
      }

      setState(() {
        _routes = [];
        _routesLoading = false;
        _routesError =
            result['message']?.toString() ?? 'Gagal mengambil rute favorit.';
      });
    } catch (error, stackTrace) {
      debugPrint('Dashboard routes error: $error');

      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      setState(() {
        _routes = [];
        _routesLoading = false;
        _routesError =
            'Gagal memuat rute favorit: '
            '$error';
      });
    }
  }

  // ============================================================
  // NAVIGASI TAB UTAMA
  // ============================================================
  //
  // Index:
  // 0 = Riwayat
  // 1 = Peta
  // 2 = Dashboard
  // 3 = Berita
  // 4 = Profil
  void _navigateToTab(BuildContext context, int tabIndex) {
    final mainScreenState = context.findAncestorStateOfType<MainScreenState>();

    mainScreenState?.navigateTo(tabIndex);
  }

  // Membuka rute favorit terpilih dan mengirim seluruh data rute
  // ke MapScreen melalui MainScreenState.
  void _openSavedRoute(BuildContext context, Map<String, dynamic> route) {
    final mainScreenState = context.findAncestorStateOfType<MainScreenState>();

    if (mainScreenState == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Halaman peta tidak dapat dibuka.'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    mainScreenState.openSavedRoute(Map<String, dynamic>.from(route));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: RefreshIndicator(
          color: _accentColor,
          backgroundColor: const Color(0xFF1E1E1E),
          onRefresh: () async {
            await Future.wait([_fetchWeeklyStats(), _fetchRoutes()]);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ==================================================
                // HEADER
                // ==================================================
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
                    GestureDetector(
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Row(
                              children: [
                                Icon(
                                  Icons.notifications_active_rounded,
                                  color: Colors.black,
                                  size: 18,
                                ),
                                SizedBox(width: 10),
                                Text(
                                  'Tidak ada notifikasi baru',
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            backgroundColor: _accentColor,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                      child: Container(
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
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // ==================================================
                // HERO BANNER
                // ==================================================
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 160,
                        child: Image.asset(
                          'assets/images/dashboard.jpeg',
                          fit: BoxFit.cover,
                          alignment: Alignment.center,
                        ),
                      ),
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

                // ==================================================
                // RENCANAKAN JALUR LARI
                // ==================================================
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF1E1E1E),
                        _accentColor.withValues(alpha: 0.15),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _accentColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.map_rounded,
                            color: _accentColor,
                            size: 24,
                          ),
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
                        'Pilih titik awal dan akhir, '
                        'temukan rute terbaikmu hari ini.',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      const SizedBox(height: 15),
                      SizedBox(
                        width: double.infinity,
                        height: 45,
                        child: HoverButton(
                          builder: (context, progress) => ElevatedButton.icon(
                            onPressed: () => _navigateToTab(context, 1),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color.lerp(
                                _accentColor,
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
                                width: 2,
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

                // ==================================================
                // STATISTIK MINGGU INI
                // ==================================================
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
                          color: _accentColor,
                          strokeWidth: 2,
                        ),
                      )
                    else
                      IconButton(
                        tooltip: 'Muat ulang statistik',
                        onPressed: _fetchWeeklyStats,
                        icon: const Icon(
                          Icons.refresh_rounded,
                          color: Colors.white38,
                          size: 19,
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        title: 'Total Jarak',
                        value: _statsLoading
                            ? '...'
                            : '${_totalJarak.toStringAsFixed(1)} km',
                        icon: Icons.route_rounded,
                        color: _accentColor,
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: _buildStatCard(
                        title: 'Waktu Tempuh',
                        value: _statsLoading ? '...' : _durasiLabel,
                        icon: Icons.timer_outlined,
                        color: Colors.blueAccent,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 30),

                // ==================================================
                // RUTE FAVORIT TERSIMPAN
                // ==================================================
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Text(
                        'Rute Favorit Tersimpan',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Tombol refresh tetap dipertahankan.
                        IconButton(
                          tooltip: 'Muat ulang rute favorit',
                          onPressed: _routesLoading ? null : _fetchRoutes,
                          icon: Icon(
                            Icons.refresh_rounded,
                            color: _routesLoading
                                ? Colors.white24
                                : Colors.white54,
                            size: 20,
                          ),
                        ),

                        // Tombol hanya muncul jika jumlah rute lebih dari tiga.
                        if (!_routesLoading &&
                            _routesError == null &&
                            _routes.length > 3)
                          HoverButton(
                            builder: (context, progress) {
                              final foregroundColor = Color.lerp(
                                _accentColor,
                                Colors.white,
                                progress,
                              )!;

                              return TextButton(
                                onPressed: () {
                                  setState(() {
                                    _showAllRoutes = !_showAllRoutes;
                                  });
                                },
                                style: TextButton.styleFrom(
                                  foregroundColor: foregroundColor,
                                  backgroundColor: Colors.transparent,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                  side: progress > 0.01
                                      ? BorderSide(
                                          color: Colors.white.withValues(
                                            alpha: progress,
                                          ),
                                          width: 1.5,
                                        )
                                      : null,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: Text(
                                  _showAllRoutes
                                      ? 'Tampilkan Sedikit'
                                      : 'Lihat Semua',
                                  style: TextStyle(
                                    color: foregroundColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // ==================================================
                // KONDISI LOADING RUTE
                // ==================================================
                if (_routesLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: CircularProgressIndicator(
                        color: _accentColor,
                        strokeWidth: 2,
                      ),
                    ),
                  )
                // ==================================================
                // KONDISI ERROR RUTE
                // ==================================================
                else if (_routesError != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.redAccent.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          color: Colors.redAccent,
                          size: 32,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _routesError!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextButton.icon(
                          onPressed: _fetchRoutes,
                          icon: const Icon(
                            Icons.refresh_rounded,
                            color: _accentColor,
                          ),
                          label: const Text(
                            'COBA LAGI',
                            style: TextStyle(
                              color: _accentColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                // ==================================================
                // KONDISI BELUM ADA RUTE
                // ==================================================
                else if (_routes.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.route_rounded,
                          color: Colors.white.withValues(alpha: 0.15),
                          size: 36,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Belum ada rute tersimpan',
                          style: TextStyle(color: Colors.white38, fontSize: 13),
                        ),
                        const SizedBox(height: 6),
                        GestureDetector(
                          onTap: () => _navigateToTab(context, 1),
                          child: const Text(
                            'Buat rute pertamamu →',
                            style: TextStyle(
                              color: _accentColor,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                // ==================================================
                // DAFTAR RUTE FAVORIT
                // ==================================================
                else
                  ...List.generate(
                    _showAllRoutes
                        ? _routes.length
                        : (_routes.length > 3 ? 3 : _routes.length),
                    (index) {
                      final route = _routes[index];

                      final start = route['nama_lokasi_start']
                          ?.toString()
                          .trim();

                      final finish = route['nama_lokasi_finish']
                          ?.toString()
                          .trim();

                      final distanceKm =
                          double.tryParse(
                            route['total_jarak_km']?.toString() ?? '',
                          ) ??
                          0;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildFavoriteRouteCard(
                          routeName:
                              '${start == null || start.isEmpty ? 'Lokasi Saya' : start}'
                              ' → '
                              '${finish == null || finish.isEmpty ? 'Tujuan' : finish}',
                          details: '${distanceKm.toStringAsFixed(2)} km',
                          icon: Icons.directions_run_rounded,
                          accentColor: _accentColor,
                          onTap: () {
                            _openSavedRoute(context, route);
                          },
                        ),
                      );
                    },
                  ),

                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // CARD STATISTIK
  // ============================================================
  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
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

  // ============================================================
  // CARD RUTE FAVORIT
  // ============================================================
  Widget _buildFavoriteRouteCard({
    required String routeName,
    required String details,
    required IconData icon,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
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
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
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
