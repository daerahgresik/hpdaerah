import 'package:flutter/material.dart';
import 'package:hpdaerah/models/user_model.dart';
import 'package:hpdaerah/models/kelas_model.dart';
import 'package:hpdaerah/models/aggregated_kelas_model.dart';
import 'package:hpdaerah/models/organization_model.dart';
import 'package:hpdaerah/services/kelas_service.dart';
import 'package:hpdaerah/services/organization_service.dart';

/// View Mode untuk admin level tinggi
enum ViewMode { daerah, desa, kelompok }

enum OverviewType { byRegion, byClass }

class AturKelasPage extends StatefulWidget {
  final UserModel user;
  final String orgId;
  final VoidCallback? onNavigateToKhataman;

  const AturKelasPage({
    super.key,
    required this.user,
    required this.orgId,
    this.onNavigateToKhataman,
  });

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
  ViewMode _viewMode = ViewMode.daerah;

  // State - Overview Mode
  OverviewType _overviewType = OverviewType.byRegion;
  List<AggregatedKelas> _aggregatedKelas = [];
  HierarchyStats _stats = HierarchyStats.empty();
  List<Map<String, dynamic>> _desaFilter = [];
  List<Map<String, dynamic>> _kelompokFilter = [];
  String? _filterDesaId;

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

  void _switchToDaerah() async {
    setState(() {
      _viewMode = ViewMode.daerah;
      _filterDesaId = null;
      _isLoading = true;
    });

    await _loadOverviewData();
    if (mounted) setState(() => _isLoading = false);
  }

  void _switchToDesa(String? desaId) async {
    setState(() {
      _viewMode = ViewMode.desa;
      _filterDesaId = desaId;
      _isLoading = true;
    });

    await _loadOverviewData();
    if (mounted) setState(() => _isLoading = false);
  }

  void _switchToKelompok() async {
    setState(() {
      _viewMode = ViewMode.kelompok;
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
        else if (_viewMode == ViewMode.kelompok)
          _buildSpecificContent()
        else
          _buildOverviewContent(),
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
        if (_viewMode == ViewMode.kelompok && _selectedKelompokId != null)
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
        else if (_viewMode != ViewMode.kelompok && _adminLevel <= 2)
          _buildOverviewAddButton(),
      ],
    );
  }

  Widget _buildOverviewAddButton() {
    return GestureDetector(
      onTap: () => _showAddEditDialog(),
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
              "Tambah Kelas",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
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
          // Tab Daerah (Overview)
          Expanded(
            child: _ModeToggleButton(
              label: "Daerah",
              icon: Icons.domain_rounded,
              isSelected: _viewMode == ViewMode.daerah,
              onTap: _switchToDaerah,
            ),
          ),
          // Tab Desa
          Expanded(
            child: _ModeToggleButton(
              label: "Desa",
              icon: Icons.location_city_rounded,
              isSelected: _viewMode == ViewMode.desa,
              onTap: () => _switchToDesa(null),
            ),
          ),
          // Tab Kelompok
          Expanded(
            child: _ModeToggleButton(
              label: "Kelompok",
              icon: Icons.groups_rounded,
              isSelected: _viewMode == ViewMode.kelompok,
              onTap: _switchToKelompok,
            ),
          ),
        ],
      ),
    );
  }

  // ==================== DAERAH & DESA CONTENT ====================

  Widget _buildOverviewContent() {
    if (_viewMode == ViewMode.daerah) {
      return _buildDaerahContent();
    } else {
      return _buildDesaContent();
    }
  }

  Widget _buildDaerahContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStatsHeader(),
        const SizedBox(height: 12),
        _buildOverviewTypeToggle(),
        const SizedBox(height: 16),
        if (_overviewType == OverviewType.byRegion)
          _buildHierarchyTree(filterDesaId: null)
        else
          _buildAggregatedByClassList(filterDesaId: null),
      ],
    );
  }

  Widget _buildDesaContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStatsHeader(),
        const SizedBox(height: 16),

        // Info Context Region
        if (_adminLevel == 1) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.withOpacity(0.1)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 16, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Menampilkan kelas di desa dari Daerah ${widget.user.orgDaerahName ?? '-'}",
                    style: const TextStyle(fontSize: 12, color: Colors.blue),
                  ),
                ),
              ],
            ),
          ),
          _buildDesaFilter(),
          const SizedBox(height: 12),
        ],

        _buildOverviewTypeToggle(),
        const SizedBox(height: 12),

        if (_overviewType == OverviewType.byRegion)
          _buildHierarchyTree(filterDesaId: _filterDesaId)
        else
          _buildAggregatedByClassList(filterDesaId: _filterDesaId),

        // Unassigned warning
        if (_stats.unassignedCount > 0) ...[
          const SizedBox(height: 16),
          _buildUnassignedOverviewBanner(),
        ],
      ],
    );
  }

  /// Builds a hierarchy tree: Desa -> Kelompok -> Kelas
  Widget _buildHierarchyTree({String? filterDesaId}) {
    // 1. Determine list of Desa to show
    List<Map<String, dynamic>> desasToShow = [];
    if (filterDesaId != null) {
      desasToShow = _desaFilter.where((d) => d['id'] == filterDesaId).toList();
    } else {
      // Show all desa if no filter
      desasToShow = List.from(_desaFilter);
      // If admin level is not 1, we might need to rely on what's available or user's org
      if (_adminLevel == 2 && _desaFilter.isEmpty) {
        // Fallback for Admin Desa if _desaFilter is empty
        desasToShow = [
          {'id': widget.user.orgDesaId, 'name': widget.user.orgDesaName},
        ];
      }
    }

    if (desasToShow.isEmpty) {
      if (_isLoading) return const Center(child: CircularProgressIndicator());
      return _buildEmptyState("Data desa tidak ditemukan");
    }

    return Column(
      children: desasToShow.map((desa) {
        return _buildDesaExpansionTile(desa);
      }).toList(),
    );
  }

  Widget _buildDesaExpansionTile(Map<String, dynamic> desa) {
    // 2. Find all classes in this Desa
    final desaId = desa['id'];
    final desaName = desa['name'];

    // Group classes by Kelompok
    final Map<String, List<KelasBreakdown>> kelompokMap = {};
    int totalKelasInDesa = 0;
    int totalKelompokInDesa = 0;

    for (var agg in _aggregatedKelas) {
      for (var bd in agg.breakdown) {
        if (bd.desaId == desaId) {
          final kId = bd.kelompokId;
          final kName = bd.kelompokName;

          final key = "$kId|$kName";

          if (!kelompokMap.containsKey(key)) {
            kelompokMap[key] = [];
            totalKelompokInDesa++;
          }
          kelompokMap[key]!.add(bd);
          totalKelasInDesa++;
        }
      }
    }

    // Sort Kelompok by Name
    final sortedKelompokKeys = kelompokMap.keys.toList()
      ..sort((a, b) {
        final nameA = a.split('|')[1];
        final nameB = b.split('|')[1];
        return nameA.compareTo(nameB);
      });

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: ExpansionTile(
        initiallyExpanded: _filterDesaId == desaId, // Expand if filtered
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        collapsedShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.teal.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.location_city, color: Colors.teal),
        ),
        title: Text(
          desaName,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Text(
          "$totalKelompokInDesa Kelompok • $totalKelasInDesa Kelas",
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        children: [
          if (sortedKelompokKeys.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                "Belum ada data kelas di desa ini.",
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: Colors.grey,
                ),
              ),
            )
          else
            ...sortedKelompokKeys.map((key) {
              final parts = key.split('|');
              final kId = parts[0];
              final kName = parts[1];
              final kelasList = kelompokMap[key]!;

              // Sort kelas by name
              kelasList.sort((a, b) => a.kelasName.compareTo(b.kelasName));

              return _buildKelompokExpansionTile(kId, kName, kelasList);
            }),
        ],
      ),
    );
  }

  Widget _buildKelompokExpansionTile(
    String kId,
    String kName,
    List<KelasBreakdown> kelasList,
  ) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        initiallyExpanded: true, // Auto expand kelompok inside desa
        leading: const Icon(
          Icons.groups_outlined,
          size: 20,
          color: Colors.grey,
        ),
        title: Text(
          kName,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Text("${kelasList.length} Kelas"),
        childrenPadding: const EdgeInsets.only(left: 16, bottom: 8),
        children: kelasList.map((bd) {
          return ListTile(
            contentPadding: const EdgeInsets.only(left: 40, right: 16),
            dense: true,
            leading: const Icon(
              Icons.class_outlined,
              size: 18,
              color: Colors.teal,
            ),
            title: Text(bd.kelasName, style: const TextStyle(fontSize: 14)),
            subtitle: Text("${bd.memberCount} Anggota"),
            onTap: () {
              // Optional: Show details
            },
          );
        }).toList(),
      ),
    );
  }

  // ==================== TOGGLE & AGGREGATED VIEW ====================

  Widget _buildOverviewTypeToggle() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () =>
                  setState(() => _overviewType = OverviewType.byRegion),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _overviewType == OverviewType.byRegion
                      ? Colors.teal
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.account_tree_rounded,
                      size: 16,
                      color: _overviewType == OverviewType.byRegion
                          ? Colors.white
                          : Colors.grey[600],
                    ),
                    const SizedBox(width: 6),
                    Text(
                      "Per Wilayah",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _overviewType == OverviewType.byRegion
                            ? Colors.white
                            : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _overviewType = OverviewType.byClass),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _overviewType == OverviewType.byClass
                      ? Colors.teal
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.school_rounded,
                      size: 16,
                      color: _overviewType == OverviewType.byClass
                          ? Colors.white
                          : Colors.grey[600],
                    ),
                    const SizedBox(width: 6),
                    Text(
                      "Per Kelas",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _overviewType == OverviewType.byClass
                            ? Colors.white
                            : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAggregatedByClassList({String? filterDesaId}) {
    // Filter berdasarkan desa jika ada
    List<AggregatedKelas> filtered = _aggregatedKelas;
    if (filterDesaId != null) {
      filtered = _aggregatedKelas.where((agg) {
        return agg.breakdown.any((bd) => bd.desaId == filterDesaId);
      }).toList();
    }

    if (filtered.isEmpty) {
      return _buildEmptyState("Belum ada data kelas");
    }

    // Sort berdasarkan nama
    filtered.sort(
      (a, b) => ClassNameHelper.naturalCompare(a.displayName, b.displayName),
    );

    return Column(
      children: filtered.map((agg) {
        return _buildAggregatedClassCard(agg, filterDesaId: filterDesaId);
      }).toList(),
    );
  }

  Widget _buildAggregatedClassCard(
    AggregatedKelas agg, {
    String? filterDesaId,
  }) {
    // Filter breakdown berdasarkan desa jika perlu
    final breakdowns = filterDesaId != null
        ? agg.breakdown.where((bd) => bd.desaId == filterDesaId).toList()
        : agg.breakdown;

    final totalMembers = breakdowns.fold<int>(
      0,
      (sum, bd) => sum + bd.memberCount,
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: ExpansionTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        collapsedShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.indigo.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.class_rounded,
            color: Colors.indigo,
            size: 22,
          ),
        ),
        title: Text(
          agg.displayName,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        subtitle: Text(
          "$totalMembers Anggota • ${breakdowns.length} Kelompok",
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        childrenPadding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
        children: breakdowns.map((bd) {
          return ListTile(
            dense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
            leading: const Icon(
              Icons.groups_outlined,
              size: 18,
              color: Colors.grey,
            ),
            title: Text(bd.kelompokName, style: const TextStyle(fontSize: 13)),
            subtitle: bd.desaName != null
                ? Text(
                    bd.desaName!,
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                  )
                : null,
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.teal.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                "${bd.memberCount}",
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.teal,
                ),
              ),
            ),
          );
        }).toList(),
      ),
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

    // Determine header title based on admin level & view mode
    String headerTitle = "Ringkasan Kelas";
    if (_adminLevel == 1) {
      if (_viewMode == ViewMode.daerah) {
        headerTitle = "Ringkasan Daerah ${widget.user.orgDaerahName ?? ''}";
      } else if (_viewMode == ViewMode.desa) {
        if (_filterDesaId != null) {
          final desaName = _desaFilter.firstWhere(
            (d) => d['id'] == _filterDesaId,
            orElse: () => {'name': ''},
          )['name'];
          headerTitle = "Ringkasan Desa $desaName";
        } else {
          headerTitle = "Ringkasan Semua Desa";
        }
      } else {
        headerTitle = "Ringkasan Kelompok";
      }
    } else if (_adminLevel == 2) {
      headerTitle = "Ringkasan Desa ${widget.user.orgDesaName ?? ''}";
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.teal.shade400, Colors.teal.shade600],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _viewMode == ViewMode.daerah ? Icons.domain : Icons.analytics,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      headerTitle,
                      style: const TextStyle(
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
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Quick action: Atur Target button
          if (_stats.uniqueClassCount > 0) ...[
            const SizedBox(height: 12),
            InkWell(
              onTap: () {
                // Navigate to Khataman tab which contains Atur Target
                if (widget.onNavigateToKhataman != null) {
                  widget.onNavigateToKhataman!();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Buka menu Khataman → Atur Target untuk assign target ke kelas',
                      ),
                      backgroundColor: Colors.teal,
                      duration: Duration(seconds: 3),
                    ),
                  );
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.track_changes,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Atur Target Khataman',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.arrow_forward_ios,
                      color: Colors.white,
                      size: 12,
                    ),
                  ],
                ),
              ),
            ),
          ],
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
          label: const Text("Semua"),
          selected: _filterDesaId == null,
          onSelected: (_) => _onDesaFilterChanged(null),
          selectedColor: Colors.teal.withOpacity(0.2),
          checkmarkColor: Colors.teal,
        ),
        ..._desaFilter.map((desa) {
          final isSelected = _filterDesaId == desa['id'];
          return FilterChip(
            label: Text(desa['name'] as String),
            selected: isSelected,
            onSelected: (_) => _onDesaFilterChanged(desa['id'] as String),
            selectedColor: Colors.teal.withOpacity(0.2),
            checkmarkColor: Colors.teal,
          );
        }),
      ],
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
        if (_adminLevel <= 2 && _viewMode == ViewMode.kelompok) ...[
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
    // Pisahkan kelas utama (tanpa parent) dan sub-kelas
    final parentKelasList = _kelasList
        .where((k) => k.parentKelasId == null)
        .toList();

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: parentKelasList.length,
      itemBuilder: (context, index) {
        final kelas = parentKelasList[index];
        return _buildKelasCard(kelas);
      },
    );
  }

  Widget _buildKelasCard(Kelas kelas) {
    final count = _memberCounts[kelas.id] ?? 0;
    // Cari sub-kelas dari daftar yg sudah dimuat
    final subKelas = _kelasList
        .where((k) => k.parentKelasId == kelas.id)
        .toList();
    final hasSubKelas = subKelas.isNotEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              _showAddEditDialog(kelas: kelas);
            },
            borderRadius: hasSubKelas
                ? const BorderRadius.vertical(top: Radius.circular(12))
                : BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: kelas.isKelasKhusus
                          ? Colors.amber.withOpacity(0.1)
                          : Colors.teal.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      kelas.isKelasKhusus
                          ? Icons.star_outline
                          : Icons.class_outlined,
                      color: kelas.isKelasKhusus ? Colors.amber : Colors.teal,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                kelas.nama,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            if (kelas.isKelasKhusus) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  kelas.orgLevelLabel,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.amber,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                "$count anggota",
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue,
                                ),
                              ),
                            ),
                            if (hasSubKelas) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.indigo.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  "${subKelas.length} sub-kelas",
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.indigo,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    onSelected: (action) {
                      if (action == 'edit') {
                        _showAddEditDialog(kelas: kelas);
                      } else if (action == 'add_sub') {
                        _showAddEditDialog(
                          parentKelasId: kelas.id,
                          parentKelasName: kelas.nama,
                        );
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
                        value: 'add_sub',
                        child: Row(
                          children: [
                            Icon(Icons.subdirectory_arrow_right, size: 18),
                            SizedBox(width: 8),
                            Text('Tambah Sub-Kelas'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Tampilkan sub-kelas jika ada
          if (hasSubKelas)
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(12),
                ),
              ),
              child: Column(
                children: [
                  const Divider(height: 1),
                  ...subKelas.map((sub) => _buildSubKelasItem(sub, kelas.nama)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSubKelasItem(Kelas sub, String parentName) {
    final count = _memberCounts[sub.id] ?? 0;
    return InkWell(
      onTap: () => _showAddEditDialog(kelas: sub),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            const SizedBox(width: 20),
            Icon(
              Icons.subdirectory_arrow_right,
              size: 16,
              color: Colors.grey[400],
            ),
            const SizedBox(width: 8),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.indigo.withOpacity(0.08),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(
                Icons.class_outlined,
                size: 16,
                color: Colors.indigo,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sub.nama,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    "$count anggota",
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 18, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  // Method _buildAggregatedCard removed as it is replaced by Hierarchy Tree logic

  // ==================== DIALOGS ====================

  void _showAddEditDialog({
    Kelas? kelas,
    String? parentKelasId,
    String? parentKelasName,
  }) {
    final isEdit = kelas != null;
    final isSubKelas = parentKelasId != null;
    final nameController = TextEditingController(text: kelas?.nama ?? '');

    // Untuk kelas khusus - pilih tingkat
    int selectedOrgLevel = kelas?.orgLevel ?? 3; // Default: Kelompok
    String? selectedOrgId = kelas?.orgId;

    // Jika dari mode overview (bukan kelompok), default ke orgLevel sesuai viewMode
    if (!isEdit &&
        !isSubKelas &&
        _viewMode != ViewMode.kelompok &&
        _adminLevel <= 2) {
      if (_viewMode == ViewMode.daerah && _adminLevel == 1) {
        selectedOrgLevel = 1; // Daerah
        selectedOrgId = widget.orgId;
      } else if (_viewMode == ViewMode.desa) {
        selectedOrgLevel = 2; // Desa
        selectedOrgId = _filterDesaId ?? widget.orgId;
      }
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isEdit
                        ? "Edit Kelas"
                        : isSubKelas
                        ? "Tambah Sub-Kelas"
                        : "Tambah Kelas Baru",
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  // Info parent kelas jika sub-kelas
                  if (isSubKelas) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.indigo.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.indigo.withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.subdirectory_arrow_right,
                            size: 18,
                            color: Colors.indigo,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "Sub-kelas dari: $parentKelasName",
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.indigo,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Pilih tingkat — hanya di mode overview & bukan edit/sub-kelas
                  if (!isEdit &&
                      !isSubKelas &&
                      _viewMode != ViewMode.kelompok &&
                      _adminLevel <= 2) ...[
                    const SizedBox(height: 16),
                    const Text(
                      "Tingkat Kelas",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          if (_adminLevel == 1)
                            Expanded(
                              child: _buildDialogLevelChip(
                                label: "Daerah",
                                icon: Icons.domain,
                                isSelected: selectedOrgLevel == 1,
                                onTap: () => setDialogState(() {
                                  selectedOrgLevel = 1;
                                  selectedOrgId = widget.orgId;
                                }),
                              ),
                            ),
                          Expanded(
                            child: _buildDialogLevelChip(
                              label: "Desa",
                              icon: Icons.location_city,
                              isSelected: selectedOrgLevel == 2,
                              onTap: () => setDialogState(() {
                                selectedOrgLevel = 2;
                                selectedOrgId =
                                    _filterDesaId ??
                                    (_adminLevel == 2 ? widget.orgId : null);
                              }),
                            ),
                          ),
                          Expanded(
                            child: _buildDialogLevelChip(
                              label: "Kelompok",
                              icon: Icons.groups,
                              isSelected: selectedOrgLevel == 3,
                              onTap: () => setDialogState(() {
                                selectedOrgLevel = 3;
                                selectedOrgId = _selectedKelompokId;
                              }),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Dropdown Desa jika level = Desa & admin Daerah
                    if (selectedOrgLevel == 2 && _adminLevel == 1) ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: selectedOrgId,
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
                        items: _desaFilter.map((d) {
                          return DropdownMenuItem(
                            value: d['id'] as String,
                            child: Text(d['name'] as String),
                          );
                        }).toList(),
                        onChanged: (val) =>
                            setDialogState(() => selectedOrgId = val),
                      ),
                    ],

                    // Dropdown Kelompok jika level = Kelompok
                    if (selectedOrgLevel == 3) ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: selectedOrgId,
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
                        items: _kelompokFilter.map((k) {
                          return DropdownMenuItem(
                            value: k['id'] as String,
                            child: Text(k['name'] as String),
                          );
                        }).toList(),
                        onChanged: (val) =>
                            setDialogState(() => selectedOrgId = val),
                      ),
                    ],

                    // Info tingkat
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline,
                            size: 14,
                            color: Colors.amber,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              selectedOrgLevel == 1
                                  ? "Kelas ini akan berlaku untuk seluruh Daerah"
                                  : selectedOrgLevel == 2
                                  ? "Kelas ini akan berlaku untuk satu Desa"
                                  : "Kelas biasa di bawah satu Kelompok",
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.amber,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: "Nama Kelas",
                      hintText: isSubKelas
                          ? "Contoh: PAUD, TK, SD Kelas 1"
                          : "Contoh: Muda-Mudi",
                      border: const OutlineInputBorder(),
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

                          // Validasi orgId untuk kelas khusus
                          if (!isEdit &&
                              !isSubKelas &&
                              selectedOrgLevel < 3 &&
                              selectedOrgId == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Pilih organisasi tujuan"),
                              ),
                            );
                            return;
                          }

                          if (!isEdit &&
                              !isSubKelas &&
                              selectedOrgLevel == 3 &&
                              selectedOrgId == null &&
                              _selectedKelompokId == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Pilih kelompok tujuan"),
                              ),
                            );
                            return;
                          }

                          try {
                            if (isEdit) {
                              await _kelasService.updateKelas(
                                kelas.copyWith(
                                  nama: nameController.text.trim(),
                                ),
                              );
                            } else {
                              final kelompokId = selectedOrgLevel == 3
                                  ? (selectedOrgId ?? _selectedKelompokId)
                                  : null;

                              await _kelasService.createKelas(
                                Kelas(
                                  id: '',
                                  orgKelompokId: kelompokId,
                                  nama: nameController.text.trim(),
                                  orgId: isSubKelas
                                      ? null
                                      : (selectedOrgId ?? kelompokId),
                                  orgLevel: isSubKelas ? 3 : selectedOrgLevel,
                                  parentKelasId: parentKelasId,
                                ),
                              );
                            }

                            if (context.mounted) {
                              Navigator.pop(ctx);

                              // Refresh data sesuai konteks
                              if (_viewMode == ViewMode.kelompok ||
                                  _adminLevel == 3) {
                                _loadKelas();
                              } else {
                                setState(() => _isLoading = true);
                                await _loadOverviewData();
                                if (mounted) setState(() => _isLoading = false);
                              }

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    isEdit
                                        ? "Kelas berhasil diperbarui"
                                        : isSubKelas
                                        ? "Sub-kelas berhasil ditambahkan"
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
        ),
      ),
    );
  }

  Widget _buildDialogLevelChip({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.teal : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? Colors.white : Colors.grey[600],
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : Colors.grey[600],
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
