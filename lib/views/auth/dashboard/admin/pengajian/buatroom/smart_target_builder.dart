import 'package:flutter/material.dart';
import 'package:hpdaerah/models/target_kriteria_model.dart';
import 'package:hpdaerah/services/kelas_service.dart';
import 'package:hpdaerah/services/target_kriteria_service.dart';

/// Mode target pemilihan peserta
enum TargetMode { all, kelas, kriteria }

/// Widget Smart Target Builder untuk memilih target peserta
class SmartTargetBuilder extends StatefulWidget {
  final String orgId;
  final int adminLevel;
  final List<TargetKriteria> systemTargets;
  final ValueChanged<TargetSelection> onSelectionChanged;
  final TargetSelection? initialSelection;
  final VoidCallback? onKriteriaCreated; // Callback to refresh kriteria list

  const SmartTargetBuilder({
    super.key,
    required this.orgId,
    required this.adminLevel,
    required this.systemTargets,
    required this.onSelectionChanged,
    this.initialSelection,
    this.onKriteriaCreated,
  });

  @override
  State<SmartTargetBuilder> createState() => _SmartTargetBuilderState();
}

class _SmartTargetBuilderState extends State<SmartTargetBuilder> {
  final _kelasService = KelasService();
  final _targetService = TargetKriteriaService();

  TargetMode _mode = TargetMode.all;
  List<Map<String, dynamic>> _kelasList = [];
  Set<String> _selectedKelasIds = {};
  String? _selectedKriteriaId;
  bool _isLoading = true;

  // Estimation
  int _estimatedCount = 0;
  List<Map<String, dynamic>> _breakdown = [];

  @override
  void initState() {
    super.initState();
    _loadKelasList();

    // Apply initial selection if provided
    if (widget.initialSelection != null) {
      _mode = widget.initialSelection!.mode;
      _selectedKelasIds = Set.from(widget.initialSelection!.kelasIds ?? []);
      _selectedKriteriaId = widget.initialSelection!.kriteriaId;
    }
  }

  Future<void> _loadKelasList() async {
    try {
      final list = await _kelasService.getKelasListForRoomTarget(
        orgId: widget.orgId,
        adminLevel: widget.adminLevel,
      );
      if (mounted) {
        setState(() {
          _kelasList = list;
          _isLoading = false;
        });
        _updateEstimate();
      }
    } catch (e) {
      debugPrint("Error loading kelas: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateEstimate() async {
    // Collect all kelas IDs from selected normalized names
    List<String> allKelasIds = [];
    for (final kelasData in _kelasList) {
      final normalized = kelasData['normalizedName'] as String;
      if (_selectedKelasIds.contains(normalized)) {
        allKelasIds.addAll((kelasData['kelasIds'] as List<String>));
      }
    }

    try {
      final estimate = await _kelasService.getTargetEstimate(
        orgId: widget.orgId,
        adminLevel: widget.adminLevel,
        targetMode: _mode.name,
        targetKelasIds: allKelasIds.isNotEmpty ? allKelasIds : null,
        targetKriteriaId: _selectedKriteriaId,
      );

      if (mounted) {
        setState(() {
          _estimatedCount = estimate['total'] as int;
          _breakdown = List<Map<String, dynamic>>.from(
            estimate['breakdown'] as List,
          );
        });

        // Notify parent
        widget.onSelectionChanged(
          TargetSelection(
            mode: _mode,
            kelasIds: allKelasIds,
            kriteriaId: _selectedKriteriaId,
            estimatedCount: _estimatedCount,
          ),
        );
      }
    } catch (e) {
      debugPrint("Error updating estimate: $e");
    }
  }

  void _onModeChanged(TargetMode mode) {
    setState(() {
      _mode = mode;
      // Reset selections when mode changes
      if (mode == TargetMode.all) {
        _selectedKelasIds.clear();
        _selectedKriteriaId = null;
      }
    });
    _updateEstimate();
  }

  void _toggleKelas(String normalizedName) {
    setState(() {
      if (_selectedKelasIds.contains(normalizedName)) {
        _selectedKelasIds.remove(normalizedName);
      } else {
        _selectedKelasIds.add(normalizedName);
      }
    });
    _updateEstimate();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Mode Selector
        _buildModeSelector(),
        const SizedBox(height: 16),

        // Mode-specific content
        if (_isLoading)
          const Center(child: CircularProgressIndicator())
        else if (_mode == TargetMode.kelas)
          _buildKelasSelector()
        else if (_mode == TargetMode.kriteria)
          _buildKriteriaSelector(),

        const SizedBox(height: 16),

        // Preview Estimasi
        _buildEstimatePreview(),
      ],
    );
  }

  Widget _buildModeSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _buildModeButton(
            label: "Semua",
            icon: Icons.groups_rounded,
            mode: TargetMode.all,
          ),
          _buildModeButton(
            label: "Per Kelas",
            icon: Icons.school_rounded,
            mode: TargetMode.kelas,
          ),
          _buildModeButton(
            label: "Kriteria",
            icon: Icons.filter_list_rounded,
            mode: TargetMode.kriteria,
          ),
        ],
      ),
    );
  }

  Widget _buildModeButton({
    required String label,
    required IconData icon,
    required TargetMode mode,
  }) {
    final isSelected = _mode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => _onModeChanged(mode),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF1A5F2D) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? Colors.white : Colors.grey[600],
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKelasSelector() {
    if (_kelasList.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.orange[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange[700]),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                "Belum ada kelas di wilayah ini. Buat kelas dulu di menu Atur Kelas.",
                style: TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Pilih kelas yang menjadi target:",
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _kelasList.map((kelas) {
            final normalized = kelas['normalizedName'] as String;
            final displayName = kelas['displayName'] as String;
            final memberCount = kelas['memberCount'] as int;
            final isSelected = _selectedKelasIds.contains(normalized);

            return FilterChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(displayName),
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.white.withValues(alpha: 0.3)
                          : Colors.grey[200],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      "$memberCount",
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : Colors.grey[700],
                      ),
                    ),
                  ),
                ],
              ),
              selected: isSelected,
              onSelected: (_) => _toggleKelas(normalized),
              selectedColor: const Color(0xFF1A5F2D),
              checkmarkColor: Colors.white,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.black87,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildKriteriaSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with "Buat Kriteria Baru" button
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Pilih kriteria target:",
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
            TextButton.icon(
              onPressed: () => _showAddKriteriaDialog(),
              icon: const Icon(Icons.add, size: 16),
              label: const Text("Buat Baru", style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                visualDensity: VisualDensity.compact,
                foregroundColor: const Color(0xFF1A5F2D),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        if (widget.systemTargets.isEmpty)
          // Empty state with create button
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                Icon(Icons.filter_list_off, color: Colors.grey[400], size: 32),
                const SizedBox(height: 8),
                const Text(
                  "Belum ada kriteria target",
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Text(
                  "Buat kriteria untuk filter peserta berdasarkan umur, jenis kelamin, dll.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () => _showAddKriteriaDialog(),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text("Buat Kriteria Pertama"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A5F2D),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          )
        else
          // Kriteria list with actions
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              children: widget.systemTargets.asMap().entries.map((entry) {
                final idx = entry.key;
                final t = entry.value;
                final isSelected = _selectedKriteriaId == t.id;
                final isLast = idx == widget.systemTargets.length - 1;

                return Column(
                  children: [
                    InkWell(
                      onTap: () {
                        setState(() => _selectedKriteriaId = t.id);
                        _updateEstimate();
                      },
                      borderRadius: BorderRadius.vertical(
                        top: idx == 0 ? const Radius.circular(12) : Radius.zero,
                        bottom: isLast
                            ? const Radius.circular(12)
                            : Radius.zero,
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF1A5F2D).withValues(alpha: 0.1)
                              : Colors.transparent,
                          borderRadius: BorderRadius.vertical(
                            top: idx == 0
                                ? const Radius.circular(12)
                                : Radius.zero,
                            bottom: isLast
                                ? const Radius.circular(12)
                                : Radius.zero,
                          ),
                        ),
                        child: Row(
                          children: [
                            // Radio indicator
                            Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFF1A5F2D)
                                      : Colors.grey.shade400,
                                  width: 2,
                                ),
                              ),
                              child: isSelected
                                  ? Center(
                                      child: Container(
                                        width: 10,
                                        height: 10,
                                        decoration: const BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Color(0xFF1A5F2D),
                                        ),
                                      ),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            // Content
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    t.namaTarget,
                                    style: TextStyle(
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.w500,
                                      color: isSelected
                                          ? const Color(0xFF1A5F2D)
                                          : Colors.black87,
                                    ),
                                  ),
                                  Text(
                                    _buildKriteriaSubtitle(t),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Action buttons
                            IconButton(
                              icon: Icon(
                                Icons.info_outline,
                                size: 18,
                                color: Colors.blue[600],
                              ),
                              onPressed: () => _showKriteriaDetailDialog(t),
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 32,
                                minHeight: 32,
                              ),
                              tooltip: "Lihat Detail",
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.edit_outlined,
                                size: 18,
                                color: Colors.orange[700],
                              ),
                              onPressed: () => _showEditKriteriaDialog(t),
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 32,
                                minHeight: 32,
                              ),
                              tooltip: "Edit",
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.delete_outline,
                                size: 18,
                                color: Colors.red[600],
                              ),
                              onPressed: () => _confirmDeleteKriteria(t),
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 32,
                                minHeight: 32,
                              ),
                              tooltip: "Hapus",
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (!isLast)
                      Divider(height: 1, color: Colors.grey.shade200),
                  ],
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  void _showKriteriaDetailDialog(TargetKriteria t) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF1A5F2D).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.filter_list,
                color: Color(0xFF1A5F2D),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(t.namaTarget)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow("Umur", "${t.minUmur} - ${t.maxUmur} tahun"),
            _buildDetailRow("Jenis Kelamin", t.jenisKelamin),
            _buildDetailRow("Status Warga", t.statusWarga),
            _buildDetailRow("Keperluan", t.keperluan),
            _buildDetailRow("Status Pernikahan", t.statusPernikahan),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Tutup"),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600])),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  void _showEditKriteriaDialog(TargetKriteria t) {
    final namaController = TextEditingController(text: t.namaTarget);
    int minUmur = t.minUmur;
    int maxUmur = t.maxUmur;
    String jenisKelamin = t.jenisKelamin;
    String statusWarga = t.statusWarga;
    String keperluan = t.keperluan;
    String statusPernikahan = t.statusPernikahan;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text('Edit Kriteria'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: namaController,
                    decoration: const InputDecoration(
                      labelText: 'Nama Kriteria',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "Range Umur",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          keyboardType: TextInputType.number,
                          controller: TextEditingController(
                            text: minUmur.toString(),
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Min',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          onChanged: (val) => minUmur = int.tryParse(val) ?? 0,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          keyboardType: TextInputType.number,
                          controller: TextEditingController(
                            text: maxUmur.toString(),
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Max',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          onChanged: (val) =>
                              maxUmur = int.tryParse(val) ?? 100,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: jenisKelamin,
                    decoration: const InputDecoration(
                      labelText: 'Jenis Kelamin',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: ['Semua', 'Laki-laki', 'Perempuan']
                        .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                        .toList(),
                    onChanged: (val) =>
                        setStateDialog(() => jenisKelamin = val ?? 'Semua'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: statusWarga,
                    decoration: const InputDecoration(
                      labelText: 'Status Warga',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: ['Semua', 'Aktif', 'Tidak Aktif']
                        .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                        .toList(),
                    onChanged: (val) =>
                        setStateDialog(() => statusWarga = val ?? 'Semua'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: keperluan,
                    decoration: const InputDecoration(
                      labelText: 'Keperluan',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: ['Semua', 'Menetap', 'Merantau']
                        .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                        .toList(),
                    onChanged: (val) =>
                        setStateDialog(() => keperluan = val ?? 'Semua'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: statusPernikahan,
                    decoration: const InputDecoration(
                      labelText: 'Status Pernikahan',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: ['Semua', 'Menikah', 'Belum Menikah', 'Duda/Janda']
                        .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                        .toList(),
                    onChanged: (val) =>
                        setStateDialog(() => statusPernikahan = val ?? 'Semua'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (namaController.text.isEmpty) return;

                  final updated = TargetKriteria(
                    id: t.id,
                    orgId: t.orgId,
                    namaTarget: namaController.text,
                    minUmur: minUmur,
                    maxUmur: maxUmur,
                    jenisKelamin: jenisKelamin,
                    statusWarga: statusWarga,
                    keperluan: keperluan,
                    statusPernikahan: statusPernikahan,
                  );

                  await _targetService.updateTarget(updated);
                  Navigator.pop(ctx);
                  widget.onKriteriaCreated?.call();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A5F2D),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Simpan'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _confirmDeleteKriteria(TargetKriteria t) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus Kriteria?'),
        content: Text(
          'Apakah Anda yakin ingin menghapus kriteria "${t.namaTarget}"? Tindakan ini tidak dapat dibatalkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              await _targetService.deleteTarget(t.id);
              Navigator.pop(ctx);
              widget.onKriteriaCreated?.call();
              if (_selectedKriteriaId == t.id) {
                setState(() => _selectedKriteriaId = null);
                _updateEstimate();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  void _showAddKriteriaDialog() {
    final namaController = TextEditingController();
    int minUmur = 0;
    int maxUmur = 100;
    String jenisKelamin = 'Semua';
    String statusWarga = 'Semua';
    String keperluan = 'Semua';
    String statusPernikahan = 'Semua';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text('Buat Kriteria Baru'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: namaController,
                    decoration: const InputDecoration(
                      labelText: 'Nama Kriteria',
                      hintText: 'Contoh: Pemuda 17-25 Tahun',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Range Umur
                  const Text(
                    "Range Umur",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Min',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          onChanged: (val) => minUmur = int.tryParse(val) ?? 0,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Max',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          onChanged: (val) =>
                              maxUmur = int.tryParse(val) ?? 100,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Jenis Kelamin
                  DropdownButtonFormField<String>(
                    value: jenisKelamin,
                    decoration: const InputDecoration(
                      labelText: 'Jenis Kelamin',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: ['Semua', 'Laki-laki', 'Perempuan']
                        .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                        .toList(),
                    onChanged: (val) =>
                        setStateDialog(() => jenisKelamin = val ?? 'Semua'),
                  ),
                  const SizedBox(height: 12),

                  // Status Warga
                  DropdownButtonFormField<String>(
                    value: statusWarga,
                    decoration: const InputDecoration(
                      labelText: 'Status Warga',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: ['Semua', 'Aktif', 'Tidak Aktif']
                        .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                        .toList(),
                    onChanged: (val) =>
                        setStateDialog(() => statusWarga = val ?? 'Semua'),
                  ),
                  const SizedBox(height: 12),

                  // Keperluan
                  DropdownButtonFormField<String>(
                    value: keperluan,
                    decoration: const InputDecoration(
                      labelText: 'Keperluan',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: ['Semua', 'Menetap', 'Merantau']
                        .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                        .toList(),
                    onChanged: (val) =>
                        setStateDialog(() => keperluan = val ?? 'Semua'),
                  ),
                  const SizedBox(height: 12),

                  // Status Pernikahan
                  DropdownButtonFormField<String>(
                    value: statusPernikahan,
                    decoration: const InputDecoration(
                      labelText: 'Status Pernikahan',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: ['Semua', 'Menikah', 'Belum Menikah', 'Duda/Janda']
                        .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                        .toList(),
                    onChanged: (val) =>
                        setStateDialog(() => statusPernikahan = val ?? 'Semua'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (namaController.text.isEmpty) return;

                  final newTarget = TargetKriteria(
                    id: '',
                    orgId: widget.orgId,
                    namaTarget: namaController.text,
                    minUmur: minUmur,
                    maxUmur: maxUmur,
                    jenisKelamin: jenisKelamin,
                    statusWarga: statusWarga,
                    keperluan: keperluan,
                    statusPernikahan: statusPernikahan,
                  );

                  await _targetService.createTarget(newTarget);
                  Navigator.pop(ctx);

                  // Notify parent to refresh kriteria list
                  widget.onKriteriaCreated?.call();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A5F2D),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Simpan'),
              ),
            ],
          );
        },
      ),
    );
  }

  String _buildKriteriaSubtitle(TargetKriteria k) {
    final parts = <String>[];
    if (k.minUmur > 0 || k.maxUmur < 100) {
      parts.add("${k.minUmur}-${k.maxUmur} thn");
    }
    if (k.jenisKelamin != 'Semua') parts.add(k.jenisKelamin);
    if (k.statusWarga != 'Semua') parts.add(k.statusWarga);
    if (k.keperluan != 'Semua') parts.add(k.keperluan);
    if (k.statusPernikahan != 'Semua') parts.add(k.statusPernikahan);
    return parts.isEmpty ? "Semua anggota" : parts.join(" • ");
  }

  Widget _buildEstimatePreview() {
    final modeLabel = switch (_mode) {
      TargetMode.all => "Semua Anggota",
      TargetMode.kelas => "${_selectedKelasIds.length} kelas dipilih",
      TargetMode.kriteria =>
        _selectedKriteriaId != null
            ? widget.systemTargets
                  .firstWhere((t) => t.id == _selectedKriteriaId)
                  .namaTarget
            : "Belum dipilih",
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1A5F2D).withValues(alpha: 0.1),
            const Color(0xFF2E8B57).withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF1A5F2D).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1A5F2D),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.people, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Estimasi Target",
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(height: 2),
                Text(
                  "$_estimatedCount peserta",
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A5F2D),
                  ),
                ),
                Text(
                  modeLabel,
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
          if (_breakdown.length > 1)
            IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: () => _showBreakdownDialog(),
              tooltip: "Lihat Detail",
            ),
        ],
      ),
    );
  }

  void _showBreakdownDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Detail Estimasi"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: _breakdown.map((b) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(b['label'] as String),
                  Text(
                    "${b['count']} anggota",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Tutup"),
          ),
        ],
      ),
    );
  }
}

/// Model untuk menyimpan hasil seleksi target
class TargetSelection {
  final TargetMode mode;
  final List<String>? kelasIds;
  final String? kriteriaId;
  final int estimatedCount;

  TargetSelection({
    required this.mode,
    this.kelasIds,
    this.kriteriaId,
    required this.estimatedCount,
  });

  String get modeString {
    switch (mode) {
      case TargetMode.all:
        return 'all';
      case TargetMode.kelas:
        return 'kelas';
      case TargetMode.kriteria:
        return 'kriteria';
    }
  }
}
