import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hpdaerah/models/user_model.dart';
import 'package:hpdaerah/models/pengajian_qr_model.dart';
import 'package:hpdaerah/services/pengajian_qr_service.dart';
import 'package:hpdaerah/services/presensi_service.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:image_picker/image_picker.dart';

/// QR Code Tab - Menampilkan QR Code berbasis pengajian
/// 3 State:
/// 1. Tidak ada pengajian aktif
/// 2. Ada QR aktif (belum dipakai)
/// 3. Sudah presensi (QR sudah dipakai)
class QrCodeTab extends StatefulWidget {
  final UserModel user;
  const QrCodeTab({super.key, required this.user});

  @override
  State<QrCodeTab> createState() => _QrCodeTabState();
}

class _QrCodeTabState extends State<QrCodeTab> {
  final _qrService = PengajianQrService();
  final _presensiService = PresensiService();
  int _currentIndex = 0;
  bool _isSubmittingIzin = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.user.id == null) {
      return const Center(child: Text('User ID null'));
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: StreamBuilder<List<PengajianQr>>(
        stream: _qrService.streamActiveQrForUser(widget.user.id!),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF1A5F2D)),
            );
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final list = snapshot.data ?? [];

          if (list.isEmpty) {
            return RefreshIndicator(
              onRefresh: () async => setState(() {}),
              color: const Color(0xFF1A5F2D),
              child: _buildNoQrState(),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => setState(() {}),
            color: const Color(0xFF1A5F2D),
            child: _buildQrCardView(list),
          );
        },
      ),
    );
  }

  void _ajukanIzin(PengajianQr qr) async {
    final picker = ImagePicker();
    // Live camera only - no source selection allowed
    final XFile? photo = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 50,
      maxWidth: 600,
    );

    if (photo == null) return;

    if (!mounted) return;

    final keteranganCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    // Show dialog for mandatory description
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

  /// State: Tidak ada pengajian aktif
  Widget _buildNoQrState() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: SizedBox(
        height: MediaQuery.of(context).size.height - 200,
        child: Center(
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
                  child: Icon(
                    Icons.qr_code_2,
                    size: 80,
                    color: Colors.grey[400],
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'Tidak Ada Pengajian',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Saat ini Anda tidak memiliki tugas pengajian yang harus dihadiri.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey[500],
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue[100]!),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 18,
                        color: Colors.blue[700],
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Hubungi admin jika ada pertanyaan',
                        style: TextStyle(color: Colors.blue[700], fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// State: Ada QR aktif
  Widget _buildQrCardView(List<PengajianQr> activeQrList) {
    return Column(
      children: [
        // Header dengan counter
        if (activeQrList.length > 1)
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.swipe, size: 16, color: Colors.grey[500]),
                const SizedBox(width: 8),
                Text(
                  'Geser untuk melihat pengajian lainnya',
                  style: TextStyle(color: Colors.grey[500], fontSize: 13),
                ),
              ],
            ),
          ),

        // Dots indicator
        if (activeQrList.length > 1)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(activeQrList.length, (index) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: _currentIndex == index ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _currentIndex == index
                      ? const Color(0xFF1A5F2D)
                      : Colors.grey[300],
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),

        // PageView dengan QR Cards
        Expanded(
          child: PageView.builder(
            itemCount: activeQrList.length,
            onPageChanged: (index) {
              setState(() => _currentIndex = index);
            },
            itemBuilder: (context, index) {
              return _buildQrCard(activeQrList[index]);
            },
          ),
        ),
        const SizedBox(height: 80), // Space for bottom nav
      ],
    );
  }

  /// QR Card untuk satu pengajian
  Widget _buildQrCard(PengajianQr qr) {
    final isUsed = qr.isUsed;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Main Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              children: [
                // Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isUsed ? Colors.green[50] : Colors.orange[50],
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isUsed ? Colors.green[200]! : Colors.orange[200]!,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isUsed ? Icons.check_circle : Icons.pending,
                        size: 18,
                        color: isUsed ? Colors.green[700] : Colors.orange[700],
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isUsed ? 'PRESENSI BERHASIL' : 'MENUNGGU PRESENSI',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isUsed
                              ? Colors.green[700]
                              : Colors.orange[700],
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // QR Code atau Success Message
                if (isUsed) _buildSuccessState(qr) else _buildQrCodeDisplay(qr),

                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),

                // Pengajian Info
                _buildPengajianInfo(qr),
              ],
            ),
          ),

          // Warning / Info Box
          if (!isUsed) ...[
            const SizedBox(height: 16),
            _buildWarningBox(),
            const SizedBox(height: 24),
            // Leave Request Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSubmittingIzin ? null : () => _ajukanIzin(qr),
                icon: _isSubmittingIzin
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.assignment_late_outlined),
                label: Text(_isSubmittingIzin ? 'Mengirim...' : 'Ajukan Izin'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange[700],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 2,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// QR Code Display (belum dipakai)
  Widget _buildQrCodeDisplay(PengajianQr qr) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1A5F2D).withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFF1A5F2D).withValues(alpha: 0.1),
              width: 2,
            ),
          ),
          child: QrImageView(
            data: qr.qrCode,
            version: QrVersions.auto,
            size: 200.0,
            backgroundColor: Colors.transparent,
            eyeStyle: const QrEyeStyle(
              eyeShape: QrEyeShape.square,
              color: Color(0xFF1A5F2D),
            ),
            dataModuleStyle: const QrDataModuleStyle(
              dataModuleShape: QrDataModuleShape.square,
              color: Color(0xFF1A5F2D),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            'Kode Unik Anda',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    );
  }

  /// Success State (sudah presensi / izin)
  Widget _buildSuccessState(PengajianQr qr) {
    final isIzin = qr.presensiStatus == 'izin';

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isIzin ? Colors.orange[50] : Colors.green[50],
            shape: BoxShape.circle,
          ),
          child: Icon(
            isIzin ? Icons.assignment_turned_in : Icons.check_circle,
            size: 80,
            color: isIzin ? Colors.orange[600] : Colors.green[600],
          ),
        ),
        const SizedBox(height: 20),
        Text(
          isIzin ? 'Izin Telah Dicatat' : 'Anda Telah Hadir!',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isIzin ? Colors.orange[700] : Colors.green[700],
          ),
        ),
        if (qr.usedAt != null) ...[
          const SizedBox(height: 8),
          Text(
            isIzin
                ? 'Diajukan pada: ${_formatTime(qr.usedAt!)}'
                : 'Hadir pada: ${_formatTime(qr.usedAt!)}',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
        ],
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: isIzin ? Colors.orange[100] : Colors.green[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            isIzin
                ? 'Keterangan izin telah terkirim ke Admin.'
                : '🎉 Semoga berkah dan bermanfaat!',
            style: TextStyle(
              fontSize: 14,
              color: isIzin ? Colors.orange[800] : Colors.green[800],
            ),
          ),
        ),
      ],
    );
  }

  /// Info Pengajian
  Widget _buildPengajianInfo(PengajianQr qr) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          qr.pengajianTitle ?? 'Pengajian',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A5F2D),
          ),
        ),
        const SizedBox(height: 16),

        _buildInfoRow(
          Icons.location_on,
          qr.pengajianLocation ?? 'Lokasi tidak ditentukan',
          Colors.red[400]!,
        ),
        const SizedBox(height: 12),

        _buildInfoRow(
          Icons.calendar_today,
          qr.pengajianStartedAt != null
              ? _formatDateTime(qr.pengajianStartedAt!)
              : 'Waktu tidak ditentukan',
          Colors.blue[400]!,
        ),
        const SizedBox(height: 12),

        _buildInfoRow(
          Icons.groups,
          'Target: ${qr.targetAudience ?? 'Semua'}',
          Colors.orange[400]!,
        ),

        if (qr.pengajianDescription != null &&
            qr.pengajianDescription!.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            qr.pengajianDescription!,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              height: 1.5,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String text, Color iconColor) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: iconColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 14, color: Colors.grey[700]),
          ),
        ),
      ],
    );
  }

  /// Warning Box
  Widget _buildWarningBox() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber[200]!),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Colors.amber[700],
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Perhatian',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.amber[800],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildWarningItem('Tunjukkan QR ini ke Admin saat hadir'),
          const SizedBox(height: 8),
          _buildWarningItem('QR hanya bisa digunakan SEKALI'),
          const SizedBox(height: 8),
          _buildWarningItem('Jangan bagikan QR ini ke orang lain'),
        ],
      ),
    );
  }

  Widget _buildWarningItem(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('• ', style: TextStyle(color: Colors.amber[700], fontSize: 14)),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: Colors.amber[800],
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  String _formatDateTime(DateTime dt) {
    final days = [
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu',
      'Minggu',
    ];
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    return '${days[dt.weekday - 1]}, ${dt.day} ${months[dt.month - 1]} ${dt.year} • ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} WIB';
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} WIB';
  }
}
