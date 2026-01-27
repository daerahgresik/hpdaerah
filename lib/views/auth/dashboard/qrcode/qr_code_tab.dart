import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import 'package:hpdaerah/models/user_model.dart';
import 'package:hpdaerah/models/pengajian_qr_model.dart';
import 'package:hpdaerah/services/pengajian_qr_service.dart';
import 'package:hpdaerah/services/presensi_service.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:image_picker/image_picker.dart';

/// Smart QR Code Tab - Organized by status
class QrCodeTab extends StatefulWidget {
  final UserModel user;
  const QrCodeTab({super.key, required this.user});

  @override
  State<QrCodeTab> createState() => _QrCodeTabState();
}

class _QrCodeTabState extends State<QrCodeTab>
    with SingleTickerProviderStateMixin {
  final _qrService = PengajianQrService();
  final _presensiService = PresensiService();
  late TabController _tabController;
  late Stream<List<PengajianQr>> _qrStream;
  bool _isSubmittingIzin = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initStream();
    // Refresh UI every minute for countdowns
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
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
        automaticallyImplyLeading: false,
        elevation: 0,
        backgroundColor: const Color(0xFF1A5F2D),
        foregroundColor: Colors.white,
        title: const Text(
          'QR Code Pengajian',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          dividerColor: Colors.transparent,
          tabs: const [
            Tab(text: 'Aktif', icon: Icon(Icons.qr_code_2, size: 20)),
            Tab(text: 'Hadir', icon: Icon(Icons.check_circle, size: 20)),
            Tab(text: 'Izin', icon: Icon(Icons.event_busy, size: 20)),
          ],
        ),
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

          // Categorize QR codes
          final aktif = allQr.where((q) => !q.isUsed).toList();
          final hadir = allQr
              .where((q) => q.isUsed && q.presensiStatus == 'hadir')
              .toList();
          final izin = allQr
              .where((q) => q.isUsed && q.presensiStatus == 'izin')
              .toList();

          return TabBarView(
            controller: _tabController,
            children: [
              _buildAktifTab(aktif),
              _buildHadirTab(hadir),
              _buildIzinTab(izin),
            ],
          );
        },
      ),
    );
  }

  // ============================================================================
  // TAB 1: AKTIF - QR yang belum di-scan
  // ============================================================================
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
        padding: const EdgeInsets.all(16),
        itemCount: aktifList.length,
        itemBuilder: (context, index) {
          final qr = aktifList[index];
          return _buildQrCard(qr, isActive: true);
        },
      ),
    );
  }

  // ============================================================================
  // TAB 2: HADIR - QR yang sudah di-scan dengan status hadir
  // ============================================================================
  Widget _buildHadirTab(List<PengajianQr> hadirList) {
    if (hadirList.isEmpty) {
      return _buildEmptyState(
        icon: Icons.event_available,
        title: 'Belum Ada Kehadiran',
        subtitle: 'Scan QR Code untuk menandai kehadiran Anda',
      );
    }

    return RefreshIndicator(
      onRefresh: () async => setState(() {}),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: hadirList.length,
        itemBuilder: (context, index) {
          final qr = hadirList[index];
          return _buildCompletedCard(qr, status: 'hadir');
        },
      ),
    );
  }

  // ============================================================================
  // TAB 3: IZIN - QR dengan status izin
  // ============================================================================
  Widget _buildIzinTab(List<PengajianQr> izinList) {
    if (izinList.isEmpty) {
      return _buildEmptyState(
        icon: Icons.assignment_turned_in,
        title: 'Tidak Ada Izin',
        subtitle: 'Anda belum pernah mengajukan izin',
      );
    }

    return RefreshIndicator(
      onRefresh: () async => setState(() {}),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: izinList.length,
        itemBuilder: (context, index) {
          final qr = izinList[index];
          return _buildCompletedCard(qr, status: 'izin');
        },
      ),
    );
  }

  // ============================================================================
  // CARD BUILDERS
  // ============================================================================
  Widget _buildQrCard(PengajianQr qr, {required bool isActive}) {
    final now = DateTime.now();
    final startTime = qr.pengajianStartedAt;
    final endTime = qr.pengajianEndedAt;

    String statusText = "";
    Color statusColor = Colors.grey;
    IconData statusIcon = Icons.timer;

    if (startTime != null) {
      if (now.isBefore(startTime)) {
        final diff = startTime.difference(now);
        if (diff.inDays > 0) {
          statusText = "Mulai dlm ${diff.inDays} hari";
        } else if (diff.inHours > 0) {
          statusText =
              "Mulai dlm ${diff.inHours} jam ${diff.inMinutes % 60} mnt";
        } else {
          statusText = "Mulai dlm ${diff.inMinutes} menit";
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
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header with Gradient & Status
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color(0xFF1A5F2D), const Color(0xFF2E7D42)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.mosque,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            qr.pengajianTitle ?? 'Pengajian',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            "ID: ${qr.qrCode.toUpperCase()}",
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 10,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: statusColor.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon, color: Colors.white, size: 12),
                          const SizedBox(width: 4),
                          Text(
                            statusText,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Main Info
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Column(
              children: [
                _buildInfoRow(
                  Icons.location_on,
                  "Lokasi",
                  qr.pengajianLocation ?? "Belum ditentukan",
                  Colors.redAccent,
                ),
                const SizedBox(height: 12),
                _buildInfoRow(
                  Icons.access_time_filled,
                  "Waktu",
                  startTime != null ? _formatDateTime(startTime) : "-",
                  Colors.blueAccent,
                ),
                if (qr.pengajianDescription != null &&
                    qr.pengajianDescription!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _buildInfoRow(
                    Icons.info,
                    "Keterangan",
                    qr.pengajianDescription!,
                    Colors.orangeAccent,
                  ),
                ],
              ],
            ),
          ),

          const Divider(height: 40),

          // Instruction Text
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              "Tunjukkan QR Code ini kepada Admin untuk melakukan presensi kehadiran.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ),

          // QR Code Image
          Padding(
            padding: const EdgeInsets.all(24),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                  ),
                ],
                border: Border.all(color: Colors.grey.shade100, width: 2),
              ),
              child: QrImageView(
                data: qr.qrCode,
                version: QrVersions.auto,
                size: 180,
                backgroundColor: Colors.white,
              ),
            ),
          ),

          // Action Buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isSubmittingIzin ? null : () => _ajukanIzin(qr),
                    icon: _isSubmittingIzin
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.event_busy, size: 18),
                    label: Text(
                      _isSubmittingIzin ? 'Mengirim...' : 'Ajukan Izin',
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orange[800],
                      side: BorderSide(color: Colors.orange.shade300),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey[500],
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCompletedCard(PengajianQr qr, {required String status}) {
    final isHadir = status == 'hadir';
    final color = isHadir ? Colors.green : Colors.orange;
    final icon = isHadir ? Icons.check_circle : Icons.event_busy;
    final label = isHadir ? 'Hadir' : 'Izin';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  qr.pengajianTitle ?? 'Pengajian',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                if (qr.pengajianStartedAt != null)
                  Text(
                    _formatDateTime(qr.pengajianStartedAt!),
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
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

  // ============================================================================
  // IZIN SUBMISSION
  // ============================================================================
  void _ajukanIzin(PengajianQr qr) async {
    final picker = ImagePicker();
    final XFile? photo = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 50,
      maxWidth: 600,
    );

    if (photo == null) return;
    if (!mounted) return;

    final keteranganCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final bool? confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Keterangan Izin'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Harap berikan alasan izin Anda (Wajib diisi)',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: keteranganCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Contoh: Sedang sakit, tugas kantor, dll.',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Keterangan tidak boleh kosong';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, true);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A5F2D),
              foregroundColor: Colors.white,
            ),
            child: const Text('Kirim Izin'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isSubmittingIzin = true);
      try {
        await _presensiService.submitLeaveRequest(
          pengajianId: qr.pengajianId,
          userId: widget.user.id!,
          keterangan: keteranganCtrl.text.trim(),
          imageFile: File(photo.path),
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Izin berhasil diajukan'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal: $e'), backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) setState(() => _isSubmittingIzin = false);
      }
    }
  }

  String _formatDateTime(DateTime dt) {
    final months = [
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
    final time =
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    return '${dt.day} ${months[dt.month - 1]} ${dt.year} • $time';
  }
}
