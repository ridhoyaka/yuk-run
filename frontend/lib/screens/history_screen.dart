import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../services/api_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  final _storage = const FlutterSecureStorage();

  List<Map<String, dynamic>> _logs = [];
  int _totalSesi = 0;
  double _totalJarak = 0;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
        );
    _animController.forward();
    _fetchLogs();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _fetchLogs() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final token = await _storage.read(key: 'jwt_token');
      if (token == null) return;

      final response = await http
          .get(
            Uri.parse('${ApiService.baseUrl}/logs'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 && mounted) {
        final data = jsonDecode(response.body);
        final summary = data['summary'] as Map<String, dynamic>;
        setState(() {
          _logs = List<Map<String, dynamic>>.from(data['data'] ?? []);
          _totalSesi = summary['total_sesi'] as int? ?? 0;
          _totalJarak = (summary['total_jarak_km'] as num?)?.toDouble() ?? 0;
          _isLoading = false;
        });
      } else {
        if (mounted)
          setState(() {
            _isLoading = false;
            _errorMessage = 'Gagal memuat data riwayat.';
          });
      }
    } catch (e) {
      if (mounted)
        setState(() {
          _isLoading = false;
          _errorMessage = 'Tidak dapat terhubung ke server.';
        });
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '-';
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = now.difference(date);
      if (diff.inDays == 0) return 'Hari ini';
      if (diff.inDays == 1) return 'Kemarin';
      const months = [
        '',
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'Mei',
        'Jun',
        'Jul',
        'Agu',
        'Sep',
        'Okt',
        'Nov',
        'Des',
      ];
      return '${date.day} ${months[date.month]} ${date.year}';
    } catch (_) {
      return dateStr;
    }
  }

  String _formatDuration(int? menit) {
    if (menit == null || menit == 0) return '-';
    if (menit < 60) return '${menit}m';
    final j = menit ~/ 60;
    final m = menit % 60;
    return m == 0 ? '${j}j' : '${j}j ${m}m';
  }

  String _formatPace(double? jarakKm, int? durasiMenit) {
    if (jarakKm == null ||
        jarakKm == 0 ||
        durasiMenit == null ||
        durasiMenit == 0) {
      return '-';
    }
    final pacePerKm = durasiMenit / jarakKm;
    final menit = pacePerKm.floor();
    final detik = ((pacePerKm - menit) * 60).round();
    return "$menit'${detik.toString().padLeft(2, '0')}'' /km";
  }

  @override
  Widget build(BuildContext context) {
    const accentColor = Color(0xFF00FF66);

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Riwayat Aktivitas',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            IconButton(
                              onPressed: _fetchLogs,
                              icon: _isLoading
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        color: accentColor,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.refresh_rounded,
                                      color: Colors.white38,
                                      size: 20,
                                    ),
                              style: IconButton.styleFrom(
                                backgroundColor: const Color(0xFF1E1E1E),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Rekam jejak latihan dan performa lari Anda',
                          style: TextStyle(color: Colors.white54, fontSize: 13),
                        ),
                        const SizedBox(height: 20),

                        // Summary card
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF1E1E1E),
                                accentColor.withValues(alpha: 0.1),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: accentColor.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildSummaryItem(
                                'Total Lari',
                                _isLoading ? '...' : '$_totalSesi Sesi',
                                Icons.directions_run_rounded,
                                accentColor,
                              ),
                              Container(
                                width: 1,
                                height: 35,
                                color: Colors.white12,
                              ),
                              _buildSummaryItem(
                                'Total Jarak',
                                _isLoading
                                    ? '...'
                                    : '${_totalJarak.toStringAsFixed(1)} km',
                                Icons.route_rounded,
                                Colors.blueAccent,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 25),
                        const Text(
                          'Daftar Latihan',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                    ),
                  ),
                ),

                // List riwayat
                if (_isLoading)
                  const SliverFillRemaining(
                    child: Center(
                      child: CircularProgressIndicator(color: accentColor),
                    ),
                  )
                else if (_errorMessage != null)
                  SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.cloud_off_rounded,
                            color: Colors.white24,
                            size: 48,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _errorMessage!,
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextButton.icon(
                            onPressed: _fetchLogs,
                            icon: const Icon(
                              Icons.refresh_rounded,
                              color: accentColor,
                            ),
                            label: const Text(
                              'Coba Lagi',
                              style: TextStyle(color: accentColor),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (_logs.isEmpty)
                  SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.directions_run_rounded,
                            color: Colors.white.withValues(alpha: 0.15),
                            size: 64,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Belum ada riwayat lari',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Mulai berlari dan catat aktivitasmu!',
                            style: TextStyle(
                              color: Colors.white38,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        if (index == _logs.length) {
                          return const SizedBox(height: 100);
                        }
                        final log = _logs[index];
                        final jarak =
                            (log['total_jarak_km'] as num?)?.toDouble() ?? 0;
                        final durasi = log['durasi_menit'] as int?;
                        final start =
                            log['nama_lokasi_start'] as String? ?? '-';
                        final finish =
                            log['nama_lokasi_finish'] as String? ?? '-';
                        final tanggal = _formatDate(
                          log['tanggal_latihan'] as String?,
                        );

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildHistoryCard(
                            date: tanggal,
                            title: '$start → $finish',
                            distance: '${jarak.toStringAsFixed(1)} km',
                            duration: _formatDuration(durasi),
                            pace: _formatPace(jarak, durasi),
                            catatan: log['catatan_kondisi'] as String?,
                            accentColor: accentColor,
                          ),
                        );
                      }, childCount: _logs.length + 1),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryCard({
    required String date,
    required String title,
    required String distance,
    required String duration,
    required String pace,
    required Color accentColor,
    String? catatan,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                date,
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  distance,
                  style: TextStyle(
                    color: accentColor,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (catatan != null && catatan.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              catatan,
              style: const TextStyle(color: Colors.white38, fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 14),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildDetailMetric('Waktu Tempuh', duration),
              _buildDetailMetric('Pace Rata-rata', pace),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.white24,
                size: 14,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailMetric(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 11),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
