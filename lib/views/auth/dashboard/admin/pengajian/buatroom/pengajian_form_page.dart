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

    // 1. SHOW CONFIRMATION DIALOAG FIRST
    final Pengajian? confirmedProps = await showDialog<Pengajian>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PengajianConfirmationDialog(
        initialTitle: _namaController.text,
        initialLocation: _lokasiController.text,
        initialDesc: _deskripsiController.text,
        initialTargetKriteriaId: _selectedTargetKriteriaId,
        initialTargetName: _selectedTarget,
        initialDate: _selectedDate!,
        initialTime: _selectedTime!,
        systemTargets: _systemTargets,
        initialMateriGuru: widget.existing?.materiGuru ?? [],
        initialMateriIsi: widget.existing?.materiIsi,
      ),
    );

    if (confirmedProps == null) return; // Cancelled

    // 2. PROCEED TO SAVE
    setState(() => _isLoading = true);

    try {
      final finalPengajian = Pengajian(
        id: widget.existing?.id ?? '',
        orgId: widget.existing?.orgId ?? widget.orgId,
        title: confirmedProps.title, // Use value from dialog
        location: confirmedProps.location, // Use value from dialog
        description: confirmedProps.description, // Use value from dialog
        targetAudience: confirmedProps.targetAudience, // Use value from dialog
        targetKriteriaId:
            confirmedProps.targetKriteriaId, // Use value from dialog
        roomCode: _roomCodeController.text
            .trim()
            .toUpperCase(), // Keep mostly hidden
        startedAt: confirmedProps.startedAt, // Use value from dialog
        endedAt: confirmedProps.endedAt, // Use value from dialog
        materiGuru: confirmedProps.materiGuru,
        materiIsi: confirmedProps.materiIsi,
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

              // Save Button (NEXT)
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
                          'Lanjutkan: Konfirmasi',
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

// -------------------------------------------------------------------------
// NEW CONFIRMATION DIALOG CLASS
// -------------------------------------------------------------------------
class PengajianConfirmationDialog extends StatefulWidget {
  final String initialTitle;
  final String initialLocation;
  final String initialDesc;
  final String? initialTargetKriteriaId;
  final String? initialTargetName;
  final DateTime initialDate;
  final TimeOfDay initialTime;
  final List<TargetKriteria> systemTargets;
  final List<String> initialMateriGuru;
  final String? initialMateriIsi;

  const PengajianConfirmationDialog({
    super.key,
    required this.initialTitle,
    required this.initialLocation,
    required this.initialDesc,
    required this.initialTargetKriteriaId,
    required this.initialTargetName,
    required this.initialDate,
    required this.initialTime,
    required this.systemTargets,
    required this.initialMateriGuru,
    this.initialMateriIsi,
  });

  @override
  State<PengajianConfirmationDialog> createState() =>
      _PengajianConfirmationDialogState();
}

class _PengajianConfirmationDialogState
    extends State<PengajianConfirmationDialog> {
  late TextEditingController _titleCtrl;
  late TextEditingController _locCtrl;
  late TextEditingController _descCtrl;
  String? _targetId;
  String? _targetName;
  late DateTime _date;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime; // Estimated
  List<String> _materiGuru = [];
  final _guruCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.initialTitle);
    _locCtrl = TextEditingController(text: widget.initialLocation);
    _descCtrl = TextEditingController(text: widget.initialDesc);
    _targetId = widget.initialTargetKriteriaId;
    _targetName = widget.initialTargetName;
    _date = widget.initialDate;
    _startTime = widget.initialTime;

    // Estimate end time (4 hours duration default)
    final startDt = DateTime(
      2024,
      1,
      1,
      _startTime.hour,
      _startTime.minute,
    ); // dummy date
    final endDt = startDt.add(const Duration(hours: 4));
    _endTime = TimeOfDay.fromDateTime(endDt);

    _materiGuru = List.from(widget.initialMateriGuru);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _locCtrl.dispose();
    _descCtrl.dispose();
    _guruCtrl.dispose();
    super.dispose();
  }

  void _addGuru() {
    final val = _guruCtrl.text.trim();
    if (val.isNotEmpty) {
      setState(() {
        _materiGuru.add(val);
        _guruCtrl.clear();
      });
    }
  }

  void _removeGuru(int index) {
    setState(() {
      _materiGuru.removeAt(index);
    });
  }

  Future<void> _pickStartTime() async {
    final t = await showTimePicker(context: context, initialTime: _startTime);
    if (t != null) setState(() => _startTime = t);
  }

  Future<void> _pickEndTime() async {
    final t = await showTimePicker(context: context, initialTime: _endTime);
    if (t != null) setState(() => _endTime = t);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: const Color(0xFFF2F5F2), // Light greenish gray
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                "Konfirmasi Buat Pengajian",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // SECTION 1: EDITABLE INFO
              const Text(
                "Sesuaikan Info (Opsional):",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 8),
              _buildMiniField("Nama Pengajian", _titleCtrl),
              const SizedBox(height: 8),
              _buildMiniField("Lokasi", _locCtrl),
              const SizedBox(height: 8),
              _buildMiniField("Deskripsi", _descCtrl, maxLines: 2),
              const SizedBox(height: 16),

              // SECTION 2: TARGET
              const Text(
                "Target Peserta:",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.black12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _targetId,
                    isExpanded: true,
                    items: widget.systemTargets.map((t) {
                      return DropdownMenuItem(
                        value: t.id,
                        child: Text(t.namaTarget),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        _targetId = val;
                        _targetName = widget.systemTargets
                            .firstWhere((e) => e.id == val)
                            .namaTarget;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // SECTION 3: WAKTU
              const Text(
                "Waktu Pelaksanaan:",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A5F2D).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF1A5F2D).withOpacity(0.2),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_today,
                          size: 16,
                          color: Color(0xFF1A5F2D),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "${_date.day}/${_date.month}/${_date.year}",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildTimePicker("Mulai", _startTime, _pickStartTime),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          size: 16,
                          color: Colors.grey,
                        ),
                        _buildTimePicker("Selesai", _endTime, _pickEndTime),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // SECTION 4: MATERI / GURU
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Input Materi / Nasehat:",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      // Focus input
                    },
                    icon: const Icon(Icons.add_circle, size: 16),
                    label: const Text("Tambah Guru"),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF1A5F2D),
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
              if (_materiGuru.isNotEmpty) ...[
                Wrap(
                  spacing: 8,
                  children: _materiGuru.asMap().entries.map((entry) {
                    return Chip(
                      label: Text(entry.value),
                      labelStyle: const TextStyle(fontSize: 11),
                      deleteIcon: const Icon(Icons.close, size: 14),
                      onDeleted: () => _removeGuru(entry.key),
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: Colors.black12),
                      visualDensity: VisualDensity.compact,
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),
              ],
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _guruCtrl,
                      decoration: InputDecoration(
                        hintText: "Nama Guru / Pemateri...",
                        hintStyle: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[400],
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        fillColor: Colors.white,
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Colors.black12),
                        ),
                      ),
                      style: const TextStyle(fontSize: 13),
                      onSubmitted: (_) => _addGuru(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _addGuru,
                    icon: const Icon(Icons.send_rounded),
                    color: const Color(0xFF1A5F2D),
                    tooltip: "Tambah",
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // BUTTONS
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.grey[700],
                      ),
                      child: const Text("Batal"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1A5F2D),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                        elevation: 0,
                      ),
                      child: const Text("Konfirmasi & Buat"),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniField(
    String label,
    TextEditingController ctrl, {
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black12),
      ),
      padding: const EdgeInsets.only(left: 12, right: 12, top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
          TextField(
            controller: ctrl,
            decoration: const InputDecoration(
              isDense: true,
              border: InputBorder.none,
              contentPadding: EdgeInsets.only(bottom: 8, top: 4),
            ),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            maxLines: maxLines,
          ),
        ],
      ),
    );
  }

  Widget _buildTimePicker(
    String label,
    TimeOfDay time,
    VoidCallback onPressed,
  ) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.black12),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 10, color: Colors.grey[600]),
            ),
            const SizedBox(height: 2),
            Text(
              time.format(context),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  void _submit() {
    // Return a dummy Pengajian object holding our confirmed values
    final startDt = DateTime(
      _date.year,
      _date.month,
      _date.day,
      _startTime.hour,
      _startTime.minute,
    );

    // End date logic: if end time < start time, assume next day.
    var endDt = DateTime(
      _date.year,
      _date.month,
      _date.day,
      _endTime.hour,
      _endTime.minute,
    );
    if (endDt.isBefore(startDt)) {
      endDt = endDt.add(const Duration(days: 1));
    }

    final confirmed = Pengajian(
      id: '', // ignored
      orgId: '', // ignored
      title: _titleCtrl.text,
      location: _locCtrl.text,
      description: _descCtrl.text,
      targetAudience: _targetName,
      targetKriteriaId: _targetId,
      startedAt: startDt,
      endedAt: endDt,
      materiGuru: _materiGuru,
      materiIsi: widget.initialMateriIsi, // Preserve if any
      roomCode: '', // ignored
    );

    Navigator.pop(context, confirmed);
  }
}
