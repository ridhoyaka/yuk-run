import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/api_service.dart';
import '../models/user_model.dart';
import 'transition_loading_screen.dart';
import 'register_screen.dart';
import '../widgets/hover_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _storage = const FlutterSecureStorage();

  bool _isLoading = false;
  bool _obscurePassword = true;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
        );

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': _emailController.text,
          'password': _passwordController.text,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final user = User.fromJson(data['user']);
        final token = data['token'];

        await _storage.write(key: 'jwt_token', value: token);
        await _storage.write(key: 'user_name', value: user.nama);
        await _storage.write(key: 'user_email', value: user.email);

        if (!mounted) return;

        // Pindah ke Layar Pemuatan Transisional yang Elegan & Mulus
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                TransitionLoadingScreen(userName: user.nama),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  return FadeTransition(opacity: animation, child: child);
                },
            transitionDuration: const Duration(milliseconds: 400),
          ),
        );
      } else {
        if (!mounted) return;
        _showError('Login gagal: Email atau password salah.');
      }
    } catch (e) {
      if (!mounted) return;
      _showError('Koneksi bermasalah. Periksa jaringan Anda.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const accentColor = Color(0xFF00FF66);

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // === Ikon / Logo Petir (Bersih Tanpa Neon) ===
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00FF66).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: accentColor.withValues(alpha: 0.3),
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.bolt_rounded,
                          size: 50,
                          color: accentColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Selamat Datang Kembali',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Masuk untuk melanjutkan jurnal lari RunNotPace',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Colors.white54),
                    ),

                    const SizedBox(height: 35),

                    // Kartu Form Login (Bersih Tanpa Neon)
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E1E),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Column(
                        children: [
                          TextField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: 'Email',
                              labelStyle: const TextStyle(
                                color: Colors.white54,
                              ),
                              prefixIcon: const Icon(
                                Icons.email_outlined,
                                color: Colors.white54,
                                size: 20,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderSide: const BorderSide(
                                  color: Colors.white12,
                                ),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: const BorderSide(
                                  color: accentColor,
                                ),
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),

                          TextField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: 'Password',
                              labelStyle: const TextStyle(
                                color: Colors.white54,
                              ),
                              prefixIcon: const Icon(
                                Icons.lock_outline,
                                color: Colors.white54,
                                size: 20,
                              ),
                              suffixIcon: HoverButton(
                                builder: (context, progress) => IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                    color: Color.lerp(
                                      Colors.white54,
                                      Colors.white,
                                      progress,
                                    ),
                                    size: 20,
                                  ),
                                  style: IconButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shape: progress > 0.01
                                        ? CircleBorder(
                                            side: BorderSide(
                                              color: Colors.white.withValues(
                                                alpha: progress,
                                              ),
                                              width: 2.0,
                                            ),
                                          )
                                        : null,
                                  ),
                                  onPressed: () {
                                    setState(
                                      () =>
                                          _obscurePassword = !_obscurePassword,
                                    );
                                  },
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderSide: const BorderSide(
                                  color: Colors.white12,
                                ),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: const BorderSide(
                                  color: accentColor,
                                ),
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),

                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: HoverButton(
                              builder: (context, progress) => TextButton(
                                onPressed: () {},
                                style: TextButton.styleFrom(
                                  foregroundColor: Color.lerp(
                                    Colors.white54,
                                    Colors.white,
                                    progress,
                                  ),
                                  backgroundColor: Colors.transparent,
                                  side: progress > 0.01
                                      ? BorderSide(
                                          color: Colors.white.withValues(
                                            alpha: progress,
                                          ),
                                          width: 2.0,
                                        )
                                      : null,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Text(
                                  'Lupa Password?',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 25),

                    // Tombol Login (Bersih Tanpa Neon)
                    SizedBox(
                      height: 55,
                      child: HoverButton(
                        builder: (context, progress) => ElevatedButton(
                          onPressed: _isLoading ? null : _handleLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color.lerp(
                              accentColor,
                              Colors.transparent,
                              progress,
                            ),
                            foregroundColor: Color.lerp(
                              Colors.black,
                              accentColor,
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
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.black,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : Text(
                                  'MASUK',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.5,
                                    color: Color.lerp(
                                      Colors.black,
                                      accentColor,
                                      progress,
                                    ),
                                  ),
                                ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 25),

                    // Navigasi ke Register
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "Belum punya akun?",
                          style: TextStyle(color: Colors.white54, fontSize: 13),
                        ),
                        HoverButton(
                          builder: (context, progress) => TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                PageRouteBuilder(
                                  pageBuilder:
                                      (
                                        context,
                                        animation,
                                        secondaryAnimation,
                                      ) => const RegisterScreen(),
                                  transitionsBuilder:
                                      (
                                        context,
                                        animation,
                                        secondaryAnimation,
                                        child,
                                      ) {
                                        var slideTransition =
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
                                          position: slideTransition,
                                          child: FadeTransition(
                                            opacity: animation,
                                            child: child,
                                          ),
                                        );
                                      },
                                  transitionDuration: const Duration(
                                    milliseconds: 400,
                                  ),
                                ),
                              );
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: Color.lerp(
                                accentColor,
                                Colors.white,
                                progress,
                              ),
                              backgroundColor: Colors.transparent,
                              side: progress > 0.01
                                  ? BorderSide(
                                      color: Colors.white.withValues(
                                        alpha: progress,
                                      ),
                                      width: 2.0,
                                    )
                                  : null,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Text(
                              'Daftar Sekarang',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Color.lerp(
                                  accentColor,
                                  Colors.white,
                                  progress,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
