import 'package:flutter/material.dart';
import 'package:hpdaerah/models/user_model.dart';
import 'package:hpdaerah/models/kelas_model.dart';
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

  bool _isLoading = true;
  int _selectedTab = 0; // 0 = Kelas, 1 = User

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // Load kelas list
      final kelasList = await _kelasService.fetchKelasInHierarchy(
        orgId: widget.orgId,
        adminLevel: widget.user.adminLevel ?? 1,
      );

      // Determine org column based on admin level
      String orgColumn = 'org_kelompok_id'; // Default
      final level = widget.user.adminLevel ?? 3;
      if (level == 1)
        orgColumn = 'org_daerah_id';
      else if (level == 2)
        orgColumn = 'org_desa_id';

      // Load user list (all users in hierarki)
      final userResponse = await _supabase
          .from('users')
          .select('id, nama')
          .eq(orgColumn, widget.orgId)
          .order('nama');

      // Load existing kelas assignments
      final kelasAssignments = await _supabase
          .from('khataman_assignment')
          .select(
            'id, kelas_id, master_target_id, master_target_khataman(nama, jumlah_halaman)',
          )
          .eq('org_id', widget.orgId)
          .eq('target_type', 'kelas')
          .eq('is_active', true);

      // Load existing user assignments
      final userAssignments = await _supabase
          .from('khataman_assignment')
          .select(
            'id, user_id, master_target_id, master_target_khataman(nama, jumlah_halaman)',
          )
          .eq('org_id', widget.orgId)
          .eq('target_type', 'user')
          .eq('is_active', true);

      setState(() {
        _kelasList = kelasList;
        _userList = List<Map<String, dynamic>>.from(userResponse as List);
        _kelasAssignments = List<Map<String, dynamic>>.from(
          kelasAssignments as List,
        );
        _userAssignments = List<Map<String, dynamic>>.from(
          userAssignments as List,
        );
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading data: $e');
      setState(() => _isLoading = false);
    }
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
              Expanded(child: _buildTab('Per Kelas', Icons.school, 0)),
              Expanded(child: _buildTab('Per User', Icons.person, 1)),
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
                onTap: _kelasList.isEmpty ? null : () => _showAddKelasDialog(),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _kelasList.isEmpty
                        ? Colors.grey.shade300
                        : Colors.amber.shade700,
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
    return Column(
      children: [
        // Header
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
                  'Target User (${_userList.length} user)',
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
        if (_userAssignments.isEmpty)
          _buildEmptyState('Belum ada target user', Icons.person_outline)
        else
          ..._userAssignments.map((a) => _buildAssignmentItem(a, 'user')),
      ],
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
    final halamanController = TextEditingController();
    final namaTargetController = TextEditingController(text: 'Al-Quran');

    // Cascading state
    String? selectedDesaId;
    String? selectedKelompokId;

    List<Map<String, dynamic>> desaList = [];
    List<Map<String, dynamic>> kelompokList = [];
    List<Kelas> filteredKelasList =
        []; // List kelas yang ditampilkan di dropdown

    bool isLoadingFilter = false;

    // Helper untuk reset selection bawahnya
    void resetKelompok() {
      selectedKelompokId = null;
      kelompokList = [];
      selectedKelas = null;
      filteredKelasList = [];
    }

    void resetKelas() {
      selectedKelas = null;
      filteredKelasList = [];
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          // Initial Load Logic (Run once)
          // Kita gunakan variabel lokal di luar builder untuk cache data
          // Tapi trigger load pertama kali bisa ditaruh di sini dengan check isEmpty
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
              filteredKelasList.isEmpty &&
              !isLoadingFilter) {
            // Admin Kelompok langsung load kelas (atau pakai _kelasList yang sudah ada)
            filteredKelasList = _kelasList;
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
                  'Target untuk Kelas',
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

                      // Load Kelompok based on Desa
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
                        resetKelas();
                        isLoadingFilter = true;
                      });

                      // Load Kelas based on Kelompok
                      if (val != null) {
                        final classes = await _kelasService
                            .fetchKelasByKelompok(val);
                        if (context.mounted) {
                          setSheetState(() {
                            filteredKelasList = classes;
                            isLoadingFilter = false;
                          });
                        }
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                ],

                // 3. Dropdown Kelas (Final Selection)
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
                  // Show list based on selection path
                  items: filteredKelasList.isEmpty
                      ? []
                      : filteredKelasList
                            .map(
                              (k) => DropdownMenuItem(
                                value: k,
                                child: Text(
                                  k.nama, // Info kelompok tidak perlu ditampilkan lagi karena sudah dipilih diatas
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                            )
                            .toList(),
                  onChanged: (val) => setSheetState(() => selectedKelas = val),
                  hint: isLoadingFilter
                      ? const Text(
                          'Loading...',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        )
                      : null,
                ),
                const SizedBox(height: 12),

                // Nama target (default Al-Quran)
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
                          if (selectedKelas == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Pilih kelas!'),
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
                          await _saveKelasTarget(
                            selectedKelas!,
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
        }, // builder
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

  Future<void> _saveKelasTarget(
    Kelas kelas,
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
