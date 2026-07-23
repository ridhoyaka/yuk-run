import 'package:flutter/material.dart';
import 'dashboard_screen.dart';
import 'map_screen.dart';
import 'history_screen.dart';
import 'news_screen.dart';
import 'profile_screen.dart';

class MainScreen extends StatefulWidget {
  final String userName;
  const MainScreen({super.key, required this.userName});

  @override
  State<MainScreen> createState() => MainScreenState();
}

class MainScreenState extends State<MainScreen> {
  int _currentIndex = 2; // Default buka Dashboard (index 2)
  late final List<Widget> _pages;

  static const _navItems = [
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

  void _onTabTapped(int index) {
    if (_currentIndex != index) setState(() => _currentIndex = index);
  }

  void navigateTo(int index) => _onTabTapped(index);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) =>
            FadeTransition(opacity: animation, child: child),
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

// ─── Data model ──────────────────────────────────────────────────────────────
class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}

// ─── Custom navbar: label selalu tampil di bawah, kotak aktif di atas ikon ───
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
  State<_CustomNavBar> createState() => _CustomNavBarState();
}

class _CustomNavBarState extends State<_CustomNavBar>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _bubbleAnims;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      widget.items.length,
      (i) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 350),
      ),
    );

    _bubbleAnims = _controllers
        .map(
          (c) => Tween<double>(
            begin: 0.0,
            end: 1.0,
          ).animate(CurvedAnimation(parent: c, curve: Curves.easeOutCubic)),
        )
        .toList();

    _controllers[widget.currentIndex].forward();
  }

  @override
  void didUpdateWidget(_CustomNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      _controllers[oldWidget.currentIndex].reverse();
      _controllers[widget.currentIndex].forward();
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) c.dispose();
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
                  onTap: () => widget.onTap(index),
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedBuilder(
                    animation: _controllers[index],
                    builder: (context, _) {
                      final progress = _bubbleAnims[index].value;

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
                                    ? Color.lerp(
                                        Colors.white38,
                                        accentColor,
                                        progress,
                                      )
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
                                      ? Color.lerp(
                                          Colors.white38,
                                          accentColor,
                                          progress,
                                        )!
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
