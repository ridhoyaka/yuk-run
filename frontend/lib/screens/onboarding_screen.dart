import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'login_screen.dart';
import 'main_screen.dart';
import '../widgets/hover_button.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  final _storage = const FlutterSecureStorage();

  int _currentPage = 0;
  double _pageOffset = 0.0;
  bool _isLoading = true;

  final List<Map<String, dynamic>> _slides = [
    {
      'title': 'RACIK RUTE & PACE LARI ANDA',
      'subtitle':
          'Temukan jalur lari terbaik dengan analisis elevasi, rute favorit, dan estimasi waktu yang akurat.',
      'icon': Icons.alt_route_rounded,
      'badge': 'PRESET RUTE',
      'bgColor': const Color(0xFF121212),
      'cardBg': const Color(0xFF1E1E1E),
    },
    {
      'title': 'LATIHAN DENGAN RITME KONSISTEN',
      'subtitle':
          'Pantau statistik mingguan, kalkulasi pace otomatis, dan tingkatkan performa tanpa beban berlebih.',
      'icon': Icons.speed_rounded,
      'badge': 'STATISTIK REALTIME',
      'bgColor': const Color(0xFF0F1B14),
      'cardBg': const Color(0xFF182E22),
    },
    {
      'title': 'GABUNG EVENT & KOMUNITAS',
      'subtitle':
          'Tantang diri Anda di ajang maraton, kumpulkan badge prestasi, dan lari bersama ribuan pelari lainnya.',
      'icon': Icons.emoji_events_rounded,
      'badge': 'EVENT & BADGE',
      'bgColor': const Color(0xFF141923),
      'cardBg': const Color(0xFF1C2433),
    },
  ];

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();

    _pageController.addListener(() {
      setState(() {
        _pageOffset = _pageController.page ?? 0.0;
      });
    });
  }

  Future<void> _checkLoginStatus() async {
    await Future.delayed(const Duration(milliseconds: 800));

    String? token = await _storage.read(key: 'jwt_token');
    String? userName = await _storage.read(key: 'user_name');

    if (!mounted) return;

    if (token != null && token.isNotEmpty) {
      await _storage.write(key: 'is_onboarded', value: 'true');
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              MainScreen(userName: userName ?? 'Pelari'),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 600),
        ),
      );
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _navigateToLogin() async {
    await _storage.write(key: 'is_onboarded', value: 'true');
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const LoginScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          var slideIn =
              Tween<Offset>(
                begin: const Offset(1.0, 0.0),
                end: Offset.zero,
              ).animate(
                CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeInOutCubic,
                ),
              );
          return SlideTransition(
            position: slideIn,
            child: FadeTransition(opacity: animation, child: child),
          );
        },
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const accentColor = Color(0xFF00FF66);

    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF121212),
        body: Center(
          child: CircularProgressIndicator(color: accentColor, strokeWidth: 3),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // === PAGEVIEW UTAMA UNTUK GESTUR SWIPE KANAN/KIRI ===
          PageView.builder(
            controller: _pageController,
            physics: const BouncingScrollPhysics(),
            onPageChanged: (int page) {
              setState(() {
                _currentPage = page;
              });
            },
            itemCount: _slides.length,
            itemBuilder: (context, index) {
              double delta = index - _pageOffset;
              return _buildDynamicSlide(_slides[index], delta, accentColor);
            },
          ),

          // === POSISI BAWAH: INDIKATOR TITIK & TOMBOL MULAI YANG KONSISTEN ===
          Positioned(
            left: 28,
            right: 28,
            bottom: 40,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Titik indikator selalu di posisi yang sama dan pas di bawah teks
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _slides.length,
                    (index) => _buildDotIndicator(index, accentColor),
                  ),
                ),

                // Tombol "MULAI SEKARANG" (Ukuran sedikit dikecilkan dan tidak menumpuk)
                SizedBox(
                  height: _currentPage == _slides.length - 1 ? 65 : 0,
                  child: AnimatedOpacity(
                    opacity: _currentPage == _slides.length - 1 ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 300),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 20),
                      child: SizedBox(
                        width: double.infinity,
                        height: 45,
                        child: HoverButton(
                          builder: (context, progress) => ElevatedButton(
                          onPressed: _currentPage == _slides.length - 1
                              ? _navigateToLogin
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color.lerp(
                              accentColor,
                              Colors.transparent,
                              progress,
                            ),
                            foregroundColor: Color.lerp(Colors.black, accentColor, progress),
                            elevation: 0,
                            side: BorderSide(
                              color: Color.lerp(Colors.transparent, Colors.white, progress)!,
                              width: 2.0,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(22),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'MULAI SEKARANG',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                  color: Color.lerp(Colors.black, accentColor, progress),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Icon(Icons.bolt_rounded, size: 18,
                                color: Color.lerp(Colors.black, accentColor, progress),
                              ),
                            ],
                          ),
                        ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDynamicSlide(
    Map<String, dynamic> slide,
    double delta,
    Color accentColor,
  ) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: slide['bgColor'],
      child: Stack(
        children: [
          Positioned.fill(
            child: Transform.translate(
              offset: Offset(delta * 180, 0),
              child: CustomPaint(
                painter: BackgroundWavePainter(color: slide['cardBg']),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 20),

                // Badge kategori
                Center(
                  child: Transform.translate(
                    offset: Offset(0, delta * 60),
                    child: Opacity(
                      opacity: (1 - delta.abs() * 1.5).clamp(0.0, 1.0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: accentColor.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          slide['badge'],
                          style: TextStyle(
                            color: accentColor,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                // Ilustrasi Utama dengan Animasi 3D Tilt Mikro
                Center(
                  child: Transform(
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.002)
                      ..translateByDouble(delta * -150, 0.0, 0.0, 1.0)
                      ..rotateZ(delta * 0.2)
                      ..scaleByDouble(
                        (1 - delta.abs() * 0.4).clamp(0.6, 1.0),
                        (1 - delta.abs() * 0.4).clamp(0.6, 1.0),
                        (1 - delta.abs() * 0.4).clamp(0.6, 1.0),
                        1.0,
                      ),
                    alignment: Alignment.center,
                    child: Opacity(
                      opacity: (1 - delta.abs() * 1.2).clamp(0.0, 1.0),
                      child: Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          color: slide['cardBg'],
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08),
                            width: 2,
                          ),
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Icon(slide['icon'], size: 80, color: accentColor),
                            Positioned(
                              bottom: 22,
                              child: Container(
                                width: 45,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: accentColor.withValues(alpha: 0.4),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 35),

                // Judul Besar (Rata Tengah)
                Transform.translate(
                  offset: Offset(delta * 250, 0),
                  child: Opacity(
                    opacity: (1 - delta.abs() * 1.5).clamp(0.0, 1.0),
                    child: Text(
                      slide['title'],
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        height: 1.2,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Subtitle (Rata Tengah) dengan tinggi fix agar posisi bawah selalu konsisten
                Transform.translate(
                  offset: Offset(delta * 320, 0),
                  child: Opacity(
                    opacity: (1 - delta.abs() * 1.8).clamp(0.0, 1.0),
                    child: SizedBox(
                      height:
                          55, // Tinggi konsisten agar teks dan indikator tidak naik-turun
                      child: Text(
                        slide['subtitle'],
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),

                // Jarak aman ke bagian bawah tempat indikator berada
                const SizedBox(height: 80),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDotIndicator(int index, Color accentColor) {
    bool isActive = _currentPage == index;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      height: 6,
      width: isActive ? 28 : 8,
      decoration: BoxDecoration(
        color: isActive ? accentColor : Colors.white24,
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}

class BackgroundWavePainter extends CustomPainter {
  final Color color;

  BackgroundWavePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final path = Path();
    path.moveTo(0, size.height * 0.2);
    path.cubicTo(
      size.width * 0.4,
      size.height * 0.15,
      size.width * 0.6,
      size.height * 0.3,
      size.width,
      size.height * 0.25,
    );

    path.moveTo(0, size.height * 0.75);
    path.cubicTo(
      size.width * 0.3,
      size.height * 0.85,
      size.width * 0.7,
      size.height * 0.65,
      size.width,
      size.height * 0.8,
    );

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
