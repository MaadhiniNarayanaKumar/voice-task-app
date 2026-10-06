import 'package:flutter/material.dart';

import '../cal/cal.dart';
import '../core/auth/auth_service.dart';
import '../core/config/config.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/theme_controller.dart';
import '../mia/mia.dart';
import '../mia/screens/categories_screen.dart';
import 'auth/auth_gate.dart';
import 'settings/settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.auth, this.themes});

  final AuthService auth;
  final ThemeController? themes;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  late final AnimationController _motion;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  int _navIndex = 0;

  String get _uid => widget.auth.currentUser?.uid ?? AppConfig.guestUid;

  String get _email =>
      widget.auth.currentUser?.email ?? 'guest@mia.app';

  String get _displayName {
    final email = _email;
    final name = email.split('@').first;
    return name.isEmpty ? 'Guest' : name;
  }

  String get _initial {
    final name = _displayName;
    return name.isEmpty ? 'M' : name.characters.first.toUpperCase();
  }

  @override
  void initState() {
    super.initState();
    _motion = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _fade = CurvedAnimation(parent: _motion, curve: Curves.easeOutCubic);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _motion, curve: Curves.easeOutCubic));
    _motion.forward();
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  Future<void> _openMia() async {
    if (!AppConfig.skipSignIn && widget.auth.currentUser == null) {
      await widget.themes?.setThemeForFeature('tasks');
      if (!mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => AuthGate(auth: widget.auth),
        ),
      );
      return;
    }
    await Mia.open(
      context,
      auth: widget.auth,
      themes: widget.themes,
    );
  }

  Future<void> _openCategories() async {
    final id = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => CategoriesScreen(uid: _uid),
      ),
    );
    if (id == null || !mounted) return;
    await Mia.open(
      context,
      auth: widget.auth,
      themes: widget.themes,
      filterCategoryId: id,
    );
  }

  Future<void> _openCalendar() async {
    await Cal.open(
      context,
      themes: widget.themes,
      uid: _uid,
    );
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SettingsScreen(auth: widget.auth),
      ),
    );
  }

  void _onNavTap(int index) {
    setState(() => _navIndex = index);
    if (index == 1) {
      _openMia();
      setState(() => _navIndex = 0);
    } else if (index == 2) {
      _openCategories();
      setState(() => _navIndex = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,
      endDrawer: _profileDrawer(),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fade,
          child: SlideTransition(
            position: _slide,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _header(),
                      const SizedBox(height: 28),
                      Text(
                        'Quick actions',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.text,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _quickActionsGrid(),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: _bottomNav(),
    );
  }

  Widget _header() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _greeting(),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.muted,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Welcome back',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text,
                  letterSpacing: -0.4,
                ),
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: () => _scaffoldKey.currentState?.openEndDrawer(),
          child: CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.indigo,
            child: Text(
              _initial,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _profileDrawer() {
    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.indigo, AppColors.indigoSoft],
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.white24,
                    child: Text(
                      _initial,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 22,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _displayName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: Icon(Icons.settings_outlined, color: AppColors.indigo),
              title: const Text(
                'Settings',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: const Text('Theme, Mia preferences'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                Navigator.pop(context);
                _openSettings();
              },
            ),
            ListTile(
              leading: Icon(Icons.mic_rounded, color: AppColors.indigo),
              title: const Text(
                'Open Mia',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              onTap: () {
                Navigator.pop(context);
                _openMia();
              },
            ),
            const Spacer(),
            if (!AppConfig.skipSignIn)
              ListTile(
                leading: const Icon(Icons.logout_rounded),
                title: const Text('Sign out'),
                onTap: () {
                  Navigator.pop(context);
                  widget.auth.signOut();
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _quickActionsGrid() {
    final actions = <({
      IconData icon,
      String label,
      Color tint,
      Color accent,
      VoidCallback onTap,
    })>[
      (
        icon: Icons.mic_rounded,
        label: 'Voice',
        tint: AppColors.tint,
        accent: AppColors.indigo,
        onTap: _openMia,
      ),
      (
        icon: Icons.add_rounded,
        label: 'Add task',
        tint: AppColors.softBlue,
        accent: const Color(0xFF0284C7),
        onTap: _openMia,
      ),
      (
        icon: Icons.category_outlined,
        label: 'Categories',
        tint: const Color(0xFFF3E8FF),
        accent: const Color(0xFF7C3AED),
        onTap: _openCategories,
      ),
      (
        icon: Icons.calendar_month_rounded,
        label: 'Calendar',
        tint: AppColors.softBlue,
        accent: const Color(0xFF2563EB),
        onTap: _openCalendar,
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: actions.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.15,
      ),
      itemBuilder: (context, index) {
        final item = actions[index];
        return _Pressable(
          borderRadius: AppRadii.lg,
          onTap: item.onTap,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadii.lg),
              boxShadow: AppTheme.cardShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: item.tint,
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                  ),
                  child: Icon(item.icon, size: 20, color: item.accent),
                ),
                const Spacer(),
                Text(
                  item.label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _bottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Row(
            children: [
              _navItem(0, Icons.home_rounded, 'Home'),
              _navItem(1, Icons.mic_rounded, 'Mia'),
              _navItem(2, Icons.category_outlined, 'Categories'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(int index, IconData icon, String label) {
    final selected = _navIndex == index;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _onNavTap(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? AppColors.tint : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 22,
                color: selected ? AppColors.indigo : Colors.black38,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: selected ? AppColors.indigo : Colors.black38,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pressable extends StatefulWidget {
  const _Pressable({
    required this.child,
    required this.onTap,
    required this.borderRadius,
  });

  final Widget child;
  final VoidCallback onTap;
  final double borderRadius;

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
