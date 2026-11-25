import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'campus_board_screen.dart';
import 'home_screen.dart';
import 'post_ad_screen.dart';
import 'profile_screen.dart';
import 'create_board_post_screen.dart';

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

  Future<void> _showPostChoiceDialog() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 78, left: 24, right: 24),
          child: Material(
            color: Colors.white,
            elevation: 10,
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'What would you like to post?',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _PostOptionCard(
                          icon: Icons.storefront_outlined,
                          label: 'Post Ad',
                          subtitle: 'Sell item',
                          color: Colors.deepPurple,
                          onTap: () {
                            Navigator.pop(ctx);
                            setState(() => _currentIndex = 2);
                            MainScreen.tabNotifier.value = 2;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _PostOptionCard(
                          icon: Icons.campaign_outlined,
                          label: 'Post on Board',
                          subtitle: 'Notice / Event',
                          color: const Color(0xFF2E7D32),
                          onTap: () async {
                            Navigator.pop(ctx);
                            await _openBoardComposer();
                          },
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
    );
  }

  Future<void> _openBoardComposer() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final campusId = doc.data()?['campusId'] as String? ?? '';
      if (!mounted) return;
      if (campusId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No campus found on your profile.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CreateBoardPostScreen(campusId: campusId),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open composer: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  final List<Widget> _screens = [
    const CampusBoardScreen(),
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
              if (index == 2) {
                _showPostChoiceDialog();
                return;
              }
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
                icon: Icon(Icons.campaign_outlined),
                activeIcon: Icon(Icons.campaign),
                label: 'Board',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined),
                activeIcon: Icon(Icons.home),
                label: 'Sell',
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

class _PostOptionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _PostOptionCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 28, color: color),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
