import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:hpdaerah/models/user_model.dart';
import 'package:hpdaerah/views/auth/dashboard/beranda/home_tab.dart';
import 'package:hpdaerah/views/auth/dashboard/navigator_menu_utama.dart';
import 'package:hpdaerah/views/auth/dashboard/qrcode/qr_code_tab.dart';
import 'package:hpdaerah/views/auth/dashboard/profil/profile_tab.dart';
import 'package:hpdaerah/services/notification_service.dart';

// Dashboard Page Controller
class DashboardPage extends StatefulWidget {
  final UserModel user;

  const DashboardPage({super.key, required this.user});

  @override
  DashboardPageState createState() => DashboardPageState();

  static DashboardPageState? of(BuildContext context) =>
      context.findAncestorStateOfType<DashboardPageState>();
}

class DashboardPageState extends State<DashboardPage> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _initNotifications();
  }

  void _initNotifications() async {
    final notif = NotificationService();
    await notif.init();
    notif.startMonitoring(widget.user);
  }

  List<Widget> get _pages {
    List<Widget> pages = [
      HomeTab(user: widget.user),
      QrCodeTab(user: widget.user),
    ];
    if (widget.user.isAdmin) {
      pages.add(AdminTab(user: widget.user));
    }
    pages.add(ProfileTab(user: widget.user));
    return pages;
  }

  void setSelectedIndex(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      extendBody: true, // Makes bottomNavigationBar float over content
      body: IndexedStack(index: _selectedIndex, children: _pages),
      bottomNavigationBar: _buildGlassBottomNav(),
    );
  }

  /// White Transparent Bottom Navigation Bar (Floating Card Style)
  Widget _buildGlassBottomNav() {
    return Container(
      color: Colors.transparent,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: _buildNavItem(
                    index: 0,
                    icon: Icons.home_outlined,
                    activeIcon: Icons.home,
                    label: 'Beranda',
                  ),
                ),
                Expanded(
                  child: _buildNavItem(
                    index: 1,
                    icon: Icons.qr_code_scanner,
                    activeIcon: Icons.qr_code_2,
                    label: 'QR Code',
                  ),
                ),
                if (widget.user.isAdmin)
                  Expanded(
                    child: _buildNavItem(
                      index: 2,
                      icon: Icons.admin_panel_settings_outlined,
                      activeIcon: Icons.admin_panel_settings,
                      label: 'Admin',
                    ),
                  ),
                Expanded(
                  child: _buildNavItem(
                    index: widget.user.isAdmin ? 3 : 2,
                    icon: Icons.person_outline,
                    activeIcon: Icons.person,
                    label: 'Profil',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
  }) {
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => setSelectedIndex(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF1A5F2D).withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              color: isSelected ? const Color(0xFF1A5F2D) : Colors.grey[500],
              size: 22, // Smaller icon
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isSelected ? const Color(0xFF1A5F2D) : Colors.grey[500],
                fontSize: 10, // Smaller font
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              maxLines: 1,
              overflow: TextOverflow.clip,
              softWrap: false,
            ),
          ],
        ),
      ),
    );
  }
}
