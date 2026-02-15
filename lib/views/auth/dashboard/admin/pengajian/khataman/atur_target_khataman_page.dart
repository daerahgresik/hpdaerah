import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hpdaerah/models/user_model.dart';
import 'package:hpdaerah/models/kelas_model.dart';
import 'package:hpdaerah/models/master_target_khataman_model.dart';
import 'package:hpdaerah/services/kelas_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Atur Target Khataman - Compact & Mobile Friendly
class AturTargetKhatamanPage extends StatefulWidget {
  final UserModel user;
  final String orgId;

  const AturTargetKhatamanPage({
    super.key,
    required this.user,
    required this.orgId,
  });

  @override
  State<AturTargetKhatamanPage> createState() => _AturTargetKhatamanPageState();
}

class _AturTargetKhatamanPageState extends State<AturTargetKhatamanPage> {
  final _supabase = Supabase.instance.client;
  final _kelasService = KelasService();

  List<Kelas> _kelasList = [];
  List<Map<String, dynamic>> _userList = [];
  List<Map<String, dynamic>> _kelasAssignments = [];
  List<Map<String, dynamic>> _userAssignments = [];
  List<MasterTargetKhataman> _masterTargets = [];

  // New: Filter & search state
  List<Map<String, dynamic>> _desaList = [];
  List<Map<String, dynamic>> _kelompokList = [];
  String _searchQuery = '';
  String? _filterDesaId;
  String? _filterKelompokId;
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  int _selectedTab = 0; // 0 = Kelas, 1 = Nama User

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final level = widget.user.adminLevel ?? 3;
    debugPrint(
      '[Khataman] Loading data... orgId=${widget.orgId}, adminLevel=$level',
    );

    // Load kelas list (independent)
    try {
      final kelasList = await _kelasService.fetchKelasInHierarchy(
        orgId: widget.orgId,
        adminLevel: level,
      );
      debugPrint('[Khataman] Loaded ${kelasList.length} kelas');
      if (mounted) setState(() => _kelasList = kelasList);
    } catch (e) {
      debugPrint('[Khataman] Error loading kelas: $e');
    }

    // Load master targets (independent)
    try {
      final masterResponse = await _supabase
          .from('master_target_khataman')
          .select()
          .eq('org_id', widget.orgId)
          .eq('is_active', true)
          .order('nama');
      debugPrint(
        '[Khataman] Loaded ${(masterResponse as List).length} master targets',
      );
      if (mounted) {
        setState(() {
          _masterTargets = (masterResponse as List)
              .map((e) => MasterTargetKhataman.fromJson(e))
              .toList();
        });
      }
    } catch (e) {
      debugPrint('[Khataman] Error loading master targets: $e');
    }

    // Load user list (independent)
    try {
      String orgColumn = 'org_kelompok_id';
      if (level == 1) {
        orgColumn = 'org_daerah_id';
      } else if (level == 2) {
        orgColumn = 'org_desa_id';
      }

      final userResponse = await _supabase
          .from('users')
          .select('''
            id, nama, 
            org_kategori_id,
            org_kategori:org_kategori_id(nama),
            org_kelompok_id,
            org_kelompok:org_kelompok_id(nama),
            org_desa_id,
            org_desa:org_desa_id(nama)
          ''')
          .eq(orgColumn, widget.orgId)
          .order('nama');
      if (mounted) {
        setState(() {
          _userList = List<Map<String, dynamic>>.from(userResponse as List);
        });
      }
    } catch (e) {
      debugPrint('[Khataman] Error loading users: $e');
    }

    // Load kelas assignments (independent)
    try {
      final kelasAssignments = await _supabase
          .from('khataman_assignment')
          .select(
            'id, kelas_id, master_target_id, master_target_khataman(nama, jumlah_halaman)',
          )
          .eq('org_id', widget.orgId)
          .eq('target_type', 'kelas')
          .eq('is_active', true);
      if (mounted) {
        setState(() {
          _kelasAssignments = List<Map<String, dynamic>>.from(
            kelasAssignments as List,
          );
        });
      }
    } catch (e) {
      debugPrint('[Khataman] Error loading kelas assignments: $e');
    }

    // Load user assignments (independent)
    try {
      final userAssignments = await _supabase
          .from('khataman_assignment')
          .select(
            'id, user_id, master_target_id, master_target_khataman(nama, jumlah_halaman)',
          )
          .eq('org_id', widget.orgId)
          .eq('target_type', 'user')
          .eq('is_active', true);
      if (mounted) {
        setState(() {
          _userAssignments = List<Map<String, dynamic>>.from(
            userAssignments as List,
          );
        });
      }
    } catch (e) {
      debugPrint('[Khataman] Error loading user assignments: $e');
    }

    // Load filter lists
    try {
      if (level == 1) {
        final desaList = await _kelasService.getDesaListForFilter(widget.orgId);
        if (mounted) setState(() => _desaList = desaList);
      }
      if (level <= 2) {
        final kelompokList = await _kelasService.getKelompokListForFilter(
          orgId: widget.orgId,
          adminLevel: level,
        );
        if (mounted) setState(() => _kelompokList = kelompokList);
      }
    } catch (e) {
      debugPrint('[Khataman] Error loading filter lists: $e');
    }

    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Tab Selector
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Expanded(child: _buildTab('Kelas', Icons.school, 0)),
              Expanded(child: _buildTab('Nama User', Icons.person, 1)),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Content based on tab
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          )
        else
          _selectedTab == 0 ? _buildKelasContent() : _buildUserContent(),
      ],
    );
  }

  Widget _buildTab(String label, IconData icon, int index) {
    final isActive = _selectedTab == index;
    return InkWell(
      onTap: () => setState(() => _selectedTab = index),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isActive ? const Color(0xFF1A5F2D) : Colors.grey,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isActive ? const Color(0xFF1A5F2D) : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKelasContent() {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.amber.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.amber.shade100),
          ),
          child: Row(
            children: [
              Icon(Icons.school, color: Colors.amber.shade700, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Target Kelas (${_kelasList.length} kelas)',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.amber.shade800,
                    fontSize: 13,
                  ),
                ),
              ),
              InkWell(
                onTap: () => _showAddKelasDialog(),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade700,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add, size: 14, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(
                        'Tambah',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // List assignments or empty
        if (_kelasAssignments.isEmpty)
          _buildEmptyState('Belum ada target kelas', Icons.school_outlined)
        else
          ..._kelasAssignments.map((a) => _buildAssignmentItem(a, 'kelas')),
      ],
    );
  }

  Widget _buildUserContent() {
    // Filter users based on search and selected filters
    List<Map<String, dynamic>> filteredUsers = _userList.where((user) {
      final nama = (user['nama'] as String? ?? '').toLowerCase();
      final matchesSearch =
          _searchQuery.isEmpty || nama.contains(_searchQuery.toLowerCase());

      final matchesDesa =
          _filterDesaId == null || user['org_desa_id'] == _filterDesaId;
      final matchesKelompok =
          _filterKelompokId == null ||
          user['org_kelompok_id'] == _filterKelompokId;

      return matchesSearch && matchesDesa && matchesKelompok;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with count and add button
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.teal.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.teal.shade100),
          ),
          child: Row(
            children: [
              Icon(Icons.person, color: Colors.teal.shade700, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Nama User (${filteredUsers.length} dari ${_userList.length})',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.teal.shade800,
                    fontSize: 13,
                  ),
                ),
              ),
              InkWell(
                onTap: _userList.isEmpty ? null : () => _showAddUserDialog(),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _userList.isEmpty
                        ? Colors.grey.shade300
                        : Colors.teal.shade700,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add, size: 14, color: Colors.white),
                      SizedBox(width: 4),
                      Text(
                        'Tambah',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Search Bar
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Cari nama user...',
            hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
            prefixIcon: const Icon(Icons.search, size: 20),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  )
                : null,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
          ),
          style: const TextStyle(fontSize: 13),
          onChanged: (val) => setState(() => _searchQuery = val),
        ),
        const SizedBox(height: 10),

        // Filter Row
        if (widget.user.adminLevel! <= 2)
          Row(
            children: [
              // Desa Filter (for Admin Daerah only)
              if (widget.user.adminLevel == 1) ...[
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _filterDesaId,
                        hint: const Text(
                          'Semua Desa',
                          style: TextStyle(fontSize: 12),
                        ),
                        isExpanded: true,
                        icon: const Icon(Icons.arrow_drop_down, size: 18),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black87,
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('Semua Desa'),
                          ),
                          ..._desaList.map(
                            (d) => DropdownMenuItem(
                              value: d['id'] as String,
                              child: Text(
                                d['name'] as String,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                        onChanged: (val) async {
                          setState(() {
                            _filterDesaId = val;
                            _filterKelompokId = null;
                          });
                          // Reload kelompok list based on selected desa
                          if (val != null) {
                            final kelompoks = await _kelasService
                                .getKelompokListForFilter(
                                  orgId: widget.orgId,
                                  adminLevel: 1,
                                  filterDesaId: val,
                                );
                            setState(() => _kelompokList = kelompoks);
                          } else {
                            setState(() => _kelompokList = []);
                          }
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              // Kelompok Filter
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _filterKelompokId,
                      hint: const Text(
                        'Semua Kelompok',
                        style: TextStyle(fontSize: 12),
                      ),
                      isExpanded: true,
                      icon: const Icon(Icons.arrow_drop_down, size: 18),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black87,
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('Semua Kelompok'),
                        ),
                        ..._kelompokList.map(
                          (k) => DropdownMenuItem(
                            value: k['id'] as String,
                            child: Text(
                              k['name'] as String,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                      onChanged: (val) =>
                          setState(() => _filterKelompokId = val),
                    ),
                  ),
                ),
              ),
            ],
          ),

        if (widget.user.adminLevel! <= 2) const SizedBox(height: 12),

        // User List - Grouped by Kelas when not searching
        if (filteredUsers.isEmpty)
          _buildEmptyState('Tidak ada user ditemukan', Icons.person_outline)
        else if (_searchQuery.isEmpty &&
            _filterDesaId == null &&
            _filterKelompokId == null)
          // Grouped View by Kelas
          ..._buildGroupedUserList(filteredUsers)
        else
          // Flat List when searching/filtering
          ...filteredUsers.map((u) => _buildUserCard(u)),
      ],
    );
  }

  // Build grouped user list by Kelas hierarchy
  List<Widget> _buildGroupedUserList(List<Map<String, dynamic>> users) {
    // Group users by kelas
    final Map<String, List<Map<String, dynamic>>> groupedByKelas = {};

    for (final user in users) {
      final kelasName =
          (user['org_kategori'] as Map?)?['nama'] as String? ?? 'Tanpa Kelas';
      groupedByKelas.putIfAbsent(kelasName, () => []).add(user);
    }

    // Sort kelas names and build widgets
    final sortedKelas = groupedByKelas.keys.toList()..sort();

    List<Widget> widgets = [];
    for (final kelasName in sortedKelas) {
      final kelasUsers = groupedByKelas[kelasName]!;
      widgets.add(
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8),
            ],
          ),
          child: Theme(
            data: ThemeData().copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 4,
              ),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.school,
                  color: Colors.amber.shade700,
                  size: 16,
                ),
              ),
              title: Text(
                kelasName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              subtitle: Text(
                '${kelasUsers.length} user',
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
              children: kelasUsers
                  .map((u) => _buildUserCard(u, compact: true))
                  .toList(),
            ),
          ),
        ),
      );
    }
    return widgets;
  }

  // Build user card with hierarchy info
  Widget _buildUserCard(Map<String, dynamic> user, {bool compact = false}) {
    final nama = user['nama'] as String? ?? 'Unknown';
    final kelasName = (user['org_kategori'] as Map?)?['nama'] as String?;
    final kelompokName = (user['org_kelompok'] as Map?)?['nama'] as String?;
    final desaName = (user['org_desa'] as Map?)?['nama'] as String?;

    return Container(
      margin: EdgeInsets.only(
        bottom: compact ? 0 : 8,
        left: compact ? 12 : 0,
        right: compact ? 12 : 0,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 12,
        vertical: compact ? 8 : 10,
      ),
      decoration: compact
          ? null
          : BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6),
              ],
            ),
      child: Row(
        children: [
          if (!compact)
            Container(
              padding: const EdgeInsets.all(8),
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                color: Colors.teal.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.person, color: Colors.teal.shade700, size: 16),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nama,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: compact ? 12 : 13,
                  ),
                ),
                const SizedBox(height: 2),
                Wrap(
                  spacing: 6,
                  runSpacing: 2,
                  children: [
                    if (kelasName != null && !compact)
                      _buildInfoChip(Icons.school, kelasName, Colors.amber),
                    if (kelompokName != null)
                      _buildInfoChip(
                        Icons.group_work,
                        kelompokName,
                        Colors.blue,
                      ),
                    if (desaName != null)
                      _buildInfoChip(
                        Icons.location_city,
                        desaName,
                        Colors.green,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper: Info chip for user card
  Widget _buildInfoChip(IconData icon, String label, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color.shade700),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, size: 32, color: Colors.grey[400]),
          const SizedBox(height: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[500],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssignmentItem(Map<String, dynamic> assignment, String type) {
    final target =
        assignment['master_target_khataman'] as Map<String, dynamic>?;
    final targetNama = target?['nama'] ?? 'Unknown';
    final targetHalaman = target?['jumlah_halaman'] ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6),
        ],
      ),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: type == 'kelas'
                ? Colors.amber.shade100
                : Colors.teal.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            type == 'kelas' ? Icons.school : Icons.person,
            color: type == 'kelas'
                ? Colors.amber.shade700
                : Colors.teal.shade700,
            size: 18,
          ),
        ),
        title: Text(
          targetNama,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        subtitle: Text(
          '$targetHalaman halaman',
          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
        ),
        trailing: IconButton(
          icon: Icon(
            Icons.delete_outline,
            size: 18,
            color: Colors.red.shade300,
          ),
          onPressed: () => _deleteAssignment(assignment['id']),
        ),
      ),
    );
  }

  void _showAddKelasDialog() {
    Kelas? selectedKelas;
    Kelas? selectedSubKelas;
    MasterTargetKhataman? selectedMasterTarget;
    final halamanController = TextEditingController();

    // Default ke level admin
    int selectedOrgLevel = widget.user.adminLevel == 1
        ? 1
        : (widget.user.adminLevel == 2 ? 2 : 3);

    // Filter state
    String? selectedDesaId;
    String? selectedKelompokId;
    List<Kelas> filteredKelasList = [];
    List<Kelas> subKelasList = [];

    bool isLoadingFilter = false;
    bool isLoadingSubKelas = false;
    bool initialLoaded = false;

    // Helper: get parent kelas from _kelasList
    List<Kelas> getParentKelas() =>
        _kelasList.where((k) => k.parentKelasId == null).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          // Helper: apply filter based on tingkat
          void applyFilter() {
            final parents = getParentKelas();

            if (selectedOrgLevel == 1) {
              // Daerah = semua kelas
              filteredKelasList = parents;
            } else if (selectedOrgLevel == 2) {
              // Desa = filter by desa
              if (selectedDesaId != null) {
                // Filter kelas yang kelompoknya ada di desa ini
                // Kelas punya orgKelompokId, kelompok punya parent desa
                // Cara filter: pakai _kelompokList yang punya desa info
                final kelompokIdsInDesa = _kelompokList
                    .where((k) => k['desa_id'] == selectedDesaId)
                    .map((k) => k['id'] as String)
                    .toSet();
                filteredKelasList = parents
                    .where(
                      (k) =>
                          k.orgKelompokId != null &&
                          kelompokIdsInDesa.contains(k.orgKelompokId),
                    )
                    .toList();
              } else {
                filteredKelasList = [];
              }
            } else {
              // Kelompok = filter by kelompok
              if (selectedKelompokId != null) {
                filteredKelasList = parents
                    .where((k) => k.orgKelompokId == selectedKelompokId)
                    .toList();
              } else {
                filteredKelasList = [];
              }
            }
          }

          // Initial load
          if (!initialLoaded) {
            initialLoaded = true;
            applyFilter();
            debugPrint(
              '[Khataman Dialog] Initial: level=$selectedOrgLevel, _kelasList=${_kelasList.length}, filtered=${filteredKelasList.length}, masterTargets=${_masterTargets.length}',
            );
          }

          // Helper: reset saat ganti tingkat
          void onOrgLevelChanged(int level) {
            setSheetState(() {
              selectedOrgLevel = level;
              selectedDesaId = null;
              selectedKelompokId = null;
              selectedKelas = null;
              selectedSubKelas = null;
              subKelasList = [];
              applyFilter();
            });
          }

          // Helper: load sub-kelas saat parent dipilih
          void onKelasSelected(Kelas? kelas) {
            setSheetState(() {
              selectedKelas = kelas;
              selectedSubKelas = null;
              subKelasList = [];
            });

            if (kelas != null) {
              setSheetState(() => isLoadingSubKelas = true);
              _kelasService.fetchSubKelas(kelas.id).then((children) {
                if (context.mounted) {
                  setSheetState(() {
                    subKelasList = children;
                    isLoadingSubKelas = false;
                  });
                }
              });
            }
          }

          return Container(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Target untuk Kelas',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),

                  // === CHIP SELECTOR TINGKAT ===
                  if (widget.user.adminLevel! <= 2) ...[
                    const Text(
                      'Pilih Tingkat',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        if (widget.user.adminLevel == 1)
                          _buildLevelChip(
                            'Daerah',
                            Icons.domain,
                            1,
                            selectedOrgLevel,
                            onOrgLevelChanged,
                            setSheetState,
                          ),
                        _buildLevelChip(
                          'Desa',
                          Icons.location_city,
                          2,
                          selectedOrgLevel,
                          onOrgLevelChanged,
                          setSheetState,
                        ),
                        _buildLevelChip(
                          'Kelompok',
                          Icons.group_work,
                          3,
                          selectedOrgLevel,
                          onOrgLevelChanged,
                          setSheetState,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],

                  // === DROPDOWN KELAS ===
                  DropdownButtonFormField<Kelas>(
                    decoration: InputDecoration(
                      labelText: 'Pilih Kelas',
                      prefixIcon: const Icon(Icons.school, size: 20),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      isDense: true,
                    ),
                    isExpanded: true,
                    value: selectedKelas,
                    items: filteredKelasList.isEmpty
                        ? []
                        : filteredKelasList
                              .map(
                                (k) => DropdownMenuItem(
                                  value: k,
                                  child: Text(
                                    k.nama,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ),
                              )
                              .toList(),
                    onChanged: onKelasSelected,
                    hint: isLoadingFilter
                        ? const Text(
                            'Loading...',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          )
                        : null,
                  ),

                  // === DROPDOWN SUB-KELAS (jika ada) ===
                  if (isLoadingSubKelas) ...[
                    const SizedBox(height: 12),
                    const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ] else if (subKelasList.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<Kelas>(
                      decoration: InputDecoration(
                        labelText: 'Pilih Sub-Kelas',
                        prefixIcon: const Icon(
                          Icons.subdirectory_arrow_right,
                          size: 20,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        isDense: true,
                      ),
                      isExpanded: true,
                      value: selectedSubKelas,
                      items: subKelasList
                          .map(
                            (k) => DropdownMenuItem(
                              value: k,
                              child: Text(
                                k.nama,
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (val) =>
                          setSheetState(() => selectedSubKelas = val),
                      hint: const Text(
                        'Pilih sub-kelas (opsional)',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ),
                  ],

                  const SizedBox(height: 12),

                  // Pilih Target dari Master
                  DropdownButtonFormField<MasterTargetKhataman>(
                    decoration: InputDecoration(
                      labelText: 'Pilih Target',
                      prefixIcon: const Icon(Icons.auto_stories, size: 20),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      isDense: true,
                    ),
                    isExpanded: true,
                    value: selectedMasterTarget,
                    items: _masterTargets
                        .map(
                          (t) => DropdownMenuItem(
                            value: t,
                            child: Text(
                              '${t.nama} (${t.jumlahHalaman} hal)',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (val) {
                      setSheetState(() {
                        selectedMasterTarget = val;
                        if (val != null) {
                          halamanController.text = val.jumlahHalaman.toString();
                        }
                      });
                    },
                    hint: _masterTargets.isEmpty
                        ? const Text(
                            'Belum ada target di Master',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          )
                        : null,
                  ),
                  const SizedBox(height: 12),

                  // Target Halaman (auto-filled, editable)
                  TextField(
                    controller: halamanController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: 'Target Halaman',
                      hintText: 'Contoh: 604',
                      prefixIcon: const Icon(Icons.menu_book, size: 20),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      isDense: true,
                    ),
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 16),

                  // Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text('Batal'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            if (selectedKelas == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Pilih kelas!'),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                              return;
                            }
                            if (selectedMasterTarget == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Pilih target!'),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                              return;
                            }
                            final halaman =
                                int.tryParse(halamanController.text.trim()) ??
                                0;
                            if (halaman <= 0) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Masukkan target halaman!'),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                              return;
                            }

                            // Gunakan sub-kelas jika dipilih, kalau tidak pakai parent
                            final targetKelas =
                                selectedSubKelas ?? selectedKelas!;

                            Navigator.pop(ctx);
                            await _saveKelasTargetWithMaster(
                              targetKelas,
                              selectedMasterTarget!,
                              halaman,
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1A5F2D),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text('Simpan'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLevelChip(
    String label,
    IconData icon,
    int level,
    int selectedLevel,
    Function(int) onChanged,
    StateSetter setSheetState,
  ) {
    final isSelected = level == selectedLevel;
    return InkWell(
      onTap: () => onChanged(level),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF1A5F2D).withOpacity(0.1)
              : Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF1A5F2D) : Colors.grey[300]!,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? const Color(0xFF1A5F2D) : Colors.grey[600],
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? const Color(0xFF1A5F2D) : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddUserDialog() {
    Map<String, dynamic>? selectedUser;
    final halamanController = TextEditingController();
    final namaTargetController = TextEditingController(text: 'Al-Quran');

    // Cascading state
    String? selectedDesaId;
    String? selectedKelompokId;

    List<Map<String, dynamic>> desaList = [];
    List<Map<String, dynamic>> kelompokList = [];
    List<Map<String, dynamic>> filteredUserList = [];

    bool isLoadingFilter = false;

    // Helper untuk reset selection bawahnya
    void resetKelompok() {
      selectedKelompokId = null;
      kelompokList = [];
      selectedUser = null;
      filteredUserList = [];
    }

    void resetUser() {
      selectedUser = null;
      filteredUserList = [];
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          // Initial Load Logic (Run once)
          if (widget.user.adminLevel == 1 &&
              desaList.isEmpty &&
              !isLoadingFilter) {
            isLoadingFilter = true;
            _kelasService.getDesaListForFilter(widget.orgId).then((data) {
              if (context.mounted) {
                setSheetState(() {
                  desaList = data;
                  isLoadingFilter = false;
                });
              }
            });
          } else if (widget.user.adminLevel == 2 &&
              kelompokList.isEmpty &&
              !isLoadingFilter) {
            isLoadingFilter = true;
            // Admin Desa langsung load kelompok
            _kelasService
                .getKelompokListForFilter(orgId: widget.orgId, adminLevel: 2)
                .then((data) {
                  if (context.mounted) {
                    setSheetState(() {
                      kelompokList = data;
                      isLoadingFilter = false;
                    });
                  }
                });
          } else if (widget.user.adminLevel == 3 &&
              filteredUserList.isEmpty &&
              !isLoadingFilter) {
            // Admin Kelompok langsung load user (atau pakai _userList yang sudah ada)
            filteredUserList = _userList;
          }

          return Container(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                const Text(
                  'Target untuk User',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),

                // === CASCADING DROPDOWNS ===

                // 1. Dropdown Desa (Only for Admin Daerah)
                if (widget.user.adminLevel == 1) ...[
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: 'Pilih Desa',
                      prefixIcon: const Icon(Icons.location_city, size: 20),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      isDense: true,
                    ),
                    isExpanded: true,
                    value: selectedDesaId,
                    items: desaList
                        .map(
                          (d) => DropdownMenuItem(
                            value: d['id'] as String,
                            child: Text(
                              d['name'] as String,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (val) async {
                      if (val == selectedDesaId) return;
                      setSheetState(() {
                        selectedDesaId = val;
                        resetKelompok();
                        isLoadingFilter = true;
                      });

                      if (val != null) {
                        final kelompoks = await _kelasService
                            .getKelompokListForFilter(
                              orgId: widget.orgId,
                              adminLevel: 1,
                              filterDesaId: val,
                            );
                        if (context.mounted) {
                          setSheetState(() {
                            kelompokList = kelompoks;
                            isLoadingFilter = false;
                          });
                        }
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                ],

                // 2. Dropdown Kelompok (For Admin Daerah & Desa)
                if (widget.user.adminLevel! <= 2) ...[
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: 'Pilih Kelompok',
                      prefixIcon: const Icon(Icons.group_work, size: 20),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      isDense: true,
                      enabled:
                          widget.user.adminLevel == 2 || selectedDesaId != null,
                    ),
                    isExpanded: true,
                    value: selectedKelompokId,
                    items: kelompokList
                        .map(
                          (k) => DropdownMenuItem(
                            value: k['id'] as String,
                            child: Text(
                              k['name'] as String,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (val) async {
                      if (val == selectedKelompokId) return;
                      setSheetState(() {
                        selectedKelompokId = val;
                        resetUser();
                        isLoadingFilter = true;
                      });

                      // Load Users based on Kelompok
                      if (val != null) {
                        final users = await _supabase
                            .from('users')
                            .select('id, nama')
                            .eq('org_kelompok_id', val)
                            .order('nama');

                        if (context.mounted) {
                          setSheetState(() {
                            filteredUserList = List<Map<String, dynamic>>.from(
                              users,
                            );
                            isLoadingFilter = false;
                          });
                        }
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                ],

                // 3. Dropdown User
                DropdownButtonFormField<Map<String, dynamic>>(
                  decoration: InputDecoration(
                    labelText: 'Pilih User',
                    prefixIcon: const Icon(Icons.person, size: 20),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    isDense: true,
                  ),
                  isExpanded: true,
                  value: selectedUser,
                  items: filteredUserList
                      .map(
                        (u) => DropdownMenuItem(
                          value: u,
                          child: Text(
                            u['nama'] ?? '-',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (val) => setSheetState(() => selectedUser = val),
                  hint: isLoadingFilter
                      ? const Text(
                          'Loading...',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        )
                      : null,
                ),
                const SizedBox(height: 12),

                // Nama target
                TextField(
                  controller: namaTargetController,
                  decoration: InputDecoration(
                    labelText: 'Nama Target',
                    hintText: 'Contoh: Al-Quran',
                    prefixIcon: const Icon(Icons.auto_stories, size: 20),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    isDense: true,
                  ),
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 12),

                // Target Halaman
                TextField(
                  controller: halamanController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Target Halaman',
                    hintText: 'Contoh: 604',
                    prefixIcon: const Icon(Icons.menu_book, size: 20),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    isDense: true,
                  ),
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 16),

                // Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text('Batal'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          if (selectedUser == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Pilih user!'),
                                backgroundColor: Colors.orange,
                              ),
                            );
                            return;
                          }
                          final halaman =
                              int.tryParse(halamanController.text.trim()) ?? 0;
                          if (halaman <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Masukkan target halaman!'),
                                backgroundColor: Colors.orange,
                              ),
                            );
                            return;
                          }

                          Navigator.pop(ctx);
                          await _saveUserTarget(
                            selectedUser!,
                            namaTargetController.text.trim(),
                            halaman,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1A5F2D),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text('Simpan'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _saveKelasTargetWithMaster(
    Kelas kelas,
    MasterTargetKhataman masterTarget,
    int halaman,
  ) async {
    try {
      // Create assignment using selected master target
      await _supabase.from('khataman_assignment').insert({
        'org_id': widget.orgId,
        'master_target_id': masterTarget.id,
        'kelas_id': kelas.id,
        'target_type': 'kelas',
        'created_by': widget.user.id,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Target kelas ditambahkan!'),
            backgroundColor: Colors.green,
          ),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _saveUserTarget(
    Map<String, dynamic> user,
    String namaTarget,
    int halaman,
  ) async {
    try {
      // First create or get master target
      final masterTarget = await _getOrCreateMasterTarget(namaTarget, halaman);

      // Then create assignment
      await _supabase.from('khataman_assignment').insert({
        'org_id': widget.orgId,
        'master_target_id': masterTarget['id'],
        'user_id': user['id'],
        'target_type': 'user',
        'created_by': widget.user.id,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Target user ditambahkan!'),
            backgroundColor: Colors.green,
          ),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<Map<String, dynamic>> _getOrCreateMasterTarget(
    String nama,
    int halaman,
  ) async {
    // Check if exists
    final existing = await _supabase
        .from('master_target_khataman')
        .select()
        .eq('org_id', widget.orgId)
        .eq('nama', nama)
        .eq('jumlah_halaman', halaman)
        .eq('is_active', true)
        .maybeSingle();

    if (existing != null) return existing;

    // Create new
    final result = await _supabase
        .from('master_target_khataman')
        .insert({
          'org_id': widget.orgId,
          'nama': nama,
          'jumlah_halaman': halaman,
          'created_by': widget.user.id,
        })
        .select()
        .single();

    return result;
  }

  Future<void> _deleteAssignment(String id) async {
    try {
      await _supabase
          .from('khataman_assignment')
          .update({'is_active': false})
          .eq('id', id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Target dihapus!'),
            backgroundColor: Colors.orange,
          ),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
