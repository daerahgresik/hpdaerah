import 'package:flutter/material.dart';
import 'package:hpdaerah/models/user_model.dart';
import 'package:hpdaerah/utils/menu_helper.dart';
import 'package:hpdaerah/models/pengajian_qr_model.dart';
import 'package:hpdaerah/services/pengajian_qr_service.dart';
import 'package:hpdaerah/models/pengajian_model.dart';
import 'package:hpdaerah/services/pengajian_service.dart';
import 'package:hpdaerah/views/auth/dashboard/qrcode/qr_code_tab.dart';
import 'package:hpdaerah/views/auth/dashboard/admin/pengajian/rekap_pengajian_page.dart';

class HomeTab extends StatelessWidget {
  final UserModel user;

  const HomeTab({super.key, required this.user});

  void _handleNavigation(BuildContext context, String route) {
    switch (route) {
      case '/qr-view':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => QrCodeTab(user: user)),
        );
        break;
      case '/riwayat':
        _showSnackBar(context, "Menu Riwayat (Segera Hadir)");
        break;
      case '/izin':
        _showSnackBar(context, "Menu Izin (Segera Hadir)");
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

                    // Live Status Card
                    _buildLiveStatusCard(context),
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
                            crossAxisCount: 2,
                            mainAxisSpacing: 16,
                            crossAxisSpacing: 16,
                            childAspectRatio: 1.1,
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

  Widget _buildLiveStatusCard(BuildContext context) {
    if (user.id == null) return const SizedBox.shrink();

    // 1. If User is Admin, search for active rooms to manage
    if (user.isAdmin) {
      return StreamBuilder<List<Pengajian>>(
        stream: PengajianService().streamActivePengajian(
          user,
          user.adminOrgId ?? user.currentOrgId ?? '',
        ),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _buildErrorStatusCard(snapshot.error.toString());
          }
          final activeRooms = snapshot.data ?? [];
          if (activeRooms.isEmpty) return _buildDefaultStatusCard();

          final latest = activeRooms.first;
          return _buildInfoCard(
            context,
            title: "Pengajian Sedang Berlangsung",
            subtitle: latest.title,
            icon: Icons.admin_panel_settings,
            color: Colors.blue,
            actionLabel: "Kelola Presensi",
            onAction: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => RekapPengajianPage(pengajian: latest),
              ),
            ),
          );
        },
      );
    }

    // 2. For Normal Users (or Admins as participants), search for active QR
    if (user.id == null) return _buildDefaultStatusCard();
    return StreamBuilder<List<PengajianQr>>(
      stream: PengajianQrService().streamActiveQrForUser(user.id!),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildErrorStatusCard(snapshot.error.toString());
        }
        final activeQrs = (snapshot.data ?? [])
            .where((q) => !q.isUsed)
            .toList();
        if (activeQrs.isEmpty) return _buildDefaultStatusCard();

        final latest = activeQrs.first;
        return _buildInfoCard(
          context,
          title: "Anda Terdaftar di Pengajian",
          subtitle: latest.pengajianTitle ?? "Pengajian",
          icon: Icons.qr_code_2,
          color: const Color(0xFF1A5F2D),
          actionLabel: "Tampilkan QR",
          onAction: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => QrCodeTab(user: user)),
          ),
        );
      },
    );
  }

  Widget _buildErrorStatusCard(String error) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.red.shade100),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red[700]),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              "Oops! Gagal memuat data: $error",
              style: TextStyle(color: Colors.red[900], fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultStatusCard() {
    return Container(
      padding: const EdgeInsets.all(20),
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
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1A5F2D).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.check_circle, color: Color(0xFF1A5F2D)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Status Kehadiran",
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
                const SizedBox(height: 4),
                const Text(
                  "Akses Mudah & Cepat",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.white, size: 24),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            subtitle,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onAction,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: color,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: Text(
                actionLabel,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
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
