import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hpdaerah/models/user_model.dart';
import 'package:hpdaerah/utils/menu_helper.dart';
import 'package:hpdaerah/views/auth/login_page.dart';
import 'package:hpdaerah/views/auth/dashboard/admin/admin_navigator_header.dart';
import 'package:hpdaerah/views/auth/dashboard/admin/organisasi/organisasi_list_page.dart';
import 'package:hpdaerah/views/auth/dashboard/admin/presensi/presensi_center_page.dart';
import 'package:hpdaerah/views/auth/dashboard/admin/pengajian/pengajian_dashboard_page.dart';
import 'package:hpdaerah/views/auth/dashboard/admin/pengguna/pengguna_list_page.dart';

// QR Code Tab moved to separate file

// ============================================================
// ADMIN TAB
// ============================================================
class AdminTab extends StatefulWidget {
  final UserModel user;

  const AdminTab({super.key, required this.user});

  @override
  State<AdminTab> createState() => _AdminTabState();
}

class _AdminTabState extends State<AdminTab> {
  String? _selectedAdminRoute;

  @override
  void initState() {
    super.initState();
    final adminMenus = MenuHelper.getMenus(
      widget.user,
    ).where((m) => m.route.startsWith('/admin')).toList();
    if (adminMenus.isNotEmpty) {
      _selectedAdminRoute = adminMenus.first.route;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          // Admin Navigator Header (Responsive & Centered)
          AdminNavigatorHeader(
            user: widget.user,
            selectedRoute: _selectedAdminRoute ?? '',
            onRouteSelected: (route) {
              setState(() => _selectedAdminRoute = route);
            },
          ),

          // Main Content Area
          Expanded(child: _buildAdminContent(_selectedAdminRoute)),
        ],
      ),
    );
  }

  Widget _buildAdminContent(String? route) {
    debugPrint(
      'Admin Content Build: User=${widget.user.username}, '
      'AdminLevel=${widget.user.adminLevel}, '
      'AdminOrgID=${widget.user.adminOrgId}, '
      'CurrentOrgID=${widget.user.currentOrgId}',
    );

    if (route == null) return const Center(child: Text('Pilih menu admin'));

    switch (route) {
      case '/admin/organisasi':
        // Logic Hierarki: Admin hanya bisa melihat sub-organisasi di bawahnya
        int startLevel = 0;
        String? startParentId;
        String?
        startParentName; // Optional, bisa fetch atau biarkan null (Title default)

        if (widget.user.adminLevel != null && widget.user.adminLevel! > 0) {
          // Admin Daerah (1) -> Start lihat Desa (Level 1), parent = adminOrgId (Daerahnya)
          // Admin Desa (2) -> Start lihat Kelompok (Level 2), parent = adminOrgId (Desanya)
          // Admin Kelompok (3) -> Start lihat Kategori (Level 3), parent = adminOrgId (Kelompoknya)
          startLevel = widget.user.adminLevel!;
          startParentId = widget.user.adminOrgId;
          // Note: Level 4 (Kategori) tidak punya child organisasi di sistem ini, jadi list akan kosong (benar).
        }

        return OrganisasiListPage(
          level: startLevel,
          parentId: startParentId,
          parentName: startParentName,
        );
      case '/admin/presensi-center':
        return const PresensiCenterPage();
      case '/admin/pengajian/buat':
        return PengajianDashboardPage(
          user: widget.user,
          orgId: widget.user.adminOrgId ?? widget.user.currentOrgId ?? '',
        );
      case '/admin/pengguna':
        return PenggunaListPage(currentUser: widget.user);
      default:
        return const Center(child: Text('Halaman Belum Tersedia'));
    }
  }
}
