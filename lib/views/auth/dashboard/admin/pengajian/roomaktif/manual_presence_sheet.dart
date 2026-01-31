import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hpdaerah/models/pengajian_model.dart';
import 'package:hpdaerah/services/presensi_service.dart';
import 'package:image_picker/image_picker.dart';

class ManualPresenceSheet extends StatefulWidget {
  final Pengajian pengajian;
  const ManualPresenceSheet({super.key, required this.pengajian});

  @override
  State<ManualPresenceSheet> createState() => _ManualPresenceSheetState();
}

class _ManualPresenceSheetState extends State<ManualPresenceSheet> {
  final _presensiService = PresensiService();
  final _picker = ImagePicker();
  final _searchCtrl = TextEditingController();

  // State for converting Stream to Manual Fetch for Stability
  List<Map<String, dynamic>> _allData = [];
  bool _isLoading = true;
  String _searchQuery = "";
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    // Silent update if already loaded, else show loader
    if (_allData.isEmpty) setState(() => _isLoading = true);

    try {
      final data = await _presensiService.getDetailedAttendanceList(
        widget.pengajian,
      );
      if (mounted) {
        setState(() {
          _allData = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching data: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Handle bar
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Presensi Manual",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        widget.pengajian.title,
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 20,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Search Field (Permanent)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (val) => setState(() => _searchQuery = val),
              style: const TextStyle(color: Colors.black87),
              decoration: InputDecoration(
                hintText: "Cari nama jamaah...",
                prefixIcon: const Icon(Icons.search, size: 20),
                filled: true,
                fillColor: Colors.grey[100],
                contentPadding: EdgeInsets.zero,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF1A5F2D)),
                  )
                : RefreshIndicator(
                    onRefresh: _fetchData,
                    color: const Color(0xFF1A5F2D),
                    child: Builder(
                      builder: (context) {
                        // Statistics for Header
                        final hadir = _allData
                            .where((e) => e['status'] == 'hadir')
                            .length;
                        final izin = _allData
                            .where((e) => e['status'] == 'izin')
                            .length;

                        // Count 'belum_absen' or null status
                        final belum = _allData.where((e) {
                          final status = e['status'];
                          return status == 'belum_absen' || status == null;
                        }).length;

                        final total = _allData.length;

                        final filteredData = _allData.where((item) {
                          final nama = item['nama'].toString().toLowerCase();
                          final username = item['username']
                              .toString()
                              .toLowerCase();
                          return nama.contains(_searchQuery.toLowerCase()) ||
                              username.contains(_searchQuery.toLowerCase());
                        }).toList();

                        return Stack(
                          children: [
                            ListView(
                              padding: EdgeInsets.zero,
                              children: [
                                // Stats Mini Card
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 8,
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 16,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: Colors.grey.shade200,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.03,
                                          ),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceAround,
                                      children: [
                                        _buildStatItem(
                                          "Hadir",
                                          hadir,
                                          Colors.green,
                                        ),
                                        _buildStatDivider(),
                                        _buildStatItem(
                                          "Izin",
                                          izin,
                                          Colors.orange,
                                        ),
                                        _buildStatDivider(),
                                        _buildStatItem(
                                          "Belum",
                                          belum,
                                          Colors.grey,
                                        ),
                                        _buildStatDivider(),
                                        _buildStatItem(
                                          "Total",
                                          total,
                                          Colors.blueAccent,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                // List
                                if (filteredData.isEmpty)
                                  SizedBox(
                                    height: 300,
                                    child: _buildEmptyState(),
                                  )
                                else
                                  ListView.builder(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    itemCount: filteredData.length,
                                    itemBuilder: (context, index) {
                                      final item = filteredData[index];
                                      return _buildUserTile(item);
                                    },
                                  ),
                              ],
                            ),
                            if (_isProcessing)
                              Container(
                                color: Colors.white.withValues(alpha: 0.5),
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    color: Color(0xFF1A5F2D),
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserTile(Map<String, dynamic> item) {
    final status = item['status'] as String;
    Color statusColor = Colors.grey;
    String statusLabel = "Belum Presensi";

    if (status == 'hadir') {
      statusColor = Colors.green;
      statusLabel = "Hadir";
    } else if (status == 'izin') {
      statusColor = Colors.orange;
      statusLabel = "Izin";
    } else if (status == 'tidak_hadir') {
      statusColor = Colors.red;
      statusLabel = "Alpha";
    } else if (status == 'tolak') {
      statusColor = Colors.redAccent;
      statusLabel = "Ditolak";
    }

    bool isHadir = status == 'hadir';
    bool isIzin = status == 'izin';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: isHadir
              ? const Color(0xFF1A5F2D).withValues(alpha: 0.2)
              : isIzin
              ? Colors.amber.withValues(alpha: 0.2)
              : status == 'tolak'
              ? Colors.red.withValues(alpha: 0.2)
              : Colors.grey.shade100,
          width: 1.5,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.grey.shade200, width: 2),
          ),
          child: CircleAvatar(
            backgroundColor: Colors.grey[100],
            backgroundImage: item['foto_profil'] != null
                ? NetworkImage(item['foto_profil'])
                : null,
            child: item['foto_profil'] == null
                ? const Icon(Icons.person, color: Colors.blueGrey)
                : null,
          ),
        ),
        title: Text(
          item['nama'] ?? '-',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: Colors.black87,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  statusLabel.toUpperCase(),
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item['kelompok'] ?? item['desa'] ?? '-',
                  style: TextStyle(fontSize: 11, color: Colors.blueGrey[400]),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // TOMBOL DETAIL IZIN (Cek foto & alasan)
            if (isIzin) ...[
              _buildActionButton(
                icon: Icons.visibility_rounded,
                color: Colors.blue.shade700,
                bgColor: Colors.blue.shade50,
                onTap: () => _showIzinDetailDialog(item),
                isActive: true,
                tooltip: "Lihat Detail Izin",
              ),
              const SizedBox(width: 8),
            ],

            // TOMBOL IZIN
            _buildActionButton(
              icon: Icons.info_rounded,
              color: isIzin ? Colors.amber.shade700 : Colors.blueGrey.shade200,
              bgColor: isIzin
                  ? Colors.amber.shade50
                  : Colors.blueGrey.shade50.withValues(alpha: 0.5),
              onTap: () => _showIzinDialog(item),
              isActive: isIzin,
              tooltip: isIzin ? "Ubah Izin" : "Proses Izin",
            ),
            const SizedBox(width: 14),
            // TOMBOL HADIR
            _buildActionButton(
              icon: Icons.check_circle_rounded,
              color: isHadir
                  ? const Color(0xFF1A5F2D)
                  : Colors.blueGrey.shade200,
              bgColor: isHadir
                  ? const Color(0xFF1A5F2D).withValues(alpha: 0.1)
                  : Colors.blueGrey.shade50.withValues(alpha: 0.5),
              onTap: () =>
                  _updateStatus(item, isHadir ? 'tidak_hadir' : 'hadir'),
              isActive: isHadir,
              tooltip: "Tandai Hadir",
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required Color bgColor,
    required VoidCallback onTap,
    required bool isActive,
    required String tooltip,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Tooltip(
          message: tooltip,
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isActive
                    ? color.withValues(alpha: 0.3)
                    : Colors.grey.shade200,
                width: 1,
              ),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
        ),
      ),
    );
  }

  void _showIzinDialog(Map<String, dynamic> item) {
    final reasonCtrl = TextEditingController();
    XFile? selectedImage; // Use XFile to support both Web and Mobile
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          // Check if form is valid
          final bool hasReason = reasonCtrl.text.trim().isNotEmpty;
          final bool hasImage =
              selectedImage != null || item['foto_izin'] != null;
          final bool isValid = hasReason && hasImage;

          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              "Proses Izin: ${item['nama']}",
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. REASON INPUT (Free Text)
                  const Text(
                    "Alasan Izin",
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: reasonCtrl,
                    maxLines: 2,
                    onChanged: (val) =>
                        setDialogState(() {}), // Trigger rebuild
                    decoration: InputDecoration(
                      hintText: "Tuliskan alasan izin...",
                      filled: true,
                      fillColor: Colors.grey[50],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 2. PHOTO INPUT (Camera Only)
                  const Text(
                    "Foto Bukti (Wajib Kamera)",
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () async {
                      final picked = await _picker.pickImage(
                        source: ImageSource.camera,
                        imageQuality: 50, // Auto compress quality
                        maxWidth: 1024, // Resize if too big
                      );
                      if (picked != null) {
                        setDialogState(() {
                          selectedImage = picked;
                        });
                      }
                    },
                    child: Container(
                      height: 150,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: hasImage ? Colors.green : Colors.grey.shade300,
                          width: hasImage ? 2 : 1,
                        ),
                      ),
                      child: selectedImage != null
                          ? kIsWeb
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.network(
                                      selectedImage!.path,
                                      fit:
                                          BoxFit.contain, // Respect orientation
                                    ),
                                  )
                                : ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.file(
                                      File(selectedImage!.path),
                                      fit:
                                          BoxFit.contain, // Respect orientation
                                    ),
                                  )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.camera_alt_outlined,
                                  size: 40,
                                  color: hasImage ? Colors.green : Colors.grey,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  selectedImage == null
                                      ? "Klik untuk Ambil Foto"
                                      : "Ganti Foto",
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  if (item['foto_izin'] != null && selectedImage == null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.check_circle,
                            size: 14,
                            color: Colors.green,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "Sudah ada foto bukti sebelumnya",
                            style: TextStyle(
                              color: Colors.green[700],
                              fontSize: 11,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Validation Message if Incomplete
                  if (!isValid)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        "* Mohon lengkapi alasan dan foto bukti",
                        style: TextStyle(color: Colors.red[300], fontSize: 11),
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Batal"),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isValid ? Colors.orange : Colors.grey[300],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: isValid && !isSubmitting
                    ? () async {
                        setDialogState(() => isSubmitting = true);
                        try {
                          Navigator.pop(ctx); // Close Dialog first
                          await _processIzin(
                            item,
                            reasonCtrl.text.trim(),
                            selectedImage, // Pass XFile
                          );
                        } catch (e) {
                          setDialogState(() => isSubmitting = false);
                        }
                      }
                    : null,
                child: isSubmitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text("Simpan Izin"),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showIzinDetailDialog(Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titlePadding: EdgeInsets.zero,
        contentPadding: EdgeInsets.zero,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header Image
            Stack(
              children: [
                Container(
                  height: 250,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                  ),
                  child: item['foto_izin'] != null
                      ? GestureDetector(
                          onTap: () => _showFullScreenImage(item['foto_izin']),
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(24),
                            ),
                            child: Image.network(
                              item['foto_izin'],
                              fit: BoxFit.cover,
                            ),
                          ),
                        )
                      : const Center(
                          child: Icon(
                            Icons.image_not_supported_rounded,
                            size: 48,
                            color: Colors.grey,
                          ),
                        ),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.black26,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: Colors.amber.shade100,
                        child: Icon(
                          Icons.info_rounded,
                          size: 14,
                          color: Colors.amber.shade800,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        "KETERANGAN IZIN",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.amber.shade100),
                    ),
                    child: Text(
                      item['keterangan'] ?? "Tidak ada alasan tertulis",
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "Jamaah: ${item['nama']}",
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFullScreenImage(String url) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Center(child: Image.network(url, fit: BoxFit.contain)),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: const Icon(
                  Icons.close_rounded,
                  color: Colors.white,
                  size: 32,
                ),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _processIzin(
    Map<String, dynamic> item,
    String reason,
    XFile? image, // Changed from File? to XFile? for Web compatibility
  ) async {
    setState(() => _isProcessing = true);
    try {
      if (image != null) {
        await _presensiService.submitLeaveRequest(
          pengajianId: widget.pengajian.id,
          userId: item['user_id'],
          keterangan: reason,
          // Pass XFile directly, let service handle cross-platform file reading
          imageFile: image,
        );
      } else {
        // Just update keterangan if no new image
        await _presensiService.recordManualIzin(
          pengajianId: widget.pengajian.id,
          userId: item['user_id'],
          keterangan: reason,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Izin ${item['nama']} berhasil dicatat"),
            backgroundColor: Colors.orange,
          ),
        );
        _fetchData(); // Refresh Data Manually
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _updateStatus(Map<String, dynamic> item, String status) async {
    setState(() => _isProcessing = true);
    try {
      await _presensiService.recordPresence(
        pengajianId: widget.pengajian.id,
        userId: item['user_id'],
        status: status,
        method: 'manual',
      );
      if (mounted) _fetchData(); // Refresh list after manual update
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 64, color: Colors.grey[200]),
          const SizedBox(height: 16),
          Text(
            "Tidak ditemukan",
            style: TextStyle(
              color: Colors.grey[400],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, int count, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildStatDivider() {
    return Container(height: 30, width: 1, color: Colors.grey[200]);
  }
}
