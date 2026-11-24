import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'home_screen.dart';
import 'post_ad_screen.dart';
import 'profile_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  // ── Global tab switcher ───────────────────────────────────────────────────
  static final ValueNotifier<int> tabNotifier = ValueNotifier(0);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  DateTime? _lastBackPressed;

  @override
  void initState() {
    super.initState();
    // Listen for tab switch requests from other screens
    MainScreen.tabNotifier.addListener(_onTabChange);
  }

  @override
  void dispose() {
    MainScreen.tabNotifier.removeListener(_onTabChange);
    super.dispose();
  }

  void _onTabChange() {
    setState(() => _currentIndex = MainScreen.tabNotifier.value);
  }

  Future<bool> _onWillPop() async {
    if (_currentIndex != 0) {
      setState(() => _currentIndex = 0);
      MainScreen.tabNotifier.value = 0;
      return false;
    }

    final now = DateTime.now();
    if (_lastBackPressed == null ||
        now.difference(_lastBackPressed!) >
            const Duration(seconds: 2)) {
      _lastBackPressed = now;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Press back again to exit'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return false;
    }

    SystemNavigator.pop();
    return true;
  }

  final List<Widget> _screens = [
    const HomeScreen(),
    const PostAdScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        await _onWillPop();
      },
      child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: _screens,
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) {
              setState(() => _currentIndex = index);
              MainScreen.tabNotifier.value = index;
            },
            backgroundColor: Colors.white,
            selectedItemColor: Colors.deepPurple,
            unselectedItemColor: Colors.grey.shade400,
            selectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
            type: BottomNavigationBarType.fixed,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined),
                activeIcon: Icon(Icons.home),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.add_circle_outline, size: 30),
                activeIcon: Icon(Icons.add_circle, size: 30),
                label: 'Post',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person_outline),
                activeIcon: Icon(Icons.person),
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }
}