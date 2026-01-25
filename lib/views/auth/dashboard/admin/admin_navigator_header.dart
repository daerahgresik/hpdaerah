import 'package:flutter/material.dart';
import 'package:hpdaerah/models/user_model.dart';
import 'package:hpdaerah/models/organization_model.dart';
import 'package:hpdaerah/services/organization_service.dart';
import 'package:hpdaerah/utils/menu_helper.dart';

/// Reusable Admin Navigator Header
/// Menampilkan identitas admin + menu navigasi
class AdminNavigatorHeader extends StatefulWidget {
  final String selectedRoute;
  final ValueChanged<String> onRouteSelected;
  final UserModel user;
  final String? selectedDaerahId; // Untuk Super Admin
  final ValueChanged<String>? onDaerahSelected; // Callback saat pilih daerah

  const AdminNavigatorHeader({
    super.key,
    required this.selectedRoute,
    required this.onRouteSelected,
    required this.user,
    this.selectedDaerahId,
    this.onDaerahSelected,
  });

  @override
  State<AdminNavigatorHeader> createState() => _AdminNavigatorHeaderState();
}

class _AdminNavigatorHeaderState extends State<AdminNavigatorHeader> {
  final _orgService = OrganizationService();
  Map<String, String> _adminInfo = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAdminInfo();
  }

  @override
  void didUpdateWidget(covariant AdminNavigatorHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload jika admin context berubah (untuk Super Admin)
    if (oldWidget.selectedDaerahId != widget.selectedDaerahId) {
      _loadAdminInfo();
    }
  }

  Future<void> _loadAdminInfo() async {
    setState(() => _isLoading = true);

    String? orgId = widget.user.adminOrgId;
    int? level = widget.user.adminLevel;

    // Jika Super Admin dan sudah pilih daerah
    if (widget.user.isSuperAdmin && widget.selectedDaerahId != null) {
      orgId = widget.selectedDaerahId;
      level = 1; // Act as Admin Daerah
    }

    if (orgId != null) {
      final info = await _orgService.getAdminScopeInfo(
        adminLevel: level,
        adminOrgId: orgId,
      );
      setState(() {
        _adminInfo = info;
        _isLoading = false;
      });
    } else {
      setState(() {
        _adminInfo = {
          'title': widget.user.isSuperAdmin ? 'Super Admin' : 'Admin',
          'subtitle': widget.user.isSuperAdmin
              ? 'Pilih daerah untuk memulai'
              : '',
          'path': '',
        };
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final adminMenus = MenuHelper.getMenus(
      widget.user,
    ).where((m) => m.route.startsWith('/admin')).toList();

    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Admin Identity Header
          _buildIdentityHeader(isTablet),

          // Menu Navigation
          Container(
            padding: EdgeInsets.symmetric(
              vertical: 12,
              horizontal: isTablet ? 24 : 12,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isTablet ? 600 : double.infinity,
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: adminMenus.asMap().entries.map((entry) {
                      final index = entry.key;
                      final menu = entry.value;
                      final isSelected = widget.selectedRoute == menu.route;

                      return Padding(
                        padding: EdgeInsets.only(
                          left: index == 0 ? 0 : 6,
                          right: index == adminMenus.length - 1 ? 0 : 6,
                        ),
                        child: _AdminMenuChip(
                          title: menu.title,
                          icon: menu.icon,
                          color: menu.color,
                          isSelected: isSelected,
                          onTap: () => widget.onRouteSelected(menu.route),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIdentityHeader(bool isTablet) {
    final isSuperAdmin = widget.user.isSuperAdmin;
    final hasSelectedDaerah = widget.selectedDaerahId != null;

    return Container(
      padding: EdgeInsets.fromLTRB(
        isTablet ? 24 : 16,
        16,
        isTablet ? 24 : 16,
        12,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF1A5F2D), const Color(0xFF2E7D42)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          // Icon
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isSuperAdmin ? Icons.shield : Icons.admin_panel_settings,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),

          // Info Text
          Expanded(
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _adminInfo['title'] ?? 'Admin',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      if (_adminInfo['subtitle']?.isNotEmpty == true) ...[
                        const SizedBox(height: 2),
                        Text(
                          _adminInfo['subtitle']!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ],
                  ),
          ),

          // Super Admin: Change Daerah Button
          if (isSuperAdmin)
            GestureDetector(
              onTap: () => _showDaerahSelector(context),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      hasSelectedDaerah ? Icons.swap_horiz : Icons.location_on,
                      size: 16,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      hasSelectedDaerah ? 'Ganti' : 'Pilih Daerah',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showDaerahSelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DaerahSelectorSheet(
        currentDaerahId: widget.selectedDaerahId,
        onSelect: (daerahId) {
          Navigator.pop(context);
          widget.onDaerahSelected?.call(daerahId);
        },
      ),
    );
  }
}

/// Bottom Sheet untuk memilih Daerah (Super Admin)
class DaerahSelectorSheet extends StatefulWidget {
  final String? currentDaerahId;
  final ValueChanged<String> onSelect;

  const DaerahSelectorSheet({
    super.key,
    this.currentDaerahId,
    required this.onSelect,
  });

  @override
  State<DaerahSelectorSheet> createState() => _DaerahSelectorSheetState();
}

class _DaerahSelectorSheetState extends State<DaerahSelectorSheet> {
  final _orgService = OrganizationService();
  List<Organization> _daerahList = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDaerah();
  }

  Future<void> _loadDaerah() async {
    try {
      final list = await _orgService.fetchDaerah();
      setState(() {
        _daerahList = list;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Title
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A5F2D).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.location_city,
                    color: Color(0xFF1A5F2D),
                    size: 28,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Pilih Daerah yang Ingin Dikelola',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Anda akan berperan sebagai Admin Daerah tersebut',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // List
          Flexible(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _daerahList.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        'Belum ada data daerah',
                        style: TextStyle(color: Colors.grey[500]),
                      ),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _daerahList.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final daerah = _daerahList[index];
                      final isSelected = daerah.id == widget.currentDaerahId;

                      return ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF1A5F2D)
                                : Colors.grey[100],
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.location_on,
                            color: isSelected ? Colors.white : Colors.grey[600],
                            size: 20,
                          ),
                        ),
                        title: Text(
                          daerah.name,
                          style: TextStyle(
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isSelected ? const Color(0xFF1A5F2D) : null,
                          ),
                        ),
                        trailing: isSelected
                            ? const Icon(
                                Icons.check_circle,
                                color: Color(0xFF1A5F2D),
                              )
                            : const Icon(
                                Icons.chevron_right,
                                color: Colors.grey,
                              ),
                        onTap: () => widget.onSelect(daerah.id),
                      );
                    },
                  ),
          ),

          // Safe area padding
          SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
        ],
      ),
    );
  }
}

class _AdminMenuChip extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _AdminMenuChip({
    required this.title,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF059669) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF059669)
                : Colors.grey.withValues(alpha: 0.25),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF059669).withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: isSelected ? Colors.white : color),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                color: isSelected ? Colors.white : Colors.grey[800],
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
