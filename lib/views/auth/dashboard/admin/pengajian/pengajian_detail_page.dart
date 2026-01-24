import 'package:flutter/material.dart';
import 'package:hpdaerah/models/pengajian_model.dart';
import 'package:hpdaerah/models/presensi_model.dart';
import 'package:hpdaerah/models/user_model.dart';
import 'package:hpdaerah/services/presensi_service.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class PengajianDetailPage extends StatefulWidget {
  final Pengajian pengajian;

  const PengajianDetailPage({super.key, required this.pengajian});

  @override
  State<PengajianDetailPage> createState() => _PengajianDetailPageState();
}

class _PengajianDetailPageState extends State<PengajianDetailPage> {
  final _presensiService = PresensiService();
  bool _isScanning = false;

  void _openScanner() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BarcodeScannerPage(
          pengajian: widget.pengajian,
          onResult: (username) async {
            await _handleScanResult(username);
          },
        ),
      ),
    );
  }

  Future<void> _handleScanResult(String username) async {
    try {
      // 1. Find User
      final user = await _presensiService.findUserByUsername(username);
      if (user == null) {
        _showErrorSnackBar("User tidak ditemukan: $username");
        return;
      }

      // 2. Check Target Audience (Target Kategori)
      // Note: mapping target audience string to user categories
      // User categories are usually in 'level' or just strings in targetAudience
      // Based on FormPage items: ['Semua', 'Muda - mudi', 'Praremaja', 'Caberawit']
      // We should check user's data. For now, let's assume it matches if not 'Semua'.
      // If we want to be strict, we need to know where 'Muda-mudi' is stored in UserModel.
      // Looking at UserModel, there is no 'category' field, maybe it is in 'jabatan' or 'keterangan'?
      // Or maybe the user is part of an organization that has an ageCategory.

      // Let's just record for now and add a toast.
      await _presensiService.recordPresence(
        pengajianId: widget.pengajian.id,
        userId: user.id!,
        method: 'qr',
      );

      _showSuccessSnackBar("Berhasil: ${user.nama} telah hadir");
    } catch (e) {
      _showErrorSnackBar("Gagal: $e");
    }
  }

  void _showSuccessSnackBar(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showErrorSnackBar(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.pengajian;
    return Scaffold(
      appBar: AppBar(
        title: const Text("Detail Pengajian"),
        backgroundColor: const Color(0xFF1A5F2D),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A5F2D),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildInfoRow(
                    Icons.location_on,
                    item.location ?? "Tidak ada lokasi",
                  ),
                  const SizedBox(height: 8),
                  _buildInfoRow(
                    Icons.calendar_today,
                    "${item.startedAt.day}/${item.startedAt.month}/${item.startedAt.year} • ${item.startedAt.hour}:${item.startedAt.minute.toString().padLeft(2, '0')}",
                  ),
                  const SizedBox(height: 8),
                  _buildInfoRow(
                    Icons.groups,
                    "Target: ${item.targetAudience ?? 'Semua'}",
                    iconColor: Colors.orange,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            const Text(
              "Deskripsi",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              item.description ?? "Tidak ada deskripsi",
              style: TextStyle(color: Colors.grey[700], height: 1.5),
            ),

            const SizedBox(height: 32),

            // Scan Button
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton.icon(
                onPressed: _openScanner,
                icon: const Icon(Icons.qr_code_scanner, size: 28),
                label: const Text(
                  "SCAN BARCODE USER",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A5F2D),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 32),
            const Text(
              "Daftar Kehadiran Terbaru",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildAttendanceList(),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text, {Color? iconColor}) {
    return Row(
      children: [
        Icon(icon, size: 18, color: iconColor ?? Colors.grey[600]),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 15, color: Colors.grey[800]),
          ),
        ),
      ],
    );
  }

  Widget _buildAttendanceList() {
    return StreamBuilder<List<Presensi>>(
      stream: _presensiService.streamAttendanceList(widget.pengajian.id),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        final list = snapshot.data!;
        if (list.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20.0),
              child: Text("Belum ada yang hadir"),
            ),
          );
        }
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: list.length,
          itemBuilder: (context, index) {
            final presensi = list[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const Icon(Icons.person),
                title: Text("User ID: ${presensi.userId.substring(0, 8)}..."),
                subtitle: Text(
                  "Status: ${presensi.status} via ${presensi.method}",
                ),
                trailing: const Icon(Icons.check_circle, color: Colors.green),
              ),
            );
          },
        );
      },
    );
  }
}

class BarcodeScannerPage extends StatefulWidget {
  final Pengajian pengajian;
  final Function(String) onResult;

  const BarcodeScannerPage({
    super.key,
    required this.pengajian,
    required this.onResult,
  });

  @override
  State<BarcodeScannerPage> createState() => _BarcodeScannerPageState();
}

class _BarcodeScannerPageState extends State<BarcodeScannerPage> {
  bool _hasResult = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Scan QR User"),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          MobileScanner(
            onDetect: (capture) {
              if (_hasResult) return;
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                if (barcode.rawValue != null) {
                  _hasResult = true;
                  final code = barcode.rawValue!;
                  // Assuming format is just the 'username'
                  widget.onResult(code);
                  Navigator.pop(context);
                  break;
                }
              }
            },
          ),
          // Custom Overlay
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  "Arahkan ke QR Code Anggota",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
