import 'package:flutter/material.dart';
import 'package:hpdaerah/models/user_model.dart';
import 'package:hpdaerah/utils/menu_helper.dart';
import 'package:hpdaerah/views/auth/dashboard/dashboard_page.dart';
import 'package:hpdaerah/views/auth/dashboard/beranda/percakapan.dart'; // Import Module Percakapan Baru

class HomeTab extends StatelessWidget {
  final UserModel user;

  const HomeTab({super.key, required this.user});

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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 1)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final generalMenus = MenuHelper.getMenus(
      user,
    ).where((m) => !m.route.startsWith('/admin')).toList();

    return Stack(
      children: [
        // Background
        Column(
          children: [
            _buildHeaderBackground(),
            Expanded(child: Container(color: Colors.grey[50])),
          ],
        ),

        // Content
        SafeArea(
          child: Column(
            children: [
              _buildHeaderContent(),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  children: [
                    const SizedBox(height: 10),

                    // Announcement Card (Announcement + Chat Button)
                    _buildDefaultStatusCard(context),
                    const SizedBox(height: 32),

                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4.0),
                      child: Text(
                        "Menu Utama",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 0.85,
                          ),
                      itemCount: generalMenus.length,
                      itemBuilder: (context, index) {
                        final menu = generalMenus[index];
                        return _buildFeatureCard(
                          menu.title,
                          menu.icon,
                          menu.color,
                          () => _handleNavigation(context, menu.route),
                        );
                      },
                    ),
                    const SizedBox(height: 120),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDefaultStatusCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // 1. Icon Pengumuman
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.campaign_outlined,
              color: Colors.orange,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),

          // 2. Teks Pengumuman
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Papan Pengumuman",
                  style: TextStyle(color: Colors.grey, fontSize: 11),
                ),
                const SizedBox(height: 2),
                Text(
                  "Belum ada info terbaru hari ini.", // Nanti bisa dinamis
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: Colors.grey[800],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // 3. Tombol Chat (Sekarang memanggil showPercakapanModal dari file eksternal)
          Container(
            margin: const EdgeInsets.only(left: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1A5F2D).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(
                Icons.chat_bubble_outline,
                color: Color(0xFF1A5F2D),
                size: 20,
              ),
              tooltip: "Ruang Ngobrol",
              onPressed: () => showPercakapanModal(context, user),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderBackground() {
    return Container(
      height: 160,
      decoration: const BoxDecoration(
        color: Color(0xFF1A5F2D),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
    );
  }

  Widget _buildHeaderContent() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: Colors.white,
            child: Text(
              user.nama.isNotEmpty ? user.nama[0] : '?',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A5F2D),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Assalamualaikum,',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                Text(
                  user.nama,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.notifications_outlined, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard(
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap, {
    bool isLarge = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: isLarge ? 160 : 120,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.05),
              spreadRadius: 2,
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 32, color: color),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
