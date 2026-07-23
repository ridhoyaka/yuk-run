import 'package:flutter/material.dart';

import 'dashboard_screen.dart';
import 'history_screen.dart';
import 'map_screen.dart';
import 'news_screen.dart';
import 'profile_screen.dart';

class MainScreen extends StatefulWidget {
  final String userName;

  const MainScreen({super.key, required this.userName});

  @override
  State<MainScreen> createState() => MainScreenState();
}

class MainScreenState extends State<MainScreen> {
  // Indeks tab:
  // 0 = Riwayat
  // 1 = Peta
  // 2 = Dashboard
  // 3 = Berita
  // 4 = Profil
  int _currentIndex = 2;

  late final List<Widget> _pages;

  static const List<_NavItem> _navItems = [
    _NavItem(icon: Icons.history_rounded, label: 'Riwayat'),
    _NavItem(icon: Icons.map_rounded, label: 'Peta'),
    _NavItem(icon: Icons.home_rounded, label: 'Dashboard'),
    _NavItem(icon: Icons.newspaper_rounded, label: 'Berita'),
    _NavItem(icon: Icons.person_rounded, label: 'Profil'),
  ];

  @override
  void initState() {
    super.initState();

    _pages = [
      const HistoryScreen(),
      const MapScreen(),
      DashboardScreen(userName: widget.userName),
      const NewsScreen(),
      ProfileScreen(userName: widget.userName),
    ];
  }

  // ============================================================
  // NAVIGASI TAB BOTTOM NAVIGATION
  // ============================================================
  void _onTabTapped(int index) {
    if (index < 0 || index >= _pages.length) {
      return;
    }

    // Jika tab yang sedang aktif ditekan kembali.
    if (_currentIndex == index) {
      // Dashboard dibuat ulang supaya data rute favorit
      // dan statistik terbaru dimuat kembali.
      if (index == 2) {
        setState(() {
          _pages[2] = DashboardScreen(
            key: UniqueKey(),
            userName: widget.userName,
          );
        });
      }

      return;
    }

    setState(() {
      // Setiap kembali ke Dashboard, buat ulang halaman
      // agar initState memanggil API terbaru.
      if (index == 2) {
        _pages[2] = DashboardScreen(
          key: UniqueKey(),
          userName: widget.userName,
        );
      }

      _currentIndex = index;
    });
  }

  // Digunakan oleh DashboardScreen dan halaman lain
  // untuk berpindah ke tab tertentu.
  void navigateTo(int index) {
    _onTabTapped(index);
  }

  // ============================================================
  // MEMBUKA RUTE FAVORIT DI PETA
  // ============================================================
  //
  // Fungsi ini menerima seluruh data rute dari Dashboard,
  // kemudian membuat ulang MapScreen dengan initialSavedRoute.
  void openSavedRoute(Map<String, dynamic> route) {
    if (route.isEmpty) {
      return;
    }

    final selectedRoute = Map<String, dynamic>.from(route);

    setState(() {
      _pages[1] = MapScreen(key: UniqueKey(), initialSavedRoute: selectedRoute);

      // Arahkan bottom navigation ke tab Peta.
      _currentIndex = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (Widget child, Animation<double> animation) {
          return FadeTransition(opacity: animation, child: child);
        },
        child: KeyedSubtree(
          key: ValueKey<int>(_currentIndex),
          child: _pages[_currentIndex],
        ),
      ),
      bottomNavigationBar: _CustomNavBar(
        currentIndex: _currentIndex,
        items: _navItems,
        onTap: _onTabTapped,
      ),
    );
  }
}

// ============================================================
// DATA MODEL NAVIGATION
// ============================================================
class _NavItem {
  final IconData icon;
  final String label;

  const _NavItem({required this.icon, required this.label});
}

// ============================================================
// CUSTOM BOTTOM NAVIGATION BAR
// ============================================================
//
// Menggunakan satu indikator hijau yang bergerak secara horizontal.
// Indikator tidak dibuat ulang pada setiap menu sehingga perpindahan
// terlihat seperti bergeser, bukan berkedip.
//
class _CustomNavBar extends StatelessWidget {
  final int currentIndex;
  final List<_NavItem> items;
  final ValueChanged<int> onTap;

  const _CustomNavBar({
    required this.currentIndex,
    required this.items,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const accentColor = Color(0xFF00FF66);

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
        border: Border(top: BorderSide(color: Colors.white12, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black45,
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 68,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final itemWidth = constraints.maxWidth / items.length;

              // Menyesuaikan lebar indikator pada layar kecil.
              final indicatorWidth = itemWidth >= 76 ? 68.0 : itemWidth - 8;

              final indicatorLeft =
                  (currentIndex * itemWidth) +
                  ((itemWidth - indicatorWidth) / 2);

              return Stack(
                alignment: Alignment.centerLeft,
                children: [
                  // ==================================================
                  // INDIKATOR HIJAU YANG BERGESER
                  // ==================================================
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 450),
                    curve: Curves.easeInOutCubic,
                    left: indicatorLeft,
                    top: 5.5,
                    width: indicatorWidth,
                    height: 57,
                    child: Container(
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: accentColor.withValues(alpha: 0.45),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: accentColor.withValues(alpha: 0.10),
                            blurRadius: 12,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ==================================================
                  // DAFTAR MENU NAVIGASI
                  // ==================================================
                  Row(
                    children: List.generate(items.length, (index) {
                      final item = items[index];
                      final isSelected = currentIndex == index;

                      return Expanded(
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => onTap(index),
                            splashColor: Colors.transparent,
                            highlightColor: Colors.transparent,
                            hoverColor: Colors.transparent,
                            focusColor: Colors.transparent,
                            overlayColor: WidgetStatePropertyAll<Color>(
                              Colors.transparent,
                            ),
                            child: SizedBox(
                              height: 68,
                              child: TweenAnimationBuilder<double>(
                                tween: Tween<double>(
                                  begin: 0,
                                  end: isSelected ? 1 : 0,
                                ),
                                duration: const Duration(milliseconds: 350),
                                curve: Curves.easeInOutCubic,
                                builder: (context, progress, child) {
                                  final itemColor = Color.lerp(
                                    Colors.white38,
                                    accentColor,
                                    progress,
                                  )!;

                                  final scale = 1 + (0.08 * progress);

                                  return Transform.scale(
                                    scale: scale,
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          item.icon,
                                          size: 22,
                                          color: itemColor,
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          item.label,
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: isSelected
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                            color: itemColor,
                                            letterSpacing: 0.2 * progress,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
