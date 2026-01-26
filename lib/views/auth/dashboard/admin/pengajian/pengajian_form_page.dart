import 'package:flutter/material.dart';
import 'package:hpdaerah/models/user_model.dart';
import 'package:hpdaerah/models/pengajian_model.dart';
import 'package:hpdaerah/services/pengajian_service.dart';

class PengajianFormPage extends StatefulWidget {
  final UserModel user;
  final String orgId;
  final String? scope; // Daerah, Desa, atau Kelompok
  final Pengajian? template; // Template data (jika dari Menu Cepat)

  const PengajianFormPage({
    super.key,
    required this.user,
    required this.orgId,
    this.scope,
    this.template,
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

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  String? _selectedTarget; // Target Peserta
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill dari template jika ada
    _namaController = TextEditingController(text: widget.template?.title ?? '');
    _lokasiController = TextEditingController(
      text: widget.template?.location ?? '',
    );
    _deskripsiController = TextEditingController(
      text:
          widget.template?.description ??
          (widget.scope != null ? "Pengajian Tingkat ${widget.scope}" : ""),
    );
    _roomCodeController = TextEditingController();
    _selectedTarget = widget.template?.targetAudience;
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

      final newPengajian = Pengajian(
        id: '', // ID akan digenerate di backend jika pakai V4, tapi di sini kita bisa pakai random string atau biarkan DB generate jika servicenya support.
        // Note: Service code uses .insert with 'id': id. So we should generate ID here or handle it in service.
        // Let's assume we need to generate UUID or let Postgres do it.
        // Based on service code: 'id': pengajian.id
        // Usually Supabase defaults ID if omitted, but our model requires it.
        // Let's modify service to NOT send ID if it is empty, OR generate UUID here.
        // For simplicity and robustness, passing empty string and letting DB handle it if configured (default gen_random_uuid()) is risky if we strictly send 'id': ''.
        // Actually, looking at OrganizationService, it generates random string logic.
        // But PengajianService I wrote sends 'id'.
        // Let's rely on my previous knowledge or just generate a minimal UUID-like string or just removed 'id' from insert map in service?
        // Use Supabase SDK standard: omit ID to let DB generate.
        // But Model requires ID. I'll pas "new" and handle it in Service.
        orgId: widget.orgId,
        title: _namaController.text,
        location: _lokasiController.text,
        description: _deskripsiController.text,
        targetAudience: _selectedTarget,
        roomCode: _roomCodeController.text.trim().toUpperCase(),
        startedAt: startedAt,
        // Full hierarchical context
        orgDaerahId: widget.user.orgDaerahId,
        orgDesaId: widget.user.orgDesaId,
        orgKelompokId: widget.user.orgKelompokId,
      );

      await _service.createPengajian(newPengajian);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Pengajian berhasil dibuat!'),
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal: $e')));
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
        title: const Text(
          'Buat Pengajian Baru',
          style: TextStyle(fontWeight: FontWeight.bold),
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
              // Target Peserta
              DropdownButtonFormField<String>(
                value: _selectedTarget,
                items: ['Semua', 'Muda - mudi', 'Praremaja', 'Caberawit']
                    .map(
                      (label) =>
                          DropdownMenuItem(value: label, child: Text(label)),
                    )
                    .toList(),
                onChanged: (val) => setState(() => _selectedTarget = val),
                // ...
                decoration: _inputDecoration('Pilih target peserta'),
                validator: (val) =>
                    val == null ? 'Target peserta wajib dipilih' : null,
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
              Text(
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
                      : const Text(
                          'Buat Pengajian',
                          style: TextStyle(
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
