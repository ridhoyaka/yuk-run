import 'package:flutter/material.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart'; // Import package baru
import 'dashboard_screen.dart';
import 'map_screen.dart';
import 'history_screen.dart';
import 'event_screen.dart';
import 'profile_screen.dart';

class MainScreen extends StatefulWidget {
  final String userName;

  const MainScreen({super.key, required this.userName});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      DashboardScreen(userName: widget.userName),
      const MapScreen(),
      const HistoryScreen(),
      const EventScreen(),
      const ProfileScreen(),
    ];
  }

  void _onTabTapped(int index) {
    if (_currentIndex != index) {
      setState(() {
        _currentIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const accentColor = Color(0xFF00FF66); // Hijau Awal (Tanpa Neon)

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      // Memastikan body merespon warna latar dengan baik
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

      // === NAVIGASI CURVED (Seperti di Video) ===
      bottomNavigationBar: CurvedNavigationBar(
        index: _currentIndex,
        height: 60.0,
        // Warna item ikon
        items: const <Widget>[
          Icon(Icons.home_rounded, size: 26, color: accentColor),
          Icon(Icons.map_rounded, size: 26, color: accentColor),
          Icon(Icons.history_rounded, size: 26, color: accentColor),
          Icon(Icons.event_note_rounded, size: 26, color: accentColor),
          Icon(Icons.person_rounded, size: 26, color: accentColor),
        ],
        // Warna dasar navigation bar
        color: const Color(0xFF1E1E1E),
        // Warna latar belakang di balik kurva (Disamakan dengan Scaffold agar menyatu)
        backgroundColor: const Color(0xFF121212),
        // Warna lingkaran yang melayang
        buttonBackgroundColor: const Color(0xFF1E1E1E),
        animationCurve: Curves.easeInOut,
        animationDuration: const Duration(milliseconds: 400),
        onTap: _onTabTapped,
      ),
    );
  }
}
