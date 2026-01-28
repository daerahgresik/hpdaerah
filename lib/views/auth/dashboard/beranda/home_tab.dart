import 'package:flutter/material.dart';
import 'package:hpdaerah/models/user_model.dart';
import 'package:hpdaerah/utils/menu_helper.dart';
import 'package:hpdaerah/views/auth/dashboard/dashboard_page.dart';

class HomeTab extends StatefulWidget {
  final UserModel user;

  const HomeTab({super.key, required this.user});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  // No unused streams

  @override
  void initState() {
    super.initState();
  }

  @override
  void didUpdateWidget(HomeTab oldWidget) {
    super.didUpdateWidget(oldWidget);
  }

  void _handleNavigation(BuildContext context, String route) {
    switch (route) {
      case '/qr-view':
        DashboardPage.of(context)?.setSelectedIndex(1);
        break;
      case '/riwayat':
        _showSnackBar(context, "Menu Riwayat (Segera Hadir)");
        break;
      case '/izin':
        _showSnackBar(context, "Menu Izin (Segera Hadir)");
        break;
      case '/khataman':
        _showSnackBar(context, "Menu Khataman (Segera Hadir)");
        break;
      case '/sodakoh':
        _showSnackBar(context, "Menu Sodakoh (Segera Hadir)");
        break;
      case '/pengumuman':
        _showSnackBar(context, "Menu Pengumuman (Segera Hadir)");
        break;
      case '/materi':
        _showSnackBar(context, "Menu Materi (Segera Hadir)");
        break;
      case '/kalender':
        _showSnackBar(context, "Menu Kalender (Segera Hadir)");
        break;
      case '/galeri':
        _showSnackBar(context, "Menu Galeri (Segera Hadir)");
        break;
      default:
        _showSnackBar(context, "Menu $route belum tersedia");
    }
  }

  void _showSnackBar(BuildContext context, String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 1)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final generalMenus = MenuHelper.getMenus(
      widget.user,
    ).where((m) => !m.route.startsWith('/admin')).toList();

    return Stack(
      children: [
        // Background
        Column(
          children: [
            Container(
              height: 200,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1A5F2D), Color(0xFF2E7D32)],
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
              ),
            ),
          ],
        ),
        SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header (Profile)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Assalamu'alaikum,",
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                        Text(
                          widget.user.nama,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const CircleAvatar(
                      backgroundColor: Colors.white24,
                      child: Icon(
                        Icons.notifications_outlined,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Main Menu Grid
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 3,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  children: generalMenus.map((menu) {
                    return GestureDetector(
                      onTap: () => _handleNavigation(context, menu.route),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Icon(
                              menu.icon,
                              color: const Color(0xFF1A5F2D),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            menu.title,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 24),

                // Admin Sections (If applicable)
                if (widget.user.isAdmin) ...[
                  const Text(
                    "Admin Shortcut",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    childAspectRatio: 2.5,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    children: [
                      _buildAdminCard(
                        context,
                        "Pengajian",
                        Icons.mosque,
                        Colors.green,
                        () => DashboardPage.of(context)?.setSelectedIndex(2),
                      ),
                      _buildAdminCard(
                        context,
                        "Khataman",
                        Icons.auto_stories,
                        Colors.orange,
                        () => DashboardPage.of(context)?.setSelectedIndex(3),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAdminCard(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
