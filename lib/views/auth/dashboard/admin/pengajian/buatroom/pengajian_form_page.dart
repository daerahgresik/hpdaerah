import 'package:flutter/material.dart';
import 'package:hpdaerah/models/user_model.dart';
import 'package:hpdaerah/models/pengajian_model.dart';
import 'package:hpdaerah/services/pengajian_service.dart';
import 'package:hpdaerah/models/target_kriteria_model.dart';
import 'package:hpdaerah/services/target_kriteria_service.dart';

class PengajianFormPage extends StatefulWidget {
  final UserModel user;
  final String orgId;
  final String? scope; // Daerah, Desa, atau Kelompok
  final Pengajian? template; // Template data (jika dari Menu Cepat)
  final Pengajian? existing; // Room yang sudah ada (untuk EDIT)

  const PengajianFormPage({
    super.key,
    required this.user,
    required this.orgId,
    this.scope,
    this.template,
    this.existing,
  });

  @override
  State<PengajianFormPage> createState() => _PengajianFormPageState();
}

class _PengajianFormPageState extends State<PengajianFormPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _namaController;
  late TextEditingController _lokasiController;
  late TextEditingController _deskripsiController;
  late TextEditingController _roomCodeController;
  final _service = PengajianService();
  final _targetService = TargetKriteriaService();

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  String? _selectedTarget; // Nama Target (Legacy/Display)
  String? _selectedTargetKriteriaId; // Link ke tabel target_kriteria
  List<TargetKriteria> _systemTargets = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill dari template atau existing jika ada
    final source = widget.existing ?? widget.template;
    _namaController = TextEditingController(text: source?.title ?? '');
    _lokasiController = TextEditingController(text: source?.location ?? '');
    _deskripsiController = TextEditingController(
      text:
          source?.description ??
          (widget.scope != null ? "Pengajian Tingkat ${widget.scope}" : ""),
    );
    _roomCodeController = TextEditingController(text: source?.roomCode ?? '');
    _selectedTarget = source?.targetAudience;
    _selectedTargetKriteriaId = source?.targetKriteriaId;

    if (widget.existing != null) {
      _selectedDate = widget.existing!.startedAt;
      _selectedTime = TimeOfDay.fromDateTime(widget.existing!.startedAt);
    }

    _loadTargets();
  }

  Future<void> _loadTargets() async {
    try {
      final targets = await _targetService.fetchAvailableTargets(
        orgId: widget.orgId,
        orgDaerahId: widget.user.orgDaerahId,
        orgDesaId: widget.user.orgDesaId,
        orgKelompokId: widget.user.orgKelompokId,
      );
      if (mounted) {
        setState(() {
          _systemTargets = targets;
        });
      }
    } catch (e) {
      debugPrint('Error loading targets: $e');
    }
  }

  @override
  void dispose() {
    _namaController.dispose();
    _lokasiController.dispose();
    _deskripsiController.dispose();
    _roomCodeController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDate == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih tanggal dan waktu pengajian')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Gabungkan Date & Time
      final startedAt = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _selectedTime!.hour,
        _selectedTime!.minute,
      );

      final finalPengajian = Pengajian(
        id: widget.existing?.id ?? '',
        orgId: widget.existing?.orgId ?? widget.orgId,
        title: _namaController.text,
        location: _lokasiController.text,
        description: _deskripsiController.text,
        targetAudience: _selectedTarget,
        targetKriteriaId: _selectedTargetKriteriaId,
        roomCode: _roomCodeController.text.trim().toUpperCase(),
        startedAt: startedAt,
        endedAt: widget.existing?.endedAt,
        // Full hierarchical context
        orgDaerahId: widget.existing?.orgDaerahId ?? widget.user.orgDaerahId,
        orgDesaId: widget.existing?.orgDesaId ?? widget.user.orgDesaId,
        orgKelompokId:
            widget.existing?.orgKelompokId ?? widget.user.orgKelompokId,
      );

      if (widget.existing != null) {
        await _service.updatePengajian(finalPengajian);
      } else {
        await _service.createPengajian(finalPengajian);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Text(
                  widget.existing != null
                      ? 'Berhasil memperbarui data!'
                      : 'Pengajian berhasil dibuat!',
                ),
              ],
            ),
            backgroundColor: const Color(0xFF1A5F2D),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        String msg = e.toString();
        if (msg.startsWith('Exception: ')) {
          msg = msg.replaceFirst('Exception: ', '');
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: Colors.red[700],
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          widget.existing != null ? 'Edit Pengajian' : 'Buat Pengajian Baru',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF1A5F2D),
        foregroundColor: Colors.white,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Nama Pengajian
              _buildLabel('Nama Pengajian'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _namaController,
                decoration: _inputDecoration('Contoh: Pengajian Rutin Ahad'),
                validator: (val) =>
                    val == null || val.isEmpty ? 'Nama wajib diisi' : null,
              ),
              const SizedBox(height: 20),

              // Lokasi
              _buildLabel('Lokasi'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _lokasiController,
                decoration: _inputDecoration('Contoh: Masjid Al-Ikhlas'),
                validator: (val) =>
                    val == null || val.isEmpty ? 'Lokasi wajib diisi' : null,
              ),
              const SizedBox(height: 20),

              // Target Peserta
              _buildLabel('Target Peserta'),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedTargetKriteriaId,
                items: _systemTargets.map((t) {
                  return DropdownMenuItem(
                    value: t.id,
                    child: Text(t.namaTarget),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedTargetKriteriaId = val;
                    _selectedTarget = _systemTargets
                        .firstWhere((element) => element.id == val)
                        .namaTarget;
                  });
                },
                decoration: _inputDecoration('Pilih target peserta'),
                validator: (val) =>
                    val == null ? 'Target peserta wajib dipilih' : null,
              ),
              if (_systemTargets.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    "* Belum ada target. Buat dulu di halaman depan Admin.",
                    style: TextStyle(color: Colors.red[700], fontSize: 11),
                  ),
                ),
              const SizedBox(height: 20),

              // Tanggal & Waktu
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('Tanggal'),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: _selectDate,
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.calendar_today,
                                  color: Colors.grey[600],
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  _selectedDate != null
                                      ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'
                                      : 'Pilih Tanggal',
                                  style: TextStyle(
                                    color: _selectedDate != null
                                        ? Colors.black87
                                        : Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('Waktu'),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: _selectTime,
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.access_time,
                                  color: Colors.grey[600],
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  _selectedTime != null
                                      ? _selectedTime!.format(context)
                                      : 'Pilih Waktu',
                                  style: TextStyle(
                                    color: _selectedTime != null
                                        ? Colors.black87
                                        : Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Deskripsi
              _buildLabel('Deskripsi (Opsional)'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _deskripsiController,
                maxLines: 3,
                decoration: _inputDecoration('Keterangan tambahan...'),
              ),
              const SizedBox(height: 20),

              // KODE ROOM
              _buildLabel('Kode Room (Opsional)'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _roomCodeController,
                textCapitalization: TextCapitalization.characters,
                decoration: _inputDecoration(
                  'Contoh: ABCDE1 (Kosongkan utk acak)',
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "* Bagikan kode ini ke Admin lain agar mereka bisa bergabung.",
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.blueGrey,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 32),

              // Save Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A5F2D),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          widget.existing != null
                              ? 'Simpan Perubahan'
                              : 'Buat Pengajian',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 14,
        color: Colors.black87,
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey[400]),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF1A5F2D), width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }
}
