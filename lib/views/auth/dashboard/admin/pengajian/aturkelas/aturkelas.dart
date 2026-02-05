import 'package:flutter/material.dart';
import 'package:hpdaerah/models/user_model.dart';
import 'package:hpdaerah/models/kelas_model.dart';
import 'package:hpdaerah/models/aggregated_kelas_model.dart';
import 'package:hpdaerah/models/organization_model.dart';
import 'package:hpdaerah/services/kelas_service.dart';
import 'package:hpdaerah/services/organization_service.dart';

/// View Mode untuk admin level tinggi
enum ViewMode { overview, specific }

class AturKelasPage extends StatefulWidget {
  final UserModel user;
  final String orgId;

  const AturKelasPage({super.key, required this.user, required this.orgId});

  @override
  State<AturKelasPage> createState() => _AturKelasPageState();
}

class _AturKelasPageState extends State<AturKelasPage> {
  final _kelasService = KelasService();
  final _orgService = OrganizationService();

  // State - Common
  bool _isLoading = true;
  int get _adminLevel => widget.user.adminLevel ?? 4;

  // State - View Mode (for admin level <= 2)
  ViewMode _viewMode = ViewMode.overview;

  // State - Overview Mode
  List<AggregatedKelas> _aggregatedKelas = [];
  HierarchyStats _stats = HierarchyStats.empty();
  List<Map<String, dynamic>> _desaFilter = [];
  List<Map<String, dynamic>> _kelompokFilter = [];
  String? _filterDesaId;
  Set<String> _expandedCards = {};

  // State - Specific Mode (per kelompok)
  List<Kelas> _kelasList = [];
  List<Organization> _desaList = [];
  List<Organization> _kelompokList = [];
  List<Map<String, dynamic>> _unassignedUsers = [];
  String? _selectedDesaId;
  String? _selectedKelompokId;
  Map<String, int> _memberCounts = {};

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    if (_adminLevel == 3) {
      // Admin Kelompok - langsung load kelas, tidak ada toggle mode
      _selectedKelompokId = widget.orgId;
      await _loadKelas();
    } else if (_adminLevel <= 2) {
      // Admin Desa/Daerah - default Overview Mode
      await _loadOverviewData();
      await _loadFilters();
    }

    if (mounted) setState(() => _isLoading = false);
  }

  // ==================== OVERVIEW MODE METHODS ====================

  Future<void> _loadOverviewData() async {
    try {
      _aggregatedKelas = await _kelasService.fetchAggregatedKelas(
        orgId: widget.orgId,
        adminLevel: _adminLevel,
        filterDesaId: _filterDesaId,
      );
      _stats = await _kelasService.getHierarchyStats(
        orgId: widget.orgId,
        adminLevel: _adminLevel,
        filterDesaId: _filterDesaId,
      );
    } catch (e) {
      debugPrint("Error loading overview: $e");
    }
  }

  Future<void> _loadFilters() async {
    try {
      if (_adminLevel == 1) {
        _desaFilter = await _kelasService.getDesaListForFilter(widget.orgId);
      }
      _kelompokFilter = await _kelasService.getKelompokListForFilter(
        orgId: widget.orgId,
        adminLevel: _adminLevel,
        filterDesaId: _filterDesaId,
      );
    } catch (e) {
      debugPrint("Error loading filters: $e");
    }
  }

  void _onDesaFilterChanged(String? desaId) async {
    setState(() {
      _filterDesaId = desaId;
      _isLoading = true;
    });

    await _loadOverviewData();
    _kelompokFilter = await _kelasService.getKelompokListForFilter(
      orgId: widget.orgId,
      adminLevel: _adminLevel,
      filterDesaId: _filterDesaId,
    );

    if (mounted) setState(() => _isLoading = false);
  }

  // ==================== SPECIFIC MODE METHODS ====================

  Future<void> _loadDesaList() async {
    if (_adminLevel == 1) {
      final children = await _orgService.fetchChildren(widget.orgId);
      _desaList = children.where((o) => o.level == 1).toList();
    } else if (_adminLevel == 2) {
      _selectedDesaId = widget.orgId;
      await _loadKelompokList(_selectedDesaId!);
    }
    setState(() {});
  }

  Future<void> _loadKelompokList(String desaId) async {
    final children = await _orgService.fetchChildren(desaId);
    setState(() {
      _kelompokList = children.where((o) => o.level == 2).toList();
      _selectedKelompokId = null;
      _kelasList = [];
    });
  }

  Future<void> _loadKelas() async {
    if (_selectedKelompokId == null) return;
    if (!mounted) return;

    setState(() => _isLoading = true);
    try {
      _kelasList = await _kelasService.fetchKelasByKelompok(
        _selectedKelompokId!,
      );
      _memberCounts = await _kelasService.getKelasMemberCounts(
        _selectedKelompokId!,
      );
      _unassignedUsers = await _kelasService.getUnassignedUsers(
        _selectedKelompokId!,
      );
    } catch (e) {
      debugPrint("Error loading kelas: $e");
    }

    if (mounted) setState(() => _isLoading = false);
  }

  void _switchToOverview() async {
    setState(() {
      _viewMode = ViewMode.overview;
      _isLoading = true;
    });

    await _loadOverviewData();
    if (mounted) setState(() => _isLoading = false);
  }

  void _switchToSpecific() async {
    setState(() {
      _viewMode = ViewMode.specific;
      _isLoading = true;
    });

    await _loadDesaList();
    if (mounted) setState(() => _isLoading = false);
  }

  // ==================== BUILD METHODS ====================

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        const SizedBox(height: 16),

        // Mode Toggle untuk admin level tinggi
        if (_adminLevel <= 2) ...[
          _buildModeToggle(),
          const SizedBox(height: 16),
        ],

        // Content berdasarkan mode
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_adminLevel == 3)
          _buildSpecificContent()
        else if (_viewMode == ViewMode.overview)
          _buildOverviewContent()
        else
          _buildSpecificContent(),
      ],
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.teal.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.school_rounded, color: Colors.teal, size: 24),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Atur Kelas",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              Text(
                _adminLevel == 3
                    ? "Kelola kelas pengajian"
                    : "Lihat & kelola kelas di seluruh wilayah",
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
        // Tombol tambah kelas
        if (_viewMode == ViewMode.specific && _selectedKelompokId != null)
          ElevatedButton.icon(
            onPressed: () => _showAddEditDialog(),
            icon: const Icon(Icons.add, size: 18),
            label: const Text("Tambah"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          )
        else if (_viewMode == ViewMode.overview && _adminLevel <= 2)
          _buildOverviewAddButton(),
      ],
    );
  }

  Widget _buildOverviewAddButton() {
    return PopupMenuButton<String>(
      onSelected: (kelompokId) {
        setState(() {
          _selectedKelompokId = kelompokId;
          _viewMode = ViewMode.specific;
        });
        _loadKelas().then((_) => _showAddEditDialog());
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.teal,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add, size: 18, color: Colors.white),
            SizedBox(width: 6),
            Text(
              "Tambah",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      itemBuilder: (context) {
        return _kelompokFilter.map((k) {
          return PopupMenuItem<String>(
            value: k['id'] as String,
            child: Text(k['name'] as String),
          );
        }).toList();
      },
    );
  }

  Widget _buildModeToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ModeToggleButton(
              label: "Overview",
              icon: Icons.dashboard_rounded,
              isSelected: _viewMode == ViewMode.overview,
              onTap: _switchToOverview,
            ),
          ),
          Expanded(
            child: _ModeToggleButton(
              label: "Per Kelompok",
              icon: Icons.list_alt_rounded,
              isSelected: _viewMode == ViewMode.specific,
              onTap: _switchToSpecific,
            ),
          ),
        ],
      ),
    );
  }

  // ==================== OVERVIEW MODE CONTENT ====================

  Widget _buildOverviewContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Stats Header
        _buildStatsHeader(),
        const SizedBox(height: 16),

        // Filters
        if (_adminLevel == 1) ...[
          _buildDesaFilter(),
          const SizedBox(height: 12),
        ],

        // Aggregated Kelas List
        if (_aggregatedKelas.isEmpty)
          _buildEmptyState("Belum ada kelas di wilayah ini")
        else
          ..._aggregatedKelas.map((ak) => _buildAggregatedCard(ak)),

        // Unassigned warning
        if (_stats.unassignedCount > 0) ...[
          const SizedBox(height: 16),
          _buildUnassignedOverviewBanner(),
        ],
      ],
    );
  }

  Widget _buildStatsHeader() {
    final parts = <String>[];
    if (_adminLevel == 1 && _stats.desaCount > 0) {
      parts.add("${_stats.desaCount} desa");
    }
    if (_stats.kelompokCount > 0) {
      parts.add("${_stats.kelompokCount} kelompok");
    }
    if (_stats.uniqueClassCount > 0) {
      parts.add("${_stats.uniqueClassCount} kelas");
    }
    if (_stats.totalMembers > 0) {
      parts.add("${_stats.totalMembers} anggota");
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.teal.shade400, Colors.teal.shade600],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.analytics, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Ringkasan Kelas",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  parts.join(" • "),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesaFilter() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilterChip(
          label: const Text("Semua Desa"),
          selected: _filterDesaId == null,
          onSelected: (_) => _onDesaFilterChanged(null),
          selectedColor: Colors.teal.withValues(alpha: 0.2),
          checkmarkColor: Colors.teal,
        ),
        ..._desaFilter.map((desa) {
          final isSelected = _filterDesaId == desa['id'];
          return FilterChip(
            label: Text(desa['name'] as String),
            selected: isSelected,
            onSelected: (_) => _onDesaFilterChanged(desa['id'] as String),
            selectedColor: Colors.teal.withValues(alpha: 0.2),
            checkmarkColor: Colors.teal,
          );
        }),
      ],
    );
  }

  Widget _buildAggregatedCard(AggregatedKelas ak) {
    final isExpanded = _expandedCards.contains(ak.normalizedName);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          // Header - Tap to expand
          InkWell(
            onTap: () {
              setState(() {
                if (isExpanded) {
                  _expandedCards.remove(ak.normalizedName);
                } else {
                  _expandedCards.add(ak.normalizedName);
                }
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.teal.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.groups_rounded, color: Colors.teal),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ak.displayName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            _StatBadge(
                              icon: Icons.people,
                              label: "${ak.totalMembers} anggota",
                              color: Colors.blue,
                            ),
                            const SizedBox(width: 8),
                            if (ak.kelompokCount > 1)
                              _StatBadge(
                                icon: Icons.location_on,
                                label: "${ak.kelompokCount} kelompok",
                                color: Colors.orange,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.expand_more, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),

          // Breakdown items
          if (isExpanded) ...[
            const Divider(height: 1),
            ...ak.breakdown.map((b) => _buildBreakdownItem(b)),
          ],
        ],
      ),
    );
  }

  Widget _buildBreakdownItem(KelasBreakdown breakdown) {
    return InkWell(
      onTap: () {
        // Navigate to specific kelompok view
        setState(() {
          _selectedKelompokId = breakdown.kelompokId;
          _viewMode = ViewMode.specific;
        });
        _loadKelas();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            const SizedBox(width: 24),
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: Colors.teal.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    breakdown.kelompokName,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  if (breakdown.desaName != null)
                    Text(
                      breakdown.desaName!,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                "${breakdown.memberCount} anggota",
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.blue[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 20),
              onSelected: (action) async {
                if (action == 'edit') {
                  // Load kelas then show edit dialog
                  final kelas = await _kelasService.fetchKelasByKelompok(
                    breakdown.kelompokId,
                  );
                  final target = kelas.firstWhere(
                    (k) => k.id == breakdown.kelasId,
                    orElse: () => kelas.first,
                  );
                  _selectedKelompokId = breakdown.kelompokId;
                  await _loadKelas();
                  if (mounted) _showAddEditDialog(kelas: target);
                } else if (action == 'delete') {
                  _confirmDeleteFromBreakdown(breakdown);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit, size: 18),
                      SizedBox(width: 8),
                      Text('Edit'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, size: 18, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Hapus', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteFromBreakdown(KelasBreakdown breakdown) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Hapus Kelas?"),
        content: Text(
          "Yakin ingin menghapus kelas \"${breakdown.kelasName}\" "
          "dari ${breakdown.kelompokName}?\n\n"
          "Anggota kelas ini akan menjadi tidak memiliki kelas.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Batal"),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await _kelasService.deleteKelas(breakdown.kelasId);
                if (context.mounted) {
                  Navigator.pop(ctx);
                  await _loadOverviewData();
                  setState(() {});
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Kelas berhasil dihapus"),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Error: $e"),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text("Hapus"),
          ),
        ],
      ),
    );
  }

  Widget _buildUnassignedOverviewBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange[800]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "${_stats.unassignedCount} Anggota Belum Memiliki Kelas",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange[900],
                  ),
                ),
                Text(
                  "Pilih kelompok untuk mengaturnya.",
                  style: TextStyle(fontSize: 12, color: Colors.orange[800]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== SPECIFIC MODE CONTENT ====================

  Widget _buildSpecificContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Scope selectors untuk admin daerah/desa
        if (_adminLevel <= 2 && _viewMode == ViewMode.specific) ...[
          _buildScopeSelectors(),
          const SizedBox(height: 16),
        ],

        // Unassigned banner
        if (_unassignedUsers.isNotEmpty) ...[
          _buildUnassignedBanner(),
          const SizedBox(height: 16),
        ],

        // Content
        if (_selectedKelompokId == null)
          _buildEmptyState("Pilih Kelompok untuk melihat daftar kelas")
        else if (_kelasList.isEmpty && _unassignedUsers.isEmpty)
          _buildEmptyState("Belum ada kelas di kelompok ini")
        else if (_kelasList.isNotEmpty)
          _buildKelasList(),
      ],
    );
  }

  Widget _buildScopeSelectors() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Pilih Kelompok:",
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(height: 12),

          // Dropdown Desa (untuk Admin Daerah)
          if (_adminLevel == 1) ...[
            DropdownButtonFormField<String>(
              value: _selectedDesaId,
              hint: const Text("Pilih Desa"),
              isExpanded: true,
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
              items: _desaList
                  .map(
                    (d) => DropdownMenuItem(value: d.id, child: Text(d.name)),
                  )
                  .toList(),
              onChanged: (val) {
                setState(() => _selectedDesaId = val);
                if (val != null) _loadKelompokList(val);
              },
            ),
            const SizedBox(height: 12),
          ],

          // Dropdown Kelompok
          DropdownButtonFormField<String>(
            value: _selectedKelompokId,
            hint: const Text("Pilih Kelompok"),
            isExpanded: true,
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
            ),
            items: _kelompokList
                .map((k) => DropdownMenuItem(value: k.id, child: Text(k.name)))
                .toList(),
            onChanged: (val) {
              setState(() => _selectedKelompokId = val);
              if (val != null) _loadKelas();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(Icons.school_outlined, size: 48, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600]),
          ),
          if (_selectedKelompokId != null) ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _showAddEditDialog(),
              icon: const Icon(Icons.add),
              label: const Text("Tambah Kelas Pertama"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildKelasList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _kelasList.length,
      itemBuilder: (context, index) {
        final kelas = _kelasList[index];
        final count = _memberCounts[kelas.id] ?? 0;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            onTap: () => _showKelasDetail(kelas),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.teal.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.groups_rounded, color: Colors.teal),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          kelas.nama,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        if (kelas.deskripsi?.isNotEmpty == true)
                          Text(
                            kelas.deskripsi!,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        const SizedBox(height: 4),
                        _StatBadge(
                          icon: Icons.people,
                          label: "$count anggota",
                          color: Colors.blue,
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    onSelected: (action) {
                      if (action == 'edit') {
                        _showAddEditDialog(kelas: kelas);
                      } else if (action == 'delete') {
                        _confirmDelete(kelas);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 18),
                            SizedBox(width: 8),
                            Text('Edit'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, size: 18, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Hapus', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ==================== DIALOGS ====================

  void _showAddEditDialog({Kelas? kelas}) {
    final isEdit = kelas != null;
    final nameController = TextEditingController(text: kelas?.nama ?? '');
    final descController = TextEditingController(text: kelas?.deskripsi ?? '');

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isEdit ? "Edit Kelas" : "Tambah Kelas Baru",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: "Nama Kelas",
                  hintText: "Contoh: Muda-Mudi",
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: "Deskripsi (Opsional)",
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text("Batal"),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () async {
                      if (nameController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Nama kelas wajib diisi"),
                          ),
                        );
                        return;
                      }

                      try {
                        if (isEdit) {
                          await _kelasService.updateKelas(
                            kelas.copyWith(
                              nama: nameController.text.trim(),
                              deskripsi: descController.text.trim(),
                            ),
                          );
                        } else {
                          await _kelasService.createKelas(
                            Kelas(
                              id: '',
                              orgKelompokId: _selectedKelompokId!,
                              nama: nameController.text.trim(),
                              deskripsi: descController.text.trim(),
                            ),
                          );
                        }

                        if (context.mounted) {
                          Navigator.pop(ctx);
                          _loadKelas();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                isEdit
                                    ? "Kelas berhasil diperbarui"
                                    : "Kelas berhasil ditambahkan",
                              ),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("Error: $e"),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(isEdit ? "Simpan" : "Tambah"),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(Kelas kelas) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Hapus Kelas?"),
        content: Text(
          "Yakin ingin menghapus kelas \"${kelas.nama}\"?\n\n"
          "Anggota kelas ini akan menjadi tidak memiliki kelas.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Batal"),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await _kelasService.deleteKelas(kelas.id);
                if (context.mounted) {
                  Navigator.pop(ctx);
                  _loadKelas();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Kelas berhasil dihapus"),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Error: $e"),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text("Hapus"),
          ),
        ],
      ),
    );
  }

  void _showKelasDetail(Kelas kelas) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.teal.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.groups, color: Colors.teal),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          kelas.nama,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (kelas.deskripsi?.isNotEmpty == true)
                          Text(
                            kelas.deskripsi!,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 24),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _kelasService.getKelasMembers(kelas.id),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final members = snapshot.data ?? [];
                  if (members.isEmpty) {
                    return Center(
                      child: Text(
                        "Belum ada anggota",
                        style: TextStyle(color: Colors.grey[500]),
                      ),
                    );
                  }
                  return ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: members.length,
                    itemBuilder: (context, index) {
                      final m = members[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: m['foto_profil'] != null
                              ? NetworkImage(m['foto_profil'])
                              : null,
                          child: m['foto_profil'] == null
                              ? Text(
                                  (m['nama'] as String?)?.isNotEmpty == true
                                      ? m['nama'][0].toUpperCase()
                                      : '?',
                                )
                              : null,
                        ),
                        title: Text(m['nama'] ?? '-'),
                        subtitle: Text("@${m['username'] ?? '-'}"),
                        trailing: IconButton(
                          icon: const Icon(Icons.swap_horiz),
                          tooltip: "Pindah Kelas",
                          onPressed: () =>
                              _showMoveUserDialog(m['id'], m['nama'], kelas.id),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMoveUserDialog(
    String userId,
    String userName,
    String currentKelasId, {
    bool closeParentSheet = true,
  }) {
    String? targetKelasId;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text("Pindah Kelas"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Pindahkan $userName ke kelas:"),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: targetKelasId,
                hint: const Text("Pilih Kelas Tujuan"),
                isExpanded: true,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: _kelasList
                    .where((k) => k.id != currentKelasId)
                    .map(
                      (k) => DropdownMenuItem(value: k.id, child: Text(k.nama)),
                    )
                    .toList(),
                onChanged: (val) => setStateDialog(() => targetKelasId = val),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Batal"),
            ),
            ElevatedButton(
              onPressed: targetKelasId == null
                  ? null
                  : () async {
                      try {
                        await _kelasService.moveUserToKelas(
                          userId: userId,
                          kelasId: targetKelasId,
                        );
                        if (context.mounted) {
                          Navigator.pop(ctx);
                          if (closeParentSheet) {
                            Navigator.pop(context);
                          }
                          _loadKelas();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("$userName berhasil dipindahkan"),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("Error: $e"),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
              ),
              child: const Text("Pindahkan"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnassignedBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange[800]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "${_unassignedUsers.length} Anggota Belum Memiliki Kelas",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange[900],
                  ),
                ),
                Text(
                  "Anggota ini terdaftar di kelompok tapi belum masuk kelas manapun.",
                  style: TextStyle(fontSize: 12, color: Colors.orange[800]),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => _showUnassignedDialog(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange[100],
              foregroundColor: Colors.orange[900],
              elevation: 0,
            ),
            child: const Text("Atur"),
          ),
        ],
      ),
    );
  }

  void _showUnassignedDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Icon(
                        Icons.group_add,
                        color: Colors.orange[700],
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Atur Anggota",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              "${_unassignedUsers.length} anggota perlu ditempatkan",
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _unassignedUsers.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (context, index) {
                      final u = _unassignedUsers[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: u['foto_profil'] != null
                              ? NetworkImage(u['foto_profil'])
                              : null,
                          child: u['foto_profil'] == null
                              ? Text((u['nama'] as String)[0].toUpperCase())
                              : null,
                        ),
                        title: Text(u['nama'] ?? '-'),
                        subtitle: Text("@${u['username'] ?? '-'}"),
                        trailing: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _showMoveUserDialog(
                              u['id'],
                              u['nama'],
                              'unassigned',
                              closeParentSheet: false,
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                          child: const Text("Pilih Kelas"),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ==================== HELPER WIDGETS ====================

class _ModeToggleButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _ModeToggleButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.teal : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? Colors.white : Colors.grey[600],
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
