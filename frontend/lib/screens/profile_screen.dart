import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'login_screen.dart';
import '../widgets/hover_button.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

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
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _handleLogout(BuildContext context) async {
    const storage = FlutterSecureStorage();
    await storage.delete(key: 'jwt_token');
    await storage.delete(key: 'user_name');

    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Keluar Akun',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'Apakah Anda yakin ingin keluar dari aplikasi RunNotPace?',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            HoverButton(
              builder: (context, progress) => TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                foregroundColor: Color.lerp(Colors.white54, Colors.white, progress),
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
              child: const Text('Batal'),
            ),
            ),
            HoverButton(
              builder: (context, progress) => TextButton(
              onPressed: () {
                Navigator.pop(context);
                _handleLogout(context);
              },
              style: TextButton.styleFrom(
                foregroundColor: Color.lerp(Colors.redAccent, const Color(0xFF00FF66), progress),
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
              child: Text(
                'Keluar',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color.lerp(Colors.redAccent, const Color(0xFF00FF66), progress),
                ),
              ),
            ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    const accentColor = Color(0xFF00FF66); // Hijau Neon Awal

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
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Profil Pengguna',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF1E1E1E),
                                accentColor.withValues(alpha: 0.1),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: accentColor.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: accentColor,
                                    width: 2,
                                  ),
                                ),
                                child: const CircleAvatar(
                                  radius: 40,
                                  backgroundColor: Color(0xFF2C2C2C),
                                  child: Icon(
                                    Icons.person_rounded,
                                    size: 40,
                                    color: accentColor,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 15),
                              const Text(
                                'Pelari RunNotPace',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'pelari.aktif@runnotpace.com',
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 20),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
                                children: [
                                  _buildProfileStat('Jarak Total', '142.5 km'),
                                  Container(
                                    width: 1,
                                    height: 25,
                                    color: Colors.white12,
                                  ),
                                  _buildProfileStat('Sesi Lari', '28 Sesi'),
                                  Container(
                                    width: 1,
                                    height: 25,
                                    color: Colors.white12,
                                  ),
                                  _buildProfileStat('Pencapaian', '12 Badge'),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 25),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Pengaturan Akun',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E1E),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                        child: Column(
                          children: [
                            _buildMenuTile(
                              Icons.person_outline_rounded,
                              'Edit Profil',
                              () {},
                            ),
                            const Divider(color: Colors.white12, height: 1),
                            _buildMenuTile(
                              Icons.notifications_outlined,
                              'Pengaturan Notifikasi',
                              () {},
                            ),
                            const Divider(color: Colors.white12, height: 1),
                            _buildMenuTile(
                              Icons.security_rounded,
                              'Keamanan & Sandi',
                              () {},
                            ),
                            const Divider(color: Colors.white12, height: 1),
                            _buildMenuTile(
                              Icons.help_outline_rounded,
                              'Pusat Bantuan',
                              () {},
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 25),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: HoverButton(
                          builder: (context, progress) => OutlinedButton.icon(
                          onPressed: () => _showLogoutDialog(context),
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            backgroundColor: Color.lerp(
                              Colors.redAccent.withValues(alpha: 0.05),
                              Colors.transparent,
                              progress,
                            )!,
                            side: BorderSide(
                              color: Color.lerp(Colors.transparent, Colors.white, progress)!,
                              width: 2.0,
                            ),
                          ),
                          icon: Icon(
                            Icons.logout_rounded,
                            color: Color.lerp(Colors.redAccent, accentColor, progress),
                            size: 20,
                          ),
                          label: Text(
                            'KELUAR AKUN (LOGOUT)',
                            style: TextStyle(
                              color: Color.lerp(Colors.redAccent, accentColor, progress),
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                        ),
                      ),
                      const SizedBox(height: 100),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildMenuTile(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF2C2C2C),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: Colors.white70, size: 18),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: const Icon(
        Icons.arrow_forward_ios_rounded,
        color: Colors.white24,
        size: 14,
      ),
      onTap: onTap,
    );
  }
}