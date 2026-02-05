import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hpdaerah/models/user_model.dart';

/// Service untuk mengelola Room Code dan penggabungan peserta dari berbagai organisasi
///
/// Fitur utama:
/// 1. Verifikasi kode room dan memungkinkan user join pengajian berdasarkan kode
/// 2. Mengelola admin dari desa/daerah berbeda yang ingin join room yang sama
/// 3. Mencatat kehadiran user yang bukan target (via manual code entry)
class RoomCodeService {
  final _client = Supabase.instance.client;

  /// Verifikasi kode room dan dapatkan detail pengajian
  ///
  /// Returns: Map dengan status dan data pengajian jika valid
  Future<Map<String, dynamic>> verifyRoomCode(String roomCode) async {
    try {
      final code = roomCode.trim().toUpperCase();

      if (code.isEmpty) {
        return {'success': false, 'error': 'Kode room tidak boleh kosong'};
      }

      // Cari pengajian berdasarkan room_code
      final response = await _client
          .from('pengajian')
          .select('''
            id, title, description, location, room_code,
            started_at, ended_at, target_audience, org_id,
            organizations:org_id (name)
          ''')
          .eq('room_code', code)
          .maybeSingle();

      if (response == null) {
        return {
          'success': false,
          'error':
              'Kode room "$code" tidak ditemukan. Pastikan kode yang Anda masukkan sudah benar.',
        };
      }

      // Cek apakah pengajian masih aktif
      final now = DateTime.now();
      final startedAt = response['started_at'] != null
          ? DateTime.parse(response['started_at'])
          : null;
      final endedAt = response['ended_at'] != null
          ? DateTime.parse(response['ended_at'])
          : null;

      String status = 'scheduled';
      if (startedAt != null) {
        if (now.isBefore(startedAt)) {
          status = 'scheduled';
        } else if (endedAt == null || now.isBefore(endedAt)) {
          status = 'active';
        } else {
          status = 'ended';
        }
      }

      return {
        'success': true,
        'pengajian': response,
        'status': status,
        'orgName': response['organizations']?['name'] ?? 'Unknown',
      };
    } catch (e) {
      debugPrint('Error verifyRoomCode: $e');
      return {'success': false, 'error': 'Terjadi kesalahan: $e'};
    }
  }

  /// Daftarkan user ke pengajian menggunakan kode room (bukan target)
  ///
  /// Ini untuk user yang bukan termasuk target tapi ingin hadir via kode
  Future<Map<String, dynamic>> joinViaRoomCode({
    required String roomCode,
    required String userId,
  }) async {
    try {
      // 1. Verifikasi kode room
      final verification = await verifyRoomCode(roomCode);
      if (!verification['success']) {
        return verification;
      }

      final pengajian = verification['pengajian'];
      final pengajianId = pengajian['id'] as String;
      final status = verification['status'] as String;

      // Cek status pengajian
      if (status == 'ended') {
        return {
          'success': false,
          'error': 'Pengajian ini sudah selesai dan tidak bisa diikuti lagi.',
        };
      }

      // 2. Cek apakah user sudah terdaftar di pengajian ini
      final existingQr = await _client
          .from('pengajian_qr')
          .select('id, presensi_status')
          .eq('pengajian_id', pengajianId)
          .eq('user_id', userId)
          .maybeSingle();

      if (existingQr != null) {
        return {
          'success': false,
          'error': 'Anda sudah terdaftar di pengajian ini.',
          'alreadyRegistered': true,
          'presensiStatus': existingQr['presensi_status'],
        };
      }

      // 3. Buat QR baru untuk user ini dengan flag manual_join
      final newQrCode =
          '${DateTime.now().millisecondsSinceEpoch}-$userId-MANUAL';

      await _client.from('pengajian_qr').insert({
        'pengajian_id': pengajianId,
        'user_id': userId,
        'qr_code': newQrCode,
        'is_used': false,
        'presensi_status': 'pending',
        'join_method': 'room_code', // Tandai bahwa join via room code
      });

      return {
        'success': true,
        'message':
            'Berhasil bergabung ke pengajian "${pengajian['title']}"! Silakan scan QR Code Anda untuk konfirmasi kehadiran.',
        'pengajian': pengajian,
      };
    } catch (e) {
      debugPrint('Error joinViaRoomCode: $e');
      return {'success': false, 'error': 'Gagal bergabung: $e'};
    }
  }

  /// Admin mengundang/membawa peserta dari organisasi lain ke room
  ///
  /// Ini untuk admin yang ingin membawa anggotanya ke pengajian di daerah lain
  Future<Map<String, dynamic>> adminBringParticipants({
    required String roomCode,
    required String adminId,
    required List<String> participantIds,
  }) async {
    try {
      // 1. Verifikasi kode room
      final verification = await verifyRoomCode(roomCode);
      if (!verification['success']) {
        return verification;
      }

      final pengajian = verification['pengajian'];
      final pengajianId = pengajian['id'] as String;

      // 2. Daftarkan semua peserta yang dibawa admin
      int successCount = 0;
      int skipCount = 0;
      final List<String> errors = [];

      for (final participantId in participantIds) {
        // Cek apakah sudah terdaftar
        final existing = await _client
            .from('pengajian_qr')
            .select('id')
            .eq('pengajian_id', pengajianId)
            .eq('user_id', participantId)
            .maybeSingle();

        if (existing != null) {
          skipCount++;
          continue;
        }

        // Buat QR baru
        final qrCode =
            '${DateTime.now().millisecondsSinceEpoch}-$participantId-ADMIN';

        try {
          await _client.from('pengajian_qr').insert({
            'pengajian_id': pengajianId,
            'user_id': participantId,
            'qr_code': qrCode,
            'is_used': false,
            'presensi_status': 'pending',
            'join_method': 'admin_invite', // Ditandai dibawa oleh admin
            'invited_by_admin_id': adminId,
          });
          successCount++;
        } catch (e) {
          errors.add('Gagal mendaftarkan peserta: $e');
        }
      }

      return {
        'success': true,
        'message': '$successCount peserta berhasil didaftarkan ke pengajian.',
        'successCount': successCount,
        'skipCount': skipCount,
        'errors': errors,
      };
    } catch (e) {
      debugPrint('Error adminBringParticipants: $e');
      return {'success': false, 'error': 'Gagal mendaftarkan peserta: $e'};
    }
  }
}

/// Widget untuk input kode room - ditampilkan ketika user tidak punya QR aktif
class RoomCodeInputCard extends StatefulWidget {
  final UserModel user;
  final VoidCallback? onJoinSuccess;

  const RoomCodeInputCard({super.key, required this.user, this.onJoinSuccess});

  @override
  State<RoomCodeInputCard> createState() => _RoomCodeInputCardState();
}

class _RoomCodeInputCardState extends State<RoomCodeInputCard> {
  final _codeController = TextEditingController();
  final _roomCodeService = RoomCodeService();
  bool _isLoading = false;
  String? _errorMessage;
  Map<String, dynamic>? _pengajianPreview;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _verifyCode() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _pengajianPreview = null;
    });

    final result = await _roomCodeService.verifyRoomCode(_codeController.text);

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result['success']) {
          _pengajianPreview = result;
        } else {
          _errorMessage = result['error'];
        }
      });
    }
  }

  Future<void> _joinRoom() async {
    if (widget.user.id == null) return;

    setState(() => _isLoading = true);

    final result = await _roomCodeService.joinViaRoomCode(
      roomCode: _codeController.text,
      userId: widget.user.id!,
    );

    if (mounted) {
      setState(() => _isLoading = false);

      if (result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Berhasil bergabung!'),
            backgroundColor: Colors.green,
          ),
        );
        widget.onJoinSuccess?.call();
        setState(() {
          _codeController.clear();
          _pengajianPreview = null;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['error'] ?? 'Gagal bergabung'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A5F2D).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.vpn_key_rounded,
                  color: Color(0xFF1A5F2D),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Gabung dengan Kode",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      "Masukkan kode room dari admin pengajian",
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Info text
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.amber.shade200),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline,
                  color: Colors.amber.shade700,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Saat ini tidak ada pengajian yang menjadikan Anda sebagai target peserta. Namun, Anda tetap bisa mengikuti pengajian lain dengan memasukkan kode room yang diberikan oleh admin.",
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.amber.shade900,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Input field
          TextField(
            controller: _codeController,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              hintText: "Contoh: ABCD1234",
              labelText: "Kode Room",
              prefixIcon: const Icon(Icons.qr_code_2),
              suffixIcon: _codeController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        setState(() {
                          _codeController.clear();
                          _pengajianPreview = null;
                          _errorMessage = null;
                        });
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Color(0xFF1A5F2D),
                  width: 2,
                ),
              ),
            ),
            onChanged: (val) {
              setState(() {
                _errorMessage = null;
                _pengajianPreview = null;
              });
            },
          ),
          const SizedBox(height: 12),

          // Error message
          if (_errorMessage != null)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    color: Colors.red.shade700,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.red.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Preview pengajian
          if (_pengajianPreview != null) ...[
            const SizedBox(height: 12),
            _buildPengajianPreview(),
          ],

          const SizedBox(height: 16),

          // Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isLoading || _codeController.text.isEmpty
                      ? null
                      : _verifyCode,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF1A5F2D),
                    side: const BorderSide(color: Color(0xFF1A5F2D)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: _isLoading && _pengajianPreview == null
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text("Cek Kode"),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isLoading || _pengajianPreview == null
                      ? null
                      : _joinRoom,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A5F2D),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: _isLoading && _pengajianPreview != null
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : const Text("Gabung"),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPengajianPreview() {
    final pengajian = _pengajianPreview!['pengajian'];
    final status = _pengajianPreview!['status'] as String;
    final orgName = _pengajianPreview!['orgName'] as String;

    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (status) {
      case 'active':
        statusColor = Colors.green;
        statusText = 'Sedang Berlangsung';
        statusIcon = Icons.play_circle_fill;
        break;
      case 'scheduled':
        statusColor = Colors.orange;
        statusText = 'Akan Datang';
        statusIcon = Icons.schedule;
        break;
      case 'ended':
        statusColor = Colors.red;
        statusText = 'Sudah Selesai';
        statusIcon = Icons.check_circle;
        break;
      default:
        statusColor = Colors.grey;
        statusText = 'Unknown';
        statusIcon = Icons.help;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A5F2D).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF1A5F2D).withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.check_circle,
                color: Color(0xFF1A5F2D),
                size: 18,
              ),
              const SizedBox(width: 6),
              const Text(
                "Kode Valid!",
                style: TextStyle(
                  color: Color(0xFF1A5F2D),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 12, color: statusColor),
                    const SizedBox(width: 4),
                    Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            pengajian['title'] ?? 'Pengajian',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.business, size: 14, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  orgName,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ),
            ],
          ),
          if (pengajian['location'] != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.location_on, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    pengajian['location'],
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
