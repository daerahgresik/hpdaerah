import 'package:flutter/material.dart';
import 'dart:async';
import 'package:hpdaerah/models/user_model.dart';
import 'package:hpdaerah/models/pengajian_qr_model.dart';
import 'package:hpdaerah/services/pengajian_qr_service.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Smart QR Code Tab - Strictly for Active QR Codes
class QrCodeTab extends StatefulWidget {
  final UserModel user;
  const QrCodeTab({super.key, required this.user});

  @override
  State<QrCodeTab> createState() => _QrCodeTabState();
}

class _QrCodeTabState extends State<QrCodeTab> {
  final _qrService = PengajianQrService();
  late Stream<List<PengajianQr>> _qrStream;
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
        padding: const EdgeInsets.all(16),
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

    if (startTime != null) {
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
          const SizedBox(height: 16), // Padding bottom for the card
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
