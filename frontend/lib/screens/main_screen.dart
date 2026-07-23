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
class _CustomNavBar extends StatefulWidget {
  final int currentIndex;
  final List<_NavItem> items;
  final ValueChanged<int> onTap;

  const _CustomNavBar({
    required this.currentIndex,
    required this.items,
    required this.onTap,
  });

  @override
  State<_CustomNavBar> createState() {
    return _CustomNavBarState();
  }
}

class _CustomNavBarState extends State<_CustomNavBar>
    with TickerProviderStateMixin {
  late final List<AnimationController> _controllers;
  late final List<Animation<double>> _bubbleAnimations;

  @override
  void initState() {
    super.initState();

    _controllers = List.generate(widget.items.length, (index) {
      return AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 350),
      );
    });

    _bubbleAnimations = _controllers.map((controller) {
      return Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: controller, curve: Curves.easeOutCubic),
      );
    }).toList();

    if (widget.currentIndex >= 0 && widget.currentIndex < _controllers.length) {
      _controllers[widget.currentIndex].forward();
    }
  }

  @override
  void didUpdateWidget(covariant _CustomNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.currentIndex == widget.currentIndex) {
      return;
    }

    if (oldWidget.currentIndex >= 0 &&
        oldWidget.currentIndex < _controllers.length) {
      _controllers[oldWidget.currentIndex].reverse();
    }

    if (widget.currentIndex >= 0 && widget.currentIndex < _controllers.length) {
      _controllers[widget.currentIndex].forward();
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }

    super.dispose();
  }

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
          child: Row(
            children: List.generate(widget.items.length, (index) {
              final item = widget.items[index];
              final isSelected = widget.currentIndex == index;

              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    widget.onTap(index);
                  },
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedBuilder(
                    animation: _controllers[index],
                    builder: (BuildContext context, Widget? child) {
                      final progress = _bubbleAnimations[index].value;

                      final selectedColor = Color.lerp(
                        Colors.white38,
                        accentColor,
                        progress,
                      );

                      return Center(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutCubic,
                          width: 68,
                          height: 57,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? accentColor.withValues(alpha: 0.18 * progress)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(14),
                            border: isSelected
                                ? Border.all(
                                    color: accentColor.withValues(
                                      alpha: 0.4 * progress,
                                    ),
                                    width: 1.5,
                                  )
                                : null,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                item.icon,
                                size: 22,
                                color: isSelected
                                    ? selectedColor
                                    : Colors.white38,
                              ),
                              const SizedBox(height: 3),
                              Text(
                                item.label,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: isSelected
                                      ? selectedColor
                                      : Colors.white38,
                                  letterSpacing: isSelected ? 0.2 : 0,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
