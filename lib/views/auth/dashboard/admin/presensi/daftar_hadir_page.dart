import 'package:flutter/material.dart';
import 'package:hpdaerah/models/user_model.dart';
import 'package:hpdaerah/services/presensi_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

class DaftarHadirPage extends StatefulWidget {
  final UserModel adminUser;
  final String? initialFilter;
  const DaftarHadirPage({
    super.key,
    required this.adminUser,
    this.initialFilter,
  });

  @override
  State<DaftarHadirPage> createState() => _DaftarHadirPageState();
}

class _DaftarHadirPageState extends State<DaftarHadirPage> {
  final _presensiService = PresensiService();
  final _supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _pengajianList = [];
  String? _selectedPengajianId;

  List<Map<String, dynamic>> _allAttendanceData = [];
  String _searchQuery = '';
  String _currentFilter = 'Semua'; // Semua, Hadir, Izin, Alpha, Belum
  late Stream<List<Map<String, dynamic>>> _attendanceStream;

  void _showFullImage(String imageUrl) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(imageUrl, fit: BoxFit.contain),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(ctx),
              icon: const Icon(Icons.close),
              label: const Text("Tutup"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialFilter != null) {
      _currentFilter = widget.initialFilter!;
    }
    _initStream();
    _fetchPengajianList();
  }

  void _initStream() {
    if (_selectedPengajianId != null) {
      _attendanceStream = _presensiService.streamDetailedAttendance(
        _selectedPengajianId!,
      );
    } else {
      _attendanceStream = Stream.value([]);
    }
  }

  Future<void> _fetchPengajianList() async {
    try {
      final response = await _supabase
          .from('pengajian')
          .select('id, title, started_at, org_id, ended_at')
          .order('started_at', ascending: false)
          .limit(30);

      if (!mounted) return;
      setState(() {
        _pengajianList = List<Map<String, dynamic>>.from(response);
        if (_pengajianList.isNotEmpty) {
          _selectedPengajianId = _pengajianList.first['id'];
          _initStream();
          _loadAttendanceData();
        }
      });
    } catch (e) {
      debugPrint("Error fetching pengajian: $e");
    }
  }

  Future<void> _loadAttendanceData() async {
    if (_selectedPengajianId == null) return;

    try {
      var data = await _presensiService.getDetailedAttendanceList(
        _selectedPengajianId!,
      );

      // Admin level filtering logic
      if (widget.adminUser.adminLevel != 0) {
        final adminOrgId = widget.adminUser.adminOrgId;
        data = data.where((u) {
          if (widget.adminUser.adminLevel == 1) {
            return u['daerah_id'] == adminOrgId;
          }
          if (widget.adminUser.adminLevel == 2) {
            return u['desa_id'] == adminOrgId;
          }
          if (widget.adminUser.adminLevel == 3) {
            return u['kelompok_id'] == adminOrgId;
          }
          return true;
        }).toList();
      }

      if (!mounted) return;
      setState(() {
        _allAttendanceData = data;
      });
    } catch (e) {
      debugPrint("Error loading attendance: $e");
    }
  }

  List<Map<String, dynamic>> get _filteredData {
    var list = _allAttendanceData;

    // Status Filter
    if (_currentFilter == 'Hadir') {
      list = list.where((u) => u['status'] == 'hadir').toList();
    } else if (_currentFilter == 'Izin') {
      list = list.where((u) => u['status'] == 'izin').toList();
    } else if (_currentFilter == 'Alpha') {
      list = list.where((u) => u['status'] == 'tidak_hadir').toList();
    } else if (_currentFilter == 'Belum') {
      list = list.where((u) => u['status'] == 'belum_absen').toList();
    }

    // Search Filter
    if (_searchQuery.isNotEmpty) {
      list = list
          .where(
            (u) =>
                (u['nama'] ?? '').toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                ) ||
                (u['username'] ?? '').toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                ),
          )
          .toList();
    }

    return list;
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedPengajianId == null) {
      return Column(
        children: [
          _buildPengajianSelector(),
          const Expanded(
            child: Center(child: Text("Pilih pengajian terlebih dahulu")),
          ),
        ],
      );
    }

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _attendanceStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        }

        // Use static data while loading the stream for the first time if needed,
        // but streamDetailedAttendance is pretty fast.
        List<Map<String, dynamic>> currentData =
            snapshot.data ?? _allAttendanceData;

        // Sync the local stats state with the stream data
        _allAttendanceData = currentData;

        return Column(
          children: [
            // 1. Selector Pengajian
            _buildPengajianSelector(),

            // 2. Summary & Filters
            _buildSummaryStats(),
            _buildFilterChips(),
            _buildSearchBar(),

            // 3. User List
            Expanded(
              child:
                  snapshot.connectionState == ConnectionState.waiting &&
                      currentData.isEmpty
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF1A5F2D),
                      ),
                    )
                  : _filteredData.isEmpty
                  ? _buildEmptyState()
                  : _buildUserList(),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPengajianSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: DropdownButtonFormField<String>(
        value: _selectedPengajianId,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: 'Pilih Pengajian',
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.grey[50],
        ),
        items: _pengajianList.map((p) {
          final isClosed = p['ended_at'] != null;
          final date = DateTime.parse(p['started_at']).toLocal();
          return DropdownMenuItem<String>(
            value: p['id'],
            child: Row(
              children: [
                Icon(
                  isClosed ? Icons.lock_clock : Icons.play_circle_outline,
                  size: 16,
                  color: isClosed ? Colors.grey : Colors.green,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "${p['title']} (${date.day}/${date.month})",
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
        onChanged: (val) {
          if (val == null) return;
          setState(() {
            _selectedPengajianId = val;
            _initStream();
            _loadAttendanceData();
          });
        },
      ),
    );
  }

  Widget _buildSummaryStats() {
    final hadir = _allAttendanceData
        .where((u) => u['status'] == 'hadir')
        .length;
    final izin = _allAttendanceData.where((u) => u['status'] == 'izin').length;
    final alpha = _allAttendanceData
        .where((u) => u['status'] == 'tidak_hadir')
        .length;
    final belum = _allAttendanceData
        .where((u) => u['status'] == 'belum_absen')
        .length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _buildStatCard("Hadir", hadir, Colors.green),
          const SizedBox(width: 4),
          _buildStatCard("Izin", izin, Colors.orange),
          const SizedBox(width: 4),
          _buildStatCard("Alpha", alpha, Colors.red),
          const SizedBox(width: 4),
          _buildStatCard("Belum", belum, Colors.grey),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, int count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Text(
              count.toString(),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: const TextStyle(fontSize: 9, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    final filters = ['Semua', 'Hadir', 'Izin', 'Alpha', 'Belum'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: filters.map((f) {
          final isSelected = _currentFilter == f;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ChoiceChip(
              label: Text(
                f,
                style: TextStyle(
                  fontSize: 12,
                  color: isSelected ? Colors.white : Colors.black87,
                ),
              ),
              selected: isSelected,
              onSelected: (val) => setState(() => _currentFilter = f),
              selectedColor: const Color(0xFF1A5F2D),
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: TextField(
        decoration: InputDecoration(
          hintText: 'Cari Nama / Username...',
          prefixIcon: const Icon(Icons.search),
          contentPadding: const EdgeInsets.all(12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.white,
        ),
        onChanged: (val) => setState(() => _searchQuery = val),
      ),
    );
  }

  Widget _buildUserList() {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: _filteredData.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, index) {
        final item = _filteredData[index];
        return _buildAttendanceTile(item);
      },
    );
  }

  Widget _buildAttendanceTile(Map<String, dynamic> item) {
    final status = item['status'];
    Color statusColor;
    IconData statusIcon;

    switch (status) {
      case 'hadir':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'izin':
        statusColor = Colors.orange;
        statusIcon = Icons.assignment_late;
        break;
      case 'tidak_hadir':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help_outline;
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: statusColor.withValues(alpha: 0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // Photo
              CircleAvatar(
                radius: 24,
                backgroundColor: Colors.grey[200],
                backgroundImage: item['foto_profil'] != null
                    ? NetworkImage(item['foto_profil'])
                    : null,
                child: item['foto_profil'] == null
                    ? const Icon(Icons.person, color: Colors.grey)
                    : null,
              ),
              const SizedBox(width: 12),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['nama'],
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    Text(
                      "${item['kelompok'] ?? '-'} • ${item['desa'] ?? '-'}",
                      style: TextStyle(color: Colors.grey[600], fontSize: 11),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    if (status == 'izin') ...[
                      if (item['keterangan'] != null)
                        Text(
                          "Ket: ${item['keterangan']}",
                          style: const TextStyle(
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                            color: Colors.blueGrey,
                          ),
                        ),
                      if (item['foto_izin'] != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: InkWell(
                            onTap: () => _showFullImage(item['foto_izin']),
                            child: Container(
                              height: 60,
                              width: 60,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                image: DecorationImage(
                                  image: NetworkImage(item['foto_izin']),
                                  fit: BoxFit.cover,
                                ),
                              ),
                              child: const Icon(
                                Icons.zoom_in,
                                color: Colors.white70,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
              // Status Badge & Manual Actions
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, size: 12, color: statusColor),
                        const SizedBox(width: 4),
                        Text(
                          status.toUpperCase(),
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (status == 'belum_absen')
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.check_circle_outline,
                            color: Colors.green,
                            size: 20,
                          ),
                          tooltip: "Hadir",
                          onPressed: () => _manualMarkPresence(item, 'hadir'),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.assignment_late_outlined,
                            color: Colors.orange,
                            size: 20,
                          ),
                          tooltip: "Izin",
                          onPressed: () => _showManualIzinDialog(item),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.cancel_outlined,
                            color: Colors.red,
                            size: 20,
                          ),
                          tooltip: "Alpha",
                          onPressed: () =>
                              _manualMarkPresence(item, 'tidak_hadir'),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _manualMarkPresence(Map<String, dynamic> item, String status) async {
    try {
      await _presensiService.recordPresence(
        pengajianId: _selectedPengajianId!,
        userId: item['user_id'],
        method: 'manual',
        status: status,
      );
      _loadAttendanceData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Berhasil update status ${item['nama']}")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Gagal: $e")));
    }
  }

  void _showManualIzinDialog(Map<String, dynamic> item) async {
    final noteCtrl = TextEditingController();
    File? selectedImage;
    final picker = ImagePicker();
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text("Catat Izin: ${item['nama']}"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: noteCtrl,
                    decoration: const InputDecoration(
                      hintText: "Alasan izin...",
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "Foto Bukti (Kamera)",
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () async {
                      final picked = await picker.pickImage(
                        source: ImageSource.camera,
                        imageQuality: 50,
                      );
                      if (picked != null) {
                        setDialogState(() {
                          selectedImage = File(picked.path);
                        });
                      }
                    },
                    child: Container(
                      height: 120,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: selectedImage != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(
                                selectedImage!,
                                fit: BoxFit.cover,
                              ),
                            )
                          : const Icon(Icons.camera_alt, color: Colors.grey),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(ctx),
                child: const Text("Batal"),
              ),
              ElevatedButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        if (noteCtrl.text.isEmpty || selectedImage == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Alasan & Foto wajib diisi"),
                            ),
                          );
                          return;
                        }

                        setDialogState(() => isSaving = true);
                        try {
                          await _presensiService.submitLeaveRequest(
                            pengajianId: _selectedPengajianId!,
                            userId: item['user_id'],
                            keterangan: noteCtrl.text.trim(),
                            imageFile: selectedImage!,
                          );
                          Navigator.pop(ctx);
                          _loadAttendanceData();
                        } catch (e) {
                          setDialogState(() => isSaving = false);
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text("Gagal: $e")));
                        }
                      },
                child: isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text("Simpan"),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_off_outlined, size: 48, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text(
              "Tidak ada data ditemukan",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[500], fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
