import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class NewsScreen extends StatefulWidget {
  const NewsScreen({super.key});

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  List<Map<String, dynamic>> _articles = [];
  bool _isLoading = true;
  String? _errorMessage;

  // Kategori filter
  final List<String> _categories = [
    'Semua',
    'Lari',
    'Kesehatan',
    'Nutrisi',
    'Kebugaran',
  ];
  int _selectedCategory = 0;

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
    _fetchNews();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _fetchNews() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // Kirim index kategori ke backend, query ditentukan di sisi server
    const apiBase = 'http://localhost:3000/api';
    final url = '$apiBase/news?category=$_selectedCategory';

    try {
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final articles = List<Map<String, dynamic>>.from(
          data['articles'] ?? [],
        );

        if (mounted) {
          setState(() {
            _articles = articles;
            _isLoading = false;
          });
        }
      } else if (response.statusCode == 429) {
        if (mounted) {
          setState(() {
            _articles = _getFallbackArticles();
            _isLoading = false;
            _errorMessage =
                'Batas harian API tercapai. Menampilkan berita tersimpan.';
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _articles = _getFallbackArticles();
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _articles = _getFallbackArticles();
          _isLoading = false;
          _errorMessage = 'Menampilkan berita tersimpan (offline mode)';
        });
      }
    }
  }

  List<Map<String, dynamic>> _getFallbackArticles() {
    return [
      {
        'title': '5 Manfaat Lari Pagi yang Perlu Kamu Tahu',
        'description':
            'Lari pagi bukan sekadar olahraga. Ada banyak manfaat yang bisa kamu rasakan mulai dari meningkatkan mood hingga menjaga kesehatan jantung.',
        'source': {'name': 'Halodoc'},
        'publishedAt': '2026-07-20T06:00:00Z',
        'url':
            'https://www.halodoc.com/artikel/manfaat-olahraga-lari-bagi-kesehatan',
        'image': null,
      },
      {
        'title': 'Tips Nutrisi Sebelum Maraton: Apa yang Harus Dimakan?',
        'description':
            'Asupan makanan yang tepat sebelum berlari jauh sangat menentukan performa dan daya tahan tubuh kamu selama lomba.',
        'source': {'name': 'Alodokter'},
        'publishedAt': '2026-07-19T08:00:00Z',
        'url': 'https://www.alodokter.com/makanan-sebelum-olahraga',
        'image': null,
      },
      {
        'title': 'Cara Menghindari Cedera Lutut Saat Lari',
        'description':
            'Cedera lutut adalah keluhan paling umum para pelari. Simak cara pencegahannya agar latihan tetap konsisten.',
        'source': {'name': 'KlikDokter'},
        'publishedAt': '2026-07-18T07:30:00Z',
        'url':
            'https://www.klikdokter.com/olahraga/olahraga-lainnya/tips-mencegah-cedera-saat-lari',
        'image': null,
      },
      {
        'title': 'Berapa Jarak Ideal Lari untuk Pemula?',
        'description':
            'Bagi kamu yang baru mulai berlari, menentukan jarak yang tepat sangat penting agar tidak overtraining dan tetap termotivasi.',
        'source': {'name': 'Alodokter'},
        'publishedAt': '2026-07-17T09:00:00Z',
        'url': 'https://www.alodokter.com/olahraga-lari-bagi-pemula',
        'image': null,
      },
      {
        'title': 'Pentingnya Pemanasan Sebelum Mulai Berlari',
        'description':
            'Banyak pelari melewatkan pemanasan. Padahal rutinitas ini sangat penting untuk mencegah cedera dan meningkatkan performa.',
        'source': {'name': 'Halodoc'},
        'publishedAt': '2026-07-16T06:45:00Z',
        'url':
            'https://www.halodoc.com/artikel/gerakan-pemanasan-sebelum-olahraga',
        'image': null,
      },
    ];
  }

  Future<void> _openArticle(String? url) async {
    if (url == null || url.isEmpty) return;
    try {
      final uri = Uri.parse(url);
      // platformDefault: buka di browser bawaan, works di Android, iOS, dan Web
      await launchUrl(uri, mode: LaunchMode.platformDefault);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Tidak dapat membuka artikel'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = now.difference(date);
      if (diff.inDays == 0) return 'Hari ini';
      if (diff.inDays == 1) return 'Kemarin';
      if (diff.inDays < 7) return '${diff.inDays} hari lalu';
      return '${date.day}/${date.month}/${date.year}';
    } catch (_) {
      return '';
    }
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Berita Kesehatan',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tips lari & kesehatan terkini',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: _fetchNews,
                        icon: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: accentColor,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                Icons.refresh_rounded,
                                color: Colors.white70,
                              ),
                        style: IconButton.styleFrom(
                          backgroundColor: const Color(0xFF1E1E1E),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Offline/error banner
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.orange.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.wifi_off_rounded,
                            color: Colors.orange,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(
                                color: Colors.orange,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Filter kategori
                SizedBox(
                  height: 44,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    itemCount: _categories.length,
                    itemBuilder: (context, index) {
                      final isSelected = _selectedCategory == index;
                      return GestureDetector(
                        onTap: () {
                          setState(() => _selectedCategory = index);
                          _fetchNews();
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(right: 10),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? accentColor
                                : const Color(0xFF1E1E1E),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected ? accentColor : Colors.white12,
                            ),
                          ),
                          child: Text(
                            _categories[index],
                            style: TextStyle(
                              color: isSelected ? Colors.black : Colors.white70,
                              fontSize: 12,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 16),

                // Konten berita
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(color: accentColor),
                        )
                      : _articles.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.article_outlined,
                                color: Colors.white24,
                                size: 48,
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Belum ada berita tersedia',
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextButton.icon(
                                onPressed: _fetchNews,
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
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                          itemCount: _articles.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 14),
                          itemBuilder: (context, index) {
                            final article = _articles[index];
                            return _buildNewsCard(article, accentColor);
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNewsCard(Map<String, dynamic> article, Color accentColor) {
    final title = article['title'] as String? ?? 'Tanpa Judul';
    final description = article['description'] as String? ?? '';
    final sourceName =
        (article['source'] as Map?)?['name'] as String? ??
        'Sumber tidak diketahui';
    final publishedAt = _formatDate(article['publishedAt'] as String?);
    final url = article['url'] as String?;
    final imageUrl = article['image'] as String?;

    return GestureDetector(
      onTap: () => _openArticle(url),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Gambar artikel (jika ada)
            if (imageUrl != null)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                child: Image.network(
                  imageUrl,
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) =>
                      _buildImagePlaceholder(accentColor),
                ),
              )
            else
              _buildImagePlaceholder(accentColor),

            // Konten teks
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sumber & tanggal
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          sourceName,
                          style: TextStyle(
                            color: accentColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        publishedAt,
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Judul
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      description,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 13,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],

                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        'Baca selengkapnya',
                        style: TextStyle(
                          color: accentColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward_rounded,
                        color: accentColor,
                        size: 14,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePlaceholder(Color accentColor) {
    return Container(
      height: 120,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2C),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Center(
        child: Icon(
          Icons.article_rounded,
          color: accentColor.withValues(alpha: 0.3),
          size: 40,
        ),
      ),
    );
  }
}
