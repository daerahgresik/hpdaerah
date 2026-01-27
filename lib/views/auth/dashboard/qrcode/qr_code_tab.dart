import 'package:flutter/material.dart';
import 'dart:async';
import 'package:hpdaerah/models/user_model.dart';
import 'package:hpdaerah/models/pengajian_qr_model.dart';
import 'package:hpdaerah/services/pengajian_qr_service.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:hpdaerah/services/presensi_service.dart';

/// Smart QR Code Tab - Strictly for Active QR Codes
class QrCodeTab extends StatefulWidget {
  final UserModel user;
  const QrCodeTab({super.key, required this.user});

  @override
  State<QrCodeTab> createState() => _QrCodeTabState();
}

class _QrCodeTabState extends State<QrCodeTab> {
  final _qrService = PengajianQrService();
  final _presensiService = PresensiService();
  late Stream<List<PengajianQr>> _qrStream;
  bool _isProcessing = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _initStream();
    // Refresh UI every second for real-time countdowns
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _initStream() {
    if (widget.user.id != null) {
      _qrStream = _qrService.streamActiveQrForUser(widget.user.id!);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.user.id == null) {
      return const Center(child: Text('User ID null'));
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'QR Code Pengajian',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF1A5F2D),
        elevation: 0,
        centerTitle: true,
        toolbarHeight: 50, // Smaller AppBar
        automaticallyImplyLeading: false,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<PengajianQr>>(
        stream: _qrStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF1A5F2D)),
            );
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final allQr = snapshot.data ?? [];
          // Categorize QR codes - ONLY SHOW ACTIVE
          final aktif = allQr.where((q) => !q.isUsed).toList();

          return _buildAktifTab(aktif);
        },
      ),
    );
  }

  Widget _buildAktifTab(List<PengajianQr> aktifList) {
    if (aktifList.isEmpty) {
      return _buildEmptyState(
        icon: Icons.qr_code_scanner,
        title: 'Tidak Ada QR Aktif',
        subtitle:
            'Semua pengajian sudah Anda hadiri atau belum ada pengajian baru',
      );
    }

    return RefreshIndicator(
      onRefresh: () async => setState(() {}),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: aktifList.length,
        itemBuilder: (context, index) {
          final qr = aktifList[index];
          return _buildQrCard(qr);
        },
      ),
    );
  }

  Widget _buildQrCard(PengajianQr qr) {
    final now = DateTime.now();
    final startTime = qr.pengajianStartedAt;
    final endTime = qr.pengajianEndedAt;

    String statusText = "";
    Color statusColor = Colors.grey;
    IconData statusIcon = Icons.timer;

    if (qr.presensiStatus == 'izin') {
      statusText = "Anda Izin";
      statusColor = Colors.orange;
      statusIcon = Icons.assignment_late;
    } else if (startTime != null) {
      if (now.isBefore(startTime)) {
        final diff = startTime.difference(now);
        if (diff.inDays > 0) {
          statusText = "Mulai dlm ${diff.inDays} hari";
        } else {
          final h = diff.inHours.toString().padLeft(2, '0');
          final m = (diff.inMinutes % 60).toString().padLeft(2, '0');
          final s = (diff.inSeconds % 60).toString().padLeft(2, '0');
          statusText = "Mulai dlm $h:$m:$s";
        }
        statusColor = Colors.orange;
        statusIcon = Icons.upcoming;
      } else if (endTime == null || now.isBefore(endTime)) {
        statusText = "Sedang Berlangsung";
        statusColor = Colors.green;
        statusIcon = Icons.play_circle_fill;
      } else {
        statusText = "Selesai";
        statusColor = Colors.red;
        statusIcon = Icons.check_circle;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header - Micro Compact
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1A5F2D), Color(0xFF2E7D42)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        qr.pengajianTitle ?? 'Pengajian',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        "ID: ${qr.qrCode.toUpperCase()}",
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 8,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(statusIcon, color: Colors.white, size: 8),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        statusText.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Main Info - Premium Micro Layout
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoRow(
                        Icons.location_on_rounded,
                        "Lokasi",
                        qr.pengajianLocation ?? "-",
                        Colors.redAccent.shade400,
                      ),
                    ),
                    Expanded(
                      child: _buildInfoRow(
                        Icons.calendar_today_rounded,
                        "Tanggal",
                        startTime != null
                            ? "${startTime.day} ${_months[startTime.month - 1]} ${startTime.year}"
                            : "-",
                        Colors.blueAccent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoRow(
                        Icons.access_time_rounded,
                        "Jam (Mulai - Selesai)",
                        _getTimeRange(startTime, endTime),
                        Colors.green.shade600,
                      ),
                    ),
                    Expanded(
                      child: _buildInfoRow(
                        Icons.hourglass_bottom_rounded,
                        "Durasi Sesi",
                        _getFullDuration(startTime, endTime),
                        Colors.indigoAccent,
                      ),
                    ),
                  ],
                ),
                if (qr.pengajianDescription != null &&
                    qr.pengajianDescription!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _buildInfoRow(
                    Icons.description_rounded,
                    "Keterangan",
                    qr.pengajianDescription!,
                    Colors.orangeAccent.shade700,
                  ),
                ],
              ],
            ),
          ),

          // QR Code or Izin Status - Micro
          if (qr.presensiStatus == 'izin')
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  Icon(Icons.check_circle, size: 32, color: Colors.green[600]),
                  const Text(
                    "Anda Sudah Izin",
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            )
          else ...[
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 10),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade100),
              ),
              child: QrImageView(
                data: qr.qrCode,
                version: QrVersions.auto,
                size: 130, // Even smaller
                backgroundColor: Colors.white,
              ),
            ),
            // Lapor Izin Button - Ultra Slim
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => _showIzinDialog(qr),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.orange[800],
                    side: BorderSide(color: Colors.orange[300]!),
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  child: const Text(
                    "Lapor Izin",
                    style: TextStyle(fontSize: 10),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 12, color: color),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    fontSize: 7,
                    letterSpacing: 0.5,
                    color: color.withValues(alpha: 0.8),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showIzinDialog(PengajianQr qr) {
    final noteCtrl = TextEditingController();
    File? selectedImage;
    final picker = ImagePicker();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text(
              "Lapor Izin / Sakit",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Alasan Tidak Hadir:",
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: noteCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: "Contoh: Sakit flu, Kerja lembur, dll",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "Foto Bukti (Wajib Kamera):",
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
                      height: 150,
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
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.camera_alt,
                                  color: Colors.grey[400],
                                  size: 40,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  "Klik untuk ambil foto",
                                  style: TextStyle(color: Colors.grey[500]),
                                ),
                              ],
                            ),
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
                onPressed: _isProcessing
                    ? null
                    : () async {
                        if (noteCtrl.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Alasan wajib diisi")),
                          );
                          return;
                        }
                        if (selectedImage == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Foto bukti wajib")),
                          );
                          return;
                        }

                        Navigator.pop(ctx);
                        setState(() => _isProcessing = true);

                        try {
                          await _presensiService.submitLeaveRequest(
                            pengajianId: qr.pengajianId,
                            userId: widget.user.id!,
                            keterangan: noteCtrl.text.trim(),
                            imageFile: selectedImage!,
                          );
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Laporan izin terkirim!"),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("Gagal: $e"),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        } finally {
                          if (mounted) {
                            setState(() => _isProcessing = false);
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A5F2D),
                  foregroundColor: Colors.white,
                ),
                child: _isProcessing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text("Kirim Laporan"),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 60, color: Colors.grey[400]),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }

  final List<String> _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'Mei',
    'Jun',
    'Jul',
    'Ags',
    'Sep',
    'Okt',
    'Nov',
    'Des',
  ];

  String _getTimeRange(DateTime? start, DateTime? end) {
    if (start == null) return "-";
    final s =
        "${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}";
    if (end == null) return s;
    final e =
        "${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}";
    return "$s - $e";
  }

  String _getFullDuration(DateTime? start, DateTime? end) {
    if (start == null || end == null) return "-";
    final diff = end.difference(start);
    final hours = diff.inHours;
    final minutes = diff.inMinutes % 60;
    final seconds = diff.inSeconds % 60;

    List<String> parts = [];
    if (hours > 0) parts.add("${hours}j");
    if (minutes > 0) parts.add("${minutes}m");
    if (seconds > 0) parts.add("${seconds}d");

    return parts.isEmpty ? "0d" : parts.join(" ");
  }
}
