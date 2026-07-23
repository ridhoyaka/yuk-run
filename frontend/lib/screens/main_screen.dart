import 'package:flutter/material.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
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

// Public state agar DashboardScreen bisa memanggil navigateTo()
class MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      DashboardScreen(userName: widget.userName),
      const MapScreen(),
      const HistoryScreen(),
      const NewsScreen(),
      ProfileScreen(userName: widget.userName),
    ];
  }

  void _onTabTapped(int index) {
    if (_currentIndex != index) {
      setState(() => _currentIndex = index);
    }
  }

  // Dipanggil dari child widget (DashboardScreen)
  void navigateTo(int index) => _onTabTapped(index);

  @override
  Widget build(BuildContext context) {
    const accentColor = Color(0xFF00FF66);

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
      bottomNavigationBar: CurvedNavigationBar(
        index: _currentIndex,
        height: 60.0,
        items: const <Widget>[
          Icon(Icons.home_rounded, size: 26, color: accentColor),
          Icon(Icons.map_rounded, size: 26, color: accentColor),
          Icon(Icons.history_rounded, size: 26, color: accentColor),
          Icon(Icons.newspaper_rounded, size: 26, color: accentColor),
          Icon(Icons.person_rounded, size: 26, color: accentColor),
        ],
        color: const Color(0xFF1E1E1E),
        backgroundColor: const Color(0xFF121212),
        buttonBackgroundColor: const Color(0xFF1E1E1E),
        animationCurve: Curves.easeInOut,
        animationDuration: const Duration(milliseconds: 400),
        onTap: _onTabTapped,
      ),
    );
  }
}
