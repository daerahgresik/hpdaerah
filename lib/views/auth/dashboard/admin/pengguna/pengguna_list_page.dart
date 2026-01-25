import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hpdaerah/models/user_model.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:barcode_widget/barcode_widget.dart';

class PenggunaListPage extends StatefulWidget {
  final UserModel? currentUser;

  const PenggunaListPage({super.key, this.currentUser});

  @override
  State<PenggunaListPage> createState() => _PenggunaListPageState();
}

class _PenggunaListPageState extends State<PenggunaListPage>
    with TickerProviderStateMixin {
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _filteredUsers = [];
  List<Map<String, dynamic>> _organisations = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedFilter =
      'Semua'; // Filter: Semua, Super Admin, Admin Daerah, Admin Desa, Admin Kelompok, User
  final TextEditingController _searchController = TextEditingController();

  late AnimationController _fadeController;

  final List<Map<String, dynamic>> _filterOptions = [
    {'label': 'Semua', 'level': null, 'icon': Icons.people},
    {'label': 'Super Admin', 'level': 0, 'icon': Icons.shield},
    {'label': 'Admin Daerah', 'level': 1, 'icon': Icons.location_city},
    {'label': 'Admin Desa', 'level': 2, 'icon': Icons.home_work},
    {'label': 'Admin Kelompok', 'level': 3, 'icon': Icons.groups},
    {'label': 'User', 'level': -1, 'icon': Icons.person_outline},
  ];

  int get _currentAdminLevel => widget.currentUser?.adminLevel ?? 0;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _loadData();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final usersResponse = await Supabase.instance.client
          .from('users')
          .select()
          .order('nama', ascending: true);

      final orgsResponse = await Supabase.instance.client
          .from('organizations')
          .select()
          .order('level', ascending: true)
          .order('name', ascending: true);

      // Fetch fallback orgs for older users
      final userOrgsResponse = await Supabase.instance.client
          .from('user_organizations')
          .select();

      Map<String, String> fallbackOrgMap = {};
      for (var item in userOrgsResponse) {
        // Assuming one main org per user or taking the last one found
        if (item['user_id'] != null && item['org_id'] != null) {
          fallbackOrgMap[item['user_id'] as String] = item['org_id'] as String;
        }
      }

      setState(() {
        // Inject fallback org ID if current_org_id is null
        _users = List<Map<String, dynamic>>.from(usersResponse).map((u) {
          if (u['current_org_id'] == null &&
              fallbackOrgMap.containsKey(u['id'])) {
            final newUser = Map<String, dynamic>.from(u);
            newUser['current_org_id'] = fallbackOrgMap[u['id']];
            return newUser;
          }
          return u;
        }).toList();

        _organisations = List<Map<String, dynamic>>.from(orgsResponse);
        _applyFilters();
        _isLoading = false;
      });
      _fadeController.forward(from: 0);
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error: $e', isError: true);
        setState(() => _isLoading = false);
      }
    }
  }

  void _applyFilters() {
    var result = _users;

    // Apply admin level filter
    final filterOption = _filterOptions.firstWhere(
      (f) => f['label'] == _selectedFilter,
      orElse: () => _filterOptions.first,
    );

    if (_selectedFilter != 'Semua') {
      if (filterOption['level'] == -1) {
        // User biasa (bukan admin)
        result = result.where((u) => u['is_admin'] != true).toList();
      } else {
        // Filter by specific admin level
        result = result
            .where((u) => u['admin_level'] == filterOption['level'])
            .toList();
      }
    }

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      result = result.where((user) {
        final nama = (user['nama'] ?? '').toLowerCase();
        final username = (user['username'] ?? '').toLowerCase();
        final query = _searchQuery.toLowerCase();
        return nama.contains(query) || username.contains(query);
      }).toList();
    }

    // --- FILTER HIERARKI (User Bawahan/Satu Lingkup) ---
    // Super Admin (0) lihat semua.
    // Admin Lain lihat user yang punya orgId yang sama atau turunannya.
    if (_currentAdminLevel > 0) {
      final myAdminOrgId = widget.currentUser?.adminOrgId;
      if (myAdminOrgId != null) {
        result = result.where((u) {
          // Cek hierarki user target
          final targetHierarchy = _getUserOrgHierarchy(u);
          // Admin Daerah (1) cek apakah user punya daerah ini
          if (_currentAdminLevel == 1) {
            return targetHierarchy['daerah'] == myAdminOrgId;
          }
          // Admin Desa (2) cek desa
          if (_currentAdminLevel == 2) {
            return targetHierarchy['desa'] == myAdminOrgId;
          }
          // Admin Kelompok (3) cek kelompok
          if (_currentAdminLevel == 3) {
            return targetHierarchy['kelompok'] == myAdminOrgId;
          }
          // Admin Kategori (4) cek kategori
          if (_currentAdminLevel == 4) {
            return targetHierarchy['kategori'] == myAdminOrgId;
          }

          return false;
        }).toList();
      }
    }

    _filteredUsers = result;
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError
            ? const Color(0xFFDC2626)
            : const Color(0xFF059669),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  String _getAdminLevelName(int? level) {
    switch (level) {
      case 0:
        return 'Super Admin';
      case 1:
        return 'Admin Daerah';
      case 2:
        return 'Admin Desa';
      case 3:
        return 'Admin Kelompok';
      case 4:
        return 'Admin Kategori';
      default:
        return 'User';
    }
  }

  String _getOrgLevelName(int level) {
    switch (level) {
      case 0:
        return 'Daerah';
      case 1:
        return 'Desa';
      case 2:
        return 'Kelompok';
      case 3:
        return 'Kategori';
      default:
        return 'Organisasi';
    }
  }

  Color _getAdminLevelColor(int? level) {
    switch (level) {
      case 0:
        return const Color(0xFF8B5CF6);
      case 1:
        return const Color(0xFF3B82F6);
      case 2:
        return const Color(0xFF06B6D4);
      case 3:
        return const Color(0xFF10B981);
      case 4:
        return const Color(0xFF84CC16);
      default:
        return const Color(0xFF6B7280);
    }
  }

  IconData _getAdminLevelIcon(int? level) {
    switch (level) {
      case 0:
        return Icons.shield;
      case 1:
        return Icons.location_city;
      case 2:
        return Icons.home_work;
      case 3:
        return Icons.groups;
      case 4:
        return Icons.category;
      default:
        return Icons.person_outline;
    }
  }

  String? _getOrgName(String? orgId) {
    if (orgId == null) return null;
    final org = _organisations.firstWhere(
      (o) => o['id'] == orgId,
      orElse: () => {},
    );
    return org.isNotEmpty ? org['name'] : null;
  }

  Future<void> _setAdminLevel(
    Map<String, dynamic> user,
    int? level,
    String? orgId,
  ) async {
    try {
      await Supabase.instance.client
          .from('users')
          .update({
            'is_admin': level != null,
            'admin_level': level,
            'admin_org_id': orgId,
          })
          .eq('id', user['id']);

      await _loadData();
      final levelName = _getAdminLevelName(level);
      final orgName = _getOrgName(orgId);
      _showSnackBar(
        level != null
            ? '${user['nama']} → $levelName${orgName != null ? ' ($orgName)' : ''}'
            : '${user['nama']} bukan admin lagi',
      );
    } catch (e) {
      _showSnackBar('Gagal: $e', isError: true);
    }
  }

  // Get user's organization hierarchy from current_org_id
  Map<String, String?> _getUserOrgHierarchy(Map<String, dynamic> user) {
    final currentOrgId = user['current_org_id'] as String?;
    if (currentOrgId == null) return {};

    // Find the user's current org
    final currentOrg = _organisations.firstWhere(
      (o) => o['id'] == currentOrgId,
      orElse: () => {},
    );
    if (currentOrg.isEmpty) return {};

    // Build hierarchy - trace up to find daerah, desa, kelompok
    Map<String, String?> hierarchy = {};

    void traceParent(Map<String, dynamic> org) {
      final level = org['level'] as int?;
      if (level == 0) hierarchy['daerah'] = org['id'];
      if (level == 1) hierarchy['desa'] = org['id'];
      if (level == 2) hierarchy['kelompok'] = org['id'];
      if (level == 3) hierarchy['kategori'] = org['id'];

      final parentId = org['parent_id'] as String?;
      if (parentId != null) {
        final parent = _organisations.firstWhere(
          (o) => o['id'] == parentId,
          orElse: () => {},
        );
        if (parent.isNotEmpty) traceParent(parent);
      }
    }

    traceParent(currentOrg);

    // Also store current level
    final currentLevel = currentOrg['level'] as int?;
    if (currentLevel == 0) hierarchy['daerah'] = currentOrgId;
    if (currentLevel == 1) hierarchy['desa'] = currentOrgId;
    if (currentLevel == 2) hierarchy['kelompok'] = currentOrgId;
    if (currentLevel == 3) hierarchy['kategori'] = currentOrgId;

    return hierarchy;
  }

  // Get categories under user's kelompok
  List<Map<String, dynamic>> _getCategoriesForUser(Map<String, dynamic> user) {
    final hierarchy = _getUserOrgHierarchy(user);
    final kelompokId = hierarchy['kelompok'];

    if (kelompokId == null) return [];

    // Get all kategori (level 3) under this kelompok
    return _organisations
        .where((org) => org['level'] == 3 && org['parent_id'] == kelompokId)
        .toList();
  }

  // Get the org ID to assign based on admin level
  String? _getAutoOrgId(Map<String, dynamic> user, int adminLevel) {
    final hierarchy = _getUserOrgHierarchy(user);
    switch (adminLevel) {
      case 1:
        return hierarchy['daerah'];
      case 2:
        return hierarchy['desa'];
      case 3:
        return hierarchy['kelompok'];
      default:
        return null;
    }
  }

  void _showUserBarcode(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            Text(
              user['nama'] ?? '-',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(
              '@${user['username'] ?? '-'}',
              style: TextStyle(color: Colors.grey[500], fontSize: 14),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1A5F2D).withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
              ),
              child: QrImageView(
                data: user['username'] ?? '',
                version: QrVersions.auto,
                size: 180.0,
                foregroundColor: const Color(0xFF1A5F2D),
              ),
            ),
            const SizedBox(height: 24),
            BarcodeWidget(
              barcode: Barcode.code128(),
              data: user['username'] ?? '',
              width: 200,
              height: 60,
              drawText: false,
              color: Colors.black87,
            ),
            const SizedBox(height: 8),
            Text(
              (user['username'] ?? '').toString().toUpperCase(),
              style: const TextStyle(
                letterSpacing: 2,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  void _showAdminLevelDialog(Map<String, dynamic> user) {
    final currentLevel = user['admin_level'] as int?;
    final isCurrentUser = user['id'] == widget.currentUser?.id;
    final userOrgHierarchy = _getUserOrgHierarchy(user);

    if (isCurrentUser) {
      _showSnackBar('Tidak bisa mengubah level admin sendiri', isError: true);
      return;
    }

    // Check if user has org hierarchy
    if (userOrgHierarchy.isEmpty) {
      _showSnackBar(
        'User belum terdaftar di organisasi manapun',
        isError: true,
      );
      return;
    }

    int? selectedLevel;
    String? selectedOrgId;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          List<int> availableLevels = [];
          // Logic: Max setara (bisa angkat sesama level atau di bawahnya)
          // Kecuali jika user target belum punya org di level tersebut, nanti divalidasi 'canSelect'
          // Level 0 (Super Admin) bisa angkat 1-4.
          // Level X bisa angkat X s.d 4.

          int startLevel = _currentAdminLevel == 0 ? 1 : _currentAdminLevel;

          for (int i = startLevel; i <= 4; i++) {
            availableLevels.add(i);
          }

          // Auto-set orgId for level 1-3
          if (selectedLevel != null &&
              selectedLevel! >= 1 &&
              selectedLevel! <= 3) {
            selectedOrgId = _getAutoOrgId(user, selectedLevel!);
          }

          // Check if selected level has valid org
          bool canSelectLevel(int level) {
            if (level >= 1 && level <= 3) {
              return _getAutoOrgId(user, level) != null;
            }
            if (level == 4) {
              return _getCategoriesForUser(user).isNotEmpty;
            }
            return true;
          }

          return Container(
            margin: const EdgeInsets.only(
              top: 60,
            ), // Beri jarak dari atas layar
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                const SizedBox(height: 16),
                Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),

                // Scrollable Content
                Flexible(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      24,
                      24,
                      24,
                      MediaQuery.of(context).viewInsets.bottom + 24,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header Box
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF059669), Color(0xFF10B981)],
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(
                                  Icons.admin_panel_settings,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Atur Level Admin',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      user['nama'] ?? '-',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.9),
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Current Status Info
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: _getAdminLevelColor(
                              currentLevel,
                            ).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: _getAdminLevelColor(
                                currentLevel,
                              ).withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _getAdminLevelIcon(currentLevel),
                                color: _getAdminLevelColor(currentLevel),
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Saat ini: ${_getAdminLevelName(currentLevel)}',
                                style: TextStyle(
                                  color: _getAdminLevelColor(currentLevel),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Level Selection Header
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Level Admin:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Color(0xFF374151),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Modern Horizontal Single Row Layout
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            mainAxisAlignment:
                                MainAxisAlignment.center, // Usahakan tengah
                            children: [
                              // 1. User Button (Singkat: "User")
                              _buildModernChip(
                                label: 'User',
                                icon: Icons.person_outline,
                                isSelected: selectedLevel == -1,
                                color: Colors.grey,
                                onTap: () => setModalState(() {
                                  selectedLevel = -1;
                                  selectedOrgId = null;
                                }),
                              ),
                              const SizedBox(width: 8),

                              // 2. Admin Levels (Daerah & Desa) -> Label: "Daerah", "Desa"
                              ...availableLevels.where((l) => l <= 2).map((
                                level,
                              ) {
                                final canSelect = canSelectLevel(level);
                                // Mapping label singkat
                                String shortLabel = '';
                                if (level == 1) shortLabel = 'Daerah';
                                if (level == 2) shortLabel = 'Desa';

                                return Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: Opacity(
                                    opacity: canSelect ? 1.0 : 0.4,
                                    child: _buildModernChip(
                                      label: shortLabel,
                                      icon: _getAdminLevelIcon(level),
                                      isSelected: selectedLevel == level,
                                      color: _getAdminLevelColor(level),
                                      onTap: canSelect
                                          ? () => setModalState(() {
                                              selectedLevel = level;
                                              selectedOrgId = _getAutoOrgId(
                                                user,
                                                level,
                                              );
                                            })
                                          : () {
                                              // Pesan error spesifik
                                              String levelName =
                                                  _getOrgLevelName(level - 1);
                                              if (level == 2 &&
                                                  _currentAdminLevel == 2) {
                                                // Admin Desa angkat Admin Desa, tapi usernya beda desa?
                                                // Harusnya gk tampil di list krn filter, tapi utk jaga2
                                                _showSnackBar(
                                                  'User harus satu $levelName',
                                                  isError: true,
                                                );
                                              } else {
                                                _showSnackBar(
                                                  'User tidak terdaftar di $levelName',
                                                  isError: true,
                                                );
                                              }
                                            },
                                    ),
                                  ),
                                );
                              }),

                              // 3. Kelompok Button (Singkat: "Kelompok")
                              if (availableLevels.contains(3))
                                Opacity(
                                  opacity: canSelectLevel(3) ? 1.0 : 0.4,
                                  child: _buildModernChip(
                                    label: 'Kelompok',
                                    icon: Icons.groups,
                                    isSelected:
                                        selectedLevel == 3 ||
                                        selectedLevel == 4,
                                    color: _getAdminLevelColor(3),
                                    onTap: canSelectLevel(3)
                                        ? () => setModalState(() {
                                            if (selectedLevel != 3 &&
                                                selectedLevel != 4) {
                                              selectedLevel = 3;
                                              selectedOrgId = _getAutoOrgId(
                                                user,
                                                3,
                                              );
                                            }
                                          })
                                        : () {
                                            _showSnackBar(
                                              'User tidak terdaftar di Kelompok',
                                              isError: true,
                                            );
                                          },
                                  ),
                                ),
                            ],
                          ),
                        ),

                        // Info Otomatis untuk Level 1-2
                        if (selectedLevel != null &&
                            selectedLevel! >= 1 &&
                            selectedLevel! <= 2) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFF059669).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(0xFF059669).withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.check_circle,
                                  color: Color(0xFF059669),
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${_getOrgLevelName(selectedLevel! - 1)} Otomatis:',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _getOrgName(selectedOrgId) ?? '-',
                                        style: const TextStyle(
                                          color: Color(0xFF059669),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // Sub-menu Bidang Tugas (Utk Kelompok & Kategori)
                        if (selectedLevel == 3 || selectedLevel == 4) ...[
                          const SizedBox(height: 24),
                          const Text(
                            'Pilih Bidang Tugas:',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF374151),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            // Hapus constraints maxHeight agar ikut scroll layout utama
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.grey[200]!),
                            ),
                            child: Column(
                              // Ganti ListView dengan Column karena sudah di dlm ScrollView
                              children: [
                                const SizedBox(height: 8),
                                // Opsi 1: Kelompok (Level 3)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  child: _buildSubOptionItem(
                                    label: 'Kelompok',
                                    isSelected: selectedLevel == 3,
                                    onTap: () => setModalState(() {
                                      selectedLevel = 3;
                                      selectedOrgId = _getAutoOrgId(user, 3);
                                    }),
                                  ),
                                ),

                                // Opsi 2: Kategori-kategori (Level 4)
                                ...() {
                                  // Filter: Sembunyikan 'Kelompok Dewasa' agar tidak duplikat konsep
                                  final cats = _getCategoriesForUser(user)
                                      .where(
                                        (c) => !(c['name'] as String)
                                            .toLowerCase()
                                            .contains('dewasa'),
                                      )
                                      .toList();

                                  cats.sort((a, b) {
                                    final nameA = (a['name'] as String)
                                        .toLowerCase();
                                    final nameB = (b['name'] as String)
                                        .toLowerCase();

                                    int score(String n) {
                                      if (n.contains('muda')) return 1;
                                      if (n.contains('pra')) return 2;
                                      if (n.contains('caberawit') ||
                                          n.contains('cabe')) {
                                        return 3;
                                      }
                                      return 4;
                                    }

                                    return score(nameA).compareTo(score(nameB));
                                  });

                                  return cats.map((cat) {
                                    final isSelected =
                                        selectedLevel == 4 &&
                                        selectedOrgId == cat['id'];
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      child: _buildSubOptionItem(
                                        label: cat['name'],
                                        isSelected: isSelected,
                                        onTap: () => setModalState(() {
                                          selectedLevel = 4;
                                          selectedOrgId = cat['id'];
                                        }),
                                      ),
                                    );
                                  });
                                }(),
                                const SizedBox(height: 8),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 32),

                        // Action Buttons
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(context),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  side: BorderSide(color: Colors.grey[300]!),
                                ),
                                child: Text(
                                  'Batal',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: ElevatedButton(
                                onPressed:
                                    (selectedLevel == -1 ||
                                        (selectedLevel != null &&
                                            selectedLevel! >= 1 &&
                                            selectedLevel! <= 3 &&
                                            selectedOrgId != null) ||
                                        (selectedLevel == 4 &&
                                            selectedOrgId != null))
                                    ? () {
                                        Navigator.pop(context);
                                        _setAdminLevel(
                                          user,
                                          selectedLevel == -1
                                              ? null
                                              : selectedLevel,
                                          selectedOrgId,
                                        );
                                      }
                                    : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF059669),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  elevation: 0,
                                ),
                                child: const Text(
                                  'Simpan Perubahan',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSubOptionItem({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: isSelected
          ? const Color(0xFF059669).withOpacity(0.1)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected
                      ? const Color(0xFF059669)
                      : Colors.transparent,
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF059669)
                        : Colors.grey[400]!,
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
                    color: isSelected
                        ? const Color(0xFF059669)
                        : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernChip({
    required String label,
    required IconData icon,
    required bool isSelected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(50),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.fromLTRB(16, 12, 20, 12),
          decoration: BoxDecoration(
            color: isSelected ? color : Colors.grey[50], // Background halus
            borderRadius: BorderRadius.circular(50), // Pill Shape
            border: Border.all(
              color: isSelected ? color : Colors.grey[300]!,
              width: 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: color.withOpacity(0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withOpacity(0.2)
                      : Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 16,
                  color: isSelected ? Colors.white : Colors.grey[500],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey[800],
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteUser(Map<String, dynamic> user) async {
    if (user['id'] == widget.currentUser?.id) {
      _showSnackBar('Tidak bisa menghapus akun sendiri', isError: true);
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.delete_forever,
                color: Colors.red,
                size: 40,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Hapus Pengguna?',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              '${user['nama']} akan dihapus secara permanen.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Batal'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Hapus'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (confirm == true) {
      try {
        await Supabase.instance.client
            .from('users')
            .delete()
            .eq('id', user['id']);
        await _loadData();
        _showSnackBar('Pengguna berhasil dihapus');
      } catch (e) {
        _showSnackBar('Gagal menghapus: $e', isError: true);
      }
    }
  }

  int _getFilterCount(String filter) {
    final filterOption = _filterOptions.firstWhere((f) => f['label'] == filter);
    if (filter == 'Semua') return _users.length;
    if (filterOption['level'] == -1) {
      return _users.where((u) => u['is_admin'] != true).length;
    }
    return _users
        .where((u) => u['admin_level'] == filterOption['level'])
        .length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // Header with gradient
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 16,
              left: 20,
              right: 20,
              bottom: 20,
            ),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF047857),
                  Color(0xFF059669),
                  Color(0xFF10B981),
                ],
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(32),
                bottomRight: Radius.circular(32),
              ),
            ),
            child: Column(
              children: [
                // Title & stats
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.people_alt,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Kelola Pengguna',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_users.length} pengguna • ${_users.where((u) => u['is_admin'] == true).length} admin',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.85),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Search bar
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) => setState(() {
                      _searchQuery = value;
                      _applyFilters();
                    }),
                    decoration: InputDecoration(
                      hintText: 'Cari nama atau username...',
                      hintStyle: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 14,
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: Colors.grey[400],
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: Icon(
                                Icons.close_rounded,
                                color: Colors.grey[400],
                              ),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchQuery = '';
                                  _applyFilters();
                                });
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Filter chips - Centered and all visible
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: _filterOptions.asMap().entries.map((entry) {
                    final index = entry.key;
                    final filter = entry.value;
                    final isSelected = _selectedFilter == filter['label'];
                    final count = _getFilterCount(filter['label']);

                    return Padding(
                      padding: EdgeInsets.only(
                        left: index == 0 ? 0 : 5,
                        right: index == _filterOptions.length - 1 ? 0 : 5,
                      ),
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _selectedFilter = filter['label'];
                          _applyFilters();
                        }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF059669)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF059669)
                                  : Colors.grey[300]!,
                              width: isSelected ? 2 : 1,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: const Color(
                                        0xFF059669,
                                      ).withOpacity(0.3),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                filter['icon'] as IconData,
                                size: 14,
                                color: isSelected
                                    ? Colors.white
                                    : Colors.grey[600],
                              ),
                              const SizedBox(width: 6),
                              Text(
                                filter['label'],
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.grey[700],
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Colors.white.withOpacity(0.25)
                                      : Colors.grey[100],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '$count',
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.grey[600],
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),

          // Content
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF059669)),
                  )
                : _filteredUsers.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
                    onRefresh: _loadData,
                    color: const Color(0xFF059669),
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                      itemCount: _filteredUsers.length,
                      itemBuilder: (context, index) =>
                          _buildUserCard(_filteredUsers[index], index),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 20,
                ),
              ],
            ),
            child: Icon(
              _searchQuery.isNotEmpty ? Icons.search_off : Icons.person_search,
              size: 52,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            _searchQuery.isNotEmpty ? 'Tidak Ditemukan' : 'Belum Ada Data',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty
                ? 'Coba kata kunci lain'
                : 'Pengguna akan muncul di sini',
            style: TextStyle(color: Colors.grey[500], fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user, int index) {
    final isAdmin = user['is_admin'] ?? false;
    final adminLevel = user['admin_level'] as int?;
    final adminOrgId = user['admin_org_id'] as String?;
    final isCurrentUser = user['id'] == widget.currentUser?.id;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 250 + (index * 30).clamp(0, 150)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 15 * (1 - value)),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => _showAdminLevelDialog(user),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Avatar
                  Stack(
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: isAdmin
                                ? [
                                    _getAdminLevelColor(adminLevel),
                                    _getAdminLevelColor(
                                      adminLevel,
                                    ).withOpacity(0.7),
                                  ]
                                : [Colors.grey[400]!, Colors.grey[500]!],
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: user['foto_profil'] != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Image.network(
                                  user['foto_profil'],
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      _buildAvatarText(user['nama']),
                                ),
                              )
                            : _buildAvatarText(user['nama']),
                      ),
                      if (isCurrentUser)
                        Positioned(
                          right: -3,
                          bottom: -3,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF3B82F6),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(
                              Icons.person,
                              color: Colors.white,
                              size: 10,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 14),

                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user['nama'] ?? '-',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '@${user['username'] ?? '-'}',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 13,
                          ),
                        ),
                        if (isAdmin) ...[
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      _getAdminLevelColor(adminLevel),
                                      _getAdminLevelColor(
                                        adminLevel,
                                      ).withOpacity(0.8),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _getAdminLevelIcon(adminLevel),
                                      size: 12,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      _getAdminLevelName(adminLevel),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (adminOrgId != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.location_on_outlined,
                                        size: 12,
                                        color: Colors.grey[600],
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        _getOrgName(adminOrgId) ?? '-',
                                        style: TextStyle(
                                          color: Colors.grey[700],
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Menu
                  PopupMenuButton<String>(
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.more_horiz,
                        color: Colors.grey[600],
                        size: 20,
                      ),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    offset: const Offset(0, 40),
                    onSelected: (value) {
                      if (value == 'admin') {
                        _showAdminLevelDialog(user);
                      } else if (value == 'barcode')
                        _showUserBarcode(user);
                      else if (value == 'delete')
                        _deleteUser(user);
                    },
                    itemBuilder: (context) => [
                      _buildPopupMenuItem(
                        'admin',
                        Icons.admin_panel_settings,
                        'Atur Level',
                        const Color(0xFF059669),
                      ),
                      _buildPopupMenuItem(
                        'barcode',
                        Icons.qr_code_2_rounded,
                        'Lihat Barcode',
                        const Color(0xFF1A5F2D),
                      ),
                      _buildPopupMenuItem(
                        'delete',
                        Icons.delete_outline,
                        'Hapus',
                        Colors.red,
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

  Widget _buildAvatarText(String? nama) {
    return Center(
      child: Text(
        (nama ?? '?')[0].toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  PopupMenuItem<String> _buildPopupMenuItem(
    String value,
    IconData icon,
    String label,
    Color color,
  ) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 14),
          Text(
            label,
            style: TextStyle(
              color: value == 'delete' ? color : Colors.black87,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
