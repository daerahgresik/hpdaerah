import 'package:flutter/material.dart';
import 'package:hpdaerah/models/user_model.dart';
import 'package:hpdaerah/utils/menu_helper.dart';
import 'package:hpdaerah/views/auth/dashboard/admin/admin_navigator_header.dart';
import 'package:hpdaerah/views/auth/dashboard/admin/organisasi/organisasi_list_page.dart';
import 'package:hpdaerah/views/auth/dashboard/admin/presensi/presensi_center_page.dart';
import 'package:hpdaerah/views/auth/dashboard/admin/pengajian/pengajian_dashboard_page.dart';
import 'package:hpdaerah/views/auth/dashboard/admin/pengguna/pengguna_list_page.dart';

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
  String? _selectedDaerahId; // Untuk Super Admin context

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

  /// Get effective org ID berdasarkan admin level
  /// Super Admin: menggunakan selected daerah ID
  /// Admin lain: menggunakan adminOrgId mereka
  String? get _effectiveOrgId {
    if (widget.user.isSuperAdmin) {
      return _selectedDaerahId;
    }
    return widget.user.adminOrgId ?? widget.user.currentOrgId;
  }

  /// Get effective admin level
  /// Super Admin yang sudah pilih daerah: act as Admin Daerah (level 1)
  int? get _effectiveAdminLevel {
    if (widget.user.isSuperAdmin && _selectedDaerahId != null) {
      return 1; // Act as Admin Daerah
    }
    return widget.user.adminLevel;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          // Admin Navigator Header (with identity + context)
          AdminNavigatorHeader(
            user: widget.user,
            selectedRoute: _selectedAdminRoute ?? '',
            onRouteSelected: (route) {
              setState(() => _selectedAdminRoute = route);
            },
            selectedDaerahId: _selectedDaerahId,
            onDaerahSelected: (daerahId) {
              setState(() => _selectedDaerahId = daerahId);
            },
          ),

          // Check if Super Admin needs to select daerah first
          if (widget.user.isSuperAdmin &&
              _selectedDaerahId == null &&
              _selectedAdminRoute != '/admin/organisasi')
            Expanded(child: _buildSelectDaerahPrompt())
          else
            // Main Content Area
            Expanded(child: _buildAdminContent(_selectedAdminRoute)),
        ],
      ),
    );
  }

  /// Prompt untuk Super Admin memilih daerah
  Widget _buildSelectDaerahPrompt() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.location_searching,
                size: 64,
                color: Colors.orange[400],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Pilih Daerah Terlebih Dahulu',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Sebagai Super Admin, Anda perlu memilih daerah yang ingin dikelola sebelum dapat mengakses fitur admin.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) => DaerahSelectorSheet(
                    currentDaerahId: _selectedDaerahId,
                    onSelect: (daerahId) {
                      Navigator.pop(context);
                      setState(() => _selectedDaerahId = daerahId);
                    },
                  ),
                );
              },
              icon: const Icon(Icons.location_on),
              label: const Text('Pilih Daerah'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A5F2D),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminContent(String? route) {
    debugPrint(
      'Admin Content Build: User=${widget.user.username}, '
      'AdminLevel=$_effectiveAdminLevel, '
      'EffectiveOrgID=$_effectiveOrgId',
    );

    if (route == null) return const Center(child: Text('Pilih menu admin'));

    switch (route) {
      case '/admin/organisasi':
        // Logic Hierarki: Admin hanya bisa melihat sub-organisasi di bawahnya
        int startLevel = 0;
        String? startParentId;

        final effectiveLevel = _effectiveAdminLevel;
        final effectiveOrgId = _effectiveOrgId;

        if (effectiveLevel != null && effectiveLevel > 0) {
          // Admin Daerah (1) -> Start lihat Desa (Level 1), parent = adminOrgId (Daerahnya)
          // Admin Desa (2) -> Start lihat Kelompok (Level 2), parent = adminOrgId (Desanya)
          // Admin Kelompok (3) -> Start lihat Kategori (Level 3), parent = adminOrgId (Kelompoknya)
          startLevel = effectiveLevel;
          startParentId = effectiveOrgId;
        }

        return OrganisasiListPage(
          level: startLevel,
          parentId: startParentId,
          parentName: null,
        );

      case '/admin/presensi-center':
        return PresensiCenterPage(user: widget.user);

      case '/admin/pengajian/buat':
        return PengajianDashboardPage(
          user: widget.user.isSuperAdmin
              ? widget.user.copyWith(
                  adminLevel: _effectiveAdminLevel,
                  adminOrgId: _effectiveOrgId,
                )
              : widget.user,
          orgId: _effectiveOrgId ?? '',
        );

      case '/admin/pengguna':
        return PenggunaListPage(currentUser: widget.user);

      default:
        return const Center(child: Text('Halaman Belum Tersedia'));
    }
  }
}
