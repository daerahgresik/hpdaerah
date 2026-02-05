import 'package:flutter/material.dart';
import 'package:hpdaerah/models/user_model.dart';
import 'package:hpdaerah/models/pengajian_model.dart';
import 'package:hpdaerah/services/pengajian_service.dart';
import 'package:hpdaerah/services/organization_service.dart';
import 'package:hpdaerah/models/organization_model.dart';
import 'package:hpdaerah/services/target_kriteria_service.dart';
import 'package:hpdaerah/models/target_kriteria_model.dart';
import 'package:hpdaerah/views/auth/dashboard/admin/pengajian/buatroom/smart_target_builder.dart';

class PengajianLevelSelector extends StatefulWidget {
  final UserModel user;
  final String orgId;
  final int adminLevel;

  const PengajianLevelSelector({
    super.key,
    required this.user,
    required this.orgId,
    required this.adminLevel,
  });

  @override
  State<PengajianLevelSelector> createState() => _PengajianLevelSelectorState();
}

class _PengajianLevelSelectorState extends State<PengajianLevelSelector> {
  final _pengajianService = PengajianService();
  final _orgService = OrganizationService();
  final _targetService = TargetKriteriaService();
  late Stream<List<Pengajian>> _templatesStream;
  List<TargetKriteria> _targetList = [];

  @override
  void initState() {
    super.initState();
    _initStream();
    _fetchTargets();
  }

  Future<void> _fetchTargets() async {
    final list = await _targetService.fetchAllTargetsInHierarchy(
      orgId: widget.orgId,
      adminLevel: widget.user.adminLevel ?? 4,
    );
    if (mounted) {
      setState(() => _targetList = list);
    }
  }

  @override
  void didUpdateWidget(covariant PengajianLevelSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.orgId != widget.orgId) {
      _initStream();
    }
  }

  void _initStream() {
    _templatesStream = _pengajianService.streamTemplates(widget.orgId);
  }

  int _levelToInt(String level) {
    if (level.toLowerCase() == 'daerah') return 0;
    if (level.toLowerCase() == 'desa') return 1;
    if (level.toLowerCase() == 'kelompok') return 2;
    if (level.toLowerCase() == 'kategori') return 3;
    return 0; // Default
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Pengajian>>(
      stream: _templatesStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20.0),
              child: CircularProgressIndicator(),
            ),
          );
        }

        final templates = snapshot.data ?? [];

        return Column(
          children: [
            // 1. DAERAH (Hanya muncul untuk Super Admin dan Admin Daerah)
            if (widget.adminLevel <= 1) ...[
              _buildSection(
                context,
                title: 'DAERAH',
                level: 'Daerah',
                color: Colors.red,
                icon: Icons.flag,
                templates: templates,
              ),
              const SizedBox(height: 24),
            ],

            // 2. DESA (Muncul untuk Super, Daerah, dan Admin Desa itu sendiri)
            if (widget.adminLevel <= 2) ...[
              _buildSection(
                context,
                title: 'DESA',
                level: 'Desa',
                color: Colors.blue,
                icon: Icons.home_work,
                templates: templates,
              ),
              const SizedBox(height: 24),
            ],

            // 3. KELOMPOK (Muncul untuk level 0, 1, 2, dan 3)
            if (widget.adminLevel <= 3) ...[
              _buildSection(
                context,
                title: 'KELOMPOK',
                level: 'Kelompok',
                color: Colors.green,
                icon: Icons.groups,
                templates: templates,
              ),
              const SizedBox(height: 24),
            ],
          ],
        );
      },
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required String level,
    required Color color,
    required IconData icon,
    required List<Pengajian> templates,
  }) {
    // Filter templates for this level (Compare Int vs Int)
    final intLevel = _levelToInt(level);
    final levelTemplates = templates.where((t) => t.level == intLevel).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Level
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color.withValues(alpha: 0.8),
                    letterSpacing: 1.2,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          Divider(height: 24, color: Colors.grey.shade100),

          // LIST MENU CEPAT (Templates)
          if (levelTemplates.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: levelTemplates.map((t) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Icon & Name (Clickable to Execute)
                      InkWell(
                        onTap: () => _showExecutionDialog(context, t),
                        child: Row(
                          children: [
                            Icon(
                              Icons.flash_on,
                              size: 16,
                              color: Colors.amber[700],
                            ),
                            const SizedBox(width: 6),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 150),
                              child: Text(
                                t.templateName ?? 'Template',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black87,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 8),
                      Container(
                        height: 16,
                        width: 1,
                        color: Colors.grey.shade300,
                      ),
                      const SizedBox(width: 4),

                      // Edit Button
                      InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () =>
                            _showAddTemplateDialog(context, level, template: t),
                        child: Padding(
                          padding: const EdgeInsets.all(4.0),
                          child: Icon(
                            Icons.edit,
                            size: 14,
                            color: Colors.blue[600],
                          ),
                        ),
                      ),

                      // Delete Button
                      InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _confirmDelete(context, t),
                        child: Padding(
                          padding: const EdgeInsets.all(4.0),
                          child: Icon(
                            Icons.close,
                            size: 14,
                            color: Colors.red[400],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            )
          else
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Text(
                "Belum ada menu cepat",
                style: TextStyle(color: Colors.grey[400], fontSize: 12),
              ),
            ),

          const SizedBox(height: 8),

          // 3. Tombol Tambah Menu Cepat
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: InkWell(
              onTap: () => _showAddTemplateDialog(context, level),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      "Tambah Menu Cepat",
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // EXECUTION DIALOG (Konfirmasi Buat Pengajian)
  Future<void> _showExecutionDialog(
    BuildContext context,
    Pengajian template,
  ) async {
    DateTime selectedDate = DateTime.now();
    TimeOfDay selectedTime = TimeOfDay.now();
    TimeOfDay selectedEndTime = TimeOfDay.fromDateTime(
      DateTime.now().add(const Duration(hours: 1)),
    );

    // Dynamic Audience selection from Database
    List<TargetKriteria> customTargets = await _targetService
        .fetchAvailableTargets(
          orgId: widget.orgId,
          orgDaerahId: widget.user.orgDaerahId,
          orgDesaId: widget.user.orgDesaId,
          orgKelompokId: widget.user.orgKelompokId,
        );

    final audienceOptions = [
      'Semua',
      ...customTargets.map((t) => t.namaTarget),
    ];

    String selectedAudience = template.targetAudience ?? 'Semua';
    String? selectedTargetKriteriaId = template.targetKriteriaId;

    // Validation: make sure selectedAudience exists in options
    if (!audienceOptions.contains(selectedAudience)) {
      selectedAudience = 'Semua';
      selectedTargetKriteriaId = null;
    }

    // Sub-organization selection - CASCADING DROPDOWNS
    // For Kelompok level template, we need: Desa dropdown ? Kelompok dropdown
    String? selectedDesaId;
    String? selectedKelompokId;
    List<Organization> desaList = [];
    List<Organization> kelompokList = [];
    bool isLoadingDesa = false;
    bool isLoadingKelompok = false;

    // Determine what level of dropdowns we need based on template level and admin level
    final int templateLevel = template.level ?? 0;
    final bool needsDesaDropdown =
        templateLevel >= 1 &&
        widget.adminLevel <= 1; // Admin Daerah needs to pick Desa
    final bool needsKelompokDropdown =
        templateLevel >= 2 && widget.adminLevel <= 2; // Need to pick Kelompok

    // Pre-fill if admin already at that level
    if (widget.adminLevel == 2) {
      // Admin Desa - auto-select their desa
      selectedDesaId = widget.user.orgDesaId ?? widget.orgId;
    }
    if (widget.adminLevel == 3) {
      // Admin Kelompok - auto-select their kelompok
      selectedDesaId = widget.user.orgDesaId;
      selectedKelompokId = widget.user.orgKelompokId ?? widget.orgId;
    }

    // Fetch Desa list if needed
    if (needsDesaDropdown) {
      isLoadingDesa = true;
      _orgService
          .fetchChildren(widget.orgId)
          .then((list) {
            // Level 1 = Desa (tidak filter by type karena bisa null/tidak konsisten)
            desaList = list.where((o) => o.level == 1).toList();
            isLoadingDesa = false;
          })
          .catchError((e) {
            debugPrint("Error fetching desa list: $e");
            isLoadingDesa = false;
          });
    }

    // Helper function to fetch Kelompok based on selected Desa
    Future<void> fetchKelompok(
      String desaId,
      void Function(void Function()) setStateDialog,
    ) async {
      setStateDialog(() {
        isLoadingKelompok = true;
        kelompokList = [];
        selectedKelompokId = null;
      });
      try {
        final list = await _orgService.fetchChildren(desaId);
        setStateDialog(() {
          // Level 2 = Kelompok
          kelompokList = list.where((o) => o.level == 2).toList();
          isLoadingKelompok = false;
        });
      } catch (e) {
        debugPrint("Error fetching kelompok list: $e");
        setStateDialog(() => isLoadingKelompok = false);
      }
    }

    final List<Map<String, TextEditingController>> materiEntries = [
      {'guru': TextEditingController(), 'isi': TextEditingController()},
    ];
    final roomCodeController = TextEditingController(text: template.roomCode);
    final titleController = TextEditingController(text: template.title);
    final locationController = TextEditingController(text: template.location);
    final descriptionController = TextEditingController(
      text: template.description,
    );

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text('Konfirmasi Buat Pengajian'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Sesuaikan Info (Opsional):",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: "Nama Pengajian",
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: locationController,
                    decoration: const InputDecoration(
                      labelText: "Lokasi",
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descriptionController,
                    decoration: const InputDecoration(
                      labelText: "Deskripsi",
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),

                  // 1. SELECT TARGET AUDIENCE - SMART TARGET BUILDER
                  const Text(
                    "Target Peserta:",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  SmartTargetBuilder(
                    orgId: widget.orgId,
                    adminLevel: widget.adminLevel,
                    systemTargets: customTargets,
                    onSelectionChanged: (selection) {
                      setStateDialog(() {
                        // Update legacy fields for compatibility
                        if (selection.mode == TargetMode.kriteria) {
                          selectedTargetKriteriaId = selection.kriteriaId;
                          if (selection.kriteriaId != null) {
                            final match = customTargets.firstWhere(
                              (t) => t.id == selection.kriteriaId,
                            );
                            selectedAudience = match.namaTarget;
                          }
                        } else {
                          selectedTargetKriteriaId = null;
                          selectedAudience = selection.mode == TargetMode.all
                              ? 'Semua'
                              : 'Kelas Tertentu';
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  // 2. SELECT TARGET WILAYAH - CASCADING DROPDOWNS
                  if (needsDesaDropdown || needsKelompokDropdown) ...[
                    const Text(
                      "Wilayah Target:",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // DROPDOWN 1: PILIH DESA
                    if (needsDesaDropdown) ...[
                      const Text(
                        "Pilih Desa:",
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 4),
                      if (isLoadingDesa)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(8.0),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      else if (desaList.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            "Tidak ada Desa ditemukan.",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange,
                            ),
                          ),
                        )
                      else
                        DropdownButtonFormField<String>(
                          value: selectedDesaId,
                          hint: const Text("Pilih Desa"),
                          isExpanded: true,
                          decoration: InputDecoration(
                            isDense: true,
                            filled: true,
                            fillColor: Colors.blue[50],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.blue.shade200,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                          ),
                          items: desaList
                              .map(
                                (org) => DropdownMenuItem(
                                  value: org.id,
                                  child: Text(org.name),
                                ),
                              )
                              .toList(),
                          onChanged: (val) {
                            setStateDialog(() {
                              selectedDesaId = val;
                              // Reset kelompok when desa changes
                              selectedKelompokId = null;
                              kelompokList = [];
                            });
                            // Fetch kelompok if needed
                            if (val != null && needsKelompokDropdown) {
                              fetchKelompok(val, setStateDialog);
                            }
                          },
                        ),
                      const SizedBox(height: 12),
                    ],

                    // DROPDOWN 2: PILIH KELOMPOK (hanya muncul jika Desa sudah dipilih)
                    if (needsKelompokDropdown && selectedDesaId != null) ...[
                      const Text(
                        "Pilih Kelompok:",
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 4),
                      if (isLoadingKelompok)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(8.0),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      else if (kelompokList.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            "Tidak ada Kelompok ditemukan di Desa ini.",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange,
                            ),
                          ),
                        )
                      else
                        DropdownButtonFormField<String>(
                          value: selectedKelompokId,
                          hint: const Text("Pilih Kelompok"),
                          isExpanded: true,
                          decoration: InputDecoration(
                            isDense: true,
                            filled: true,
                            fillColor: Colors.green[50],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.green.shade200,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                          ),
                          items: kelompokList
                              .map(
                                (org) => DropdownMenuItem(
                                  value: org.id,
                                  child: Text(org.name),
                                ),
                              )
                              .toList(),
                          onChanged: (val) {
                            setStateDialog(() => selectedKelompokId = val);
                          },
                        ),
                      const SizedBox(height: 12),
                    ],
                    const SizedBox(height: 4),
                  ],

                  // Waktu Pelaksanaan (Mulai - Selesai)
                  const Text(
                    "Waktu Pelaksanaan:",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),

                  // TANGGAL
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime.now().subtract(
                            const Duration(days: 1),
                          ),
                          lastDate: DateTime.now().add(
                            const Duration(days: 365),
                          ),
                        );
                        if (d != null) setStateDialog(() => selectedDate = d);
                      },
                      icon: const Icon(Icons.calendar_today, size: 16),
                      label: Text(
                        "${selectedDate.day}/${selectedDate.month}/${selectedDate.year}",
                      ),
                      style: OutlinedButton.styleFrom(
                        alignment: Alignment.centerLeft,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  Row(
                    children: [
                      // JAM MULAI
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Mulai", style: TextStyle(fontSize: 12)),
                            OutlinedButton.icon(
                              onPressed: () async {
                                final t = await showTimePicker(
                                  context: context,
                                  initialTime: selectedTime,
                                );
                                if (t != null) {
                                  setStateDialog(() => selectedTime = t);
                                }
                              },
                              icon: const Icon(Icons.access_time, size: 16),
                              label: Text(selectedTime.format(context)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // JAM SELESAI
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Selesai",
                              style: TextStyle(fontSize: 12),
                            ),
                            OutlinedButton.icon(
                              onPressed: () async {
                                final t = await showTimePicker(
                                  context: context,
                                  initialTime: selectedEndTime,
                                );
                                if (t != null) {
                                  setStateDialog(() => selectedEndTime = t);
                                }
                              },
                              icon: const Icon(
                                Icons.access_time_filled,
                                size: 16,
                              ),
                              label: Text(selectedEndTime.format(context)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),

                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),

                  // INPUT MATERI (DYNAMIC LIST)
                  Row(
                    children: [
                      const Text(
                        "Input Materi / Nasehat:",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () {
                          setStateDialog(() {
                            materiEntries.add({
                              'guru': TextEditingController(),
                              'isi': TextEditingController(),
                            });
                          });
                        },
                        icon: const Icon(Icons.add_circle_outline, size: 20),
                        label: const Text("Tambah Guru"),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF1A5F2D),
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  ...List.generate(materiEntries.length, (index) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                "Materi #${index + 1}",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: Colors.blueGrey,
                                ),
                              ),
                              const Spacer(),
                              if (materiEntries.length > 1)
                                IconButton(
                                  onPressed: () {
                                    setStateDialog(() {
                                      materiEntries[index]['guru']!.dispose();
                                      materiEntries[index]['isi']!.dispose();
                                      materiEntries.removeAt(index);
                                    });
                                  },
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.red,
                                    size: 20,
                                  ),
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: materiEntries[index]['guru'],
                            decoration: const InputDecoration(
                              labelText: 'Pembawa Materi / Guru',
                              hintText: 'Nama Guru',
                              border: OutlineInputBorder(),
                              isDense: true,
                              filled: true,
                              fillColor: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: materiEntries[index]['isi'],
                            maxLines: 3,
                            decoration: const InputDecoration(
                              labelText: 'Kesimpulan Materi',
                              hintText: 'Tulis ringkasan materi di sini...',
                              border: OutlineInputBorder(),
                              isDense: true,
                              filled: true,
                              fillColor: Colors.white,
                              alignLabelWithHint: true,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),

                  const SizedBox(height: 8),
                  const Divider(),
                  const SizedBox(height: 8),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  // KODE ROOM
                  const Text(
                    "Kode Room (Opsional):",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: roomCodeController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Kode Room',
                      hintText: 'Contoh: NGAJI01 (Kosongkan utk acak)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "* Bagikan kode ini ke Admin lain agar mereka bisa bergabung ke room yang sama.",
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.blueGrey,
                      fontStyle: FontStyle.italic,
                    ),
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
                onPressed: () => _showPreviewAndConfirm(
                  ctx,
                  context,
                  template,
                  titleController,
                  locationController,
                  descriptionController,
                  roomCodeController,
                  selectedDate,
                  selectedTime,
                  selectedEndTime,
                  selectedAudience,
                  selectedTargetKriteriaId,
                  customTargets,
                  selectedDesaId,
                  selectedKelompokId,
                  desaList,
                  materiEntries,
                  templateLevel,
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A5F2D),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
                child: const Text('Buat'),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Show preview popup with pengajian summary, then confirm and send QR to targets
  Future<void> _showPreviewAndConfirm(
    BuildContext dialogCtx,
    BuildContext parentContext,
    Pengajian template,
    TextEditingController titleController,
    TextEditingController locationController,
    TextEditingController descriptionController,
    TextEditingController roomCodeController,
    DateTime selectedDate,
    TimeOfDay selectedTime,
    TimeOfDay selectedEndTime,
    String selectedAudience,
    String? selectedTargetKriteriaId,
    List<TargetKriteria> customTargets,
    String? selectedDesaId,
    String? selectedKelompokId,
    List<Organization> desaList,
    List<Map<String, TextEditingController>> materiEntries,
    int templateLevel,
  ) async {
    // Format waktu
    final startTimeStr =
        '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}';
    final endTimeStr =
        '${selectedEndTime.hour.toString().padLeft(2, '0')}:${selectedEndTime.minute.toString().padLeft(2, '0')}';
    final dateStr =
        '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}';

    // Find target kriteria name
    String targetName = selectedAudience;
    if (selectedTargetKriteriaId != null) {
      final kriteria = customTargets.firstWhere(
        (k) => k.id == selectedTargetKriteriaId,
        orElse: () =>
            TargetKriteria(id: '', orgId: '', namaTarget: selectedAudience),
      );
      targetName = kriteria.namaTarget;
    }

    // Collect materi for preview
    final List<String> materiList = [];
    for (var entry in materiEntries) {
      final guru = entry['guru']?.text.trim() ?? '';
      final isi = entry['isi']?.text.trim() ?? '';
      if (guru.isNotEmpty || isi.isNotEmpty) {
        materiList.add(guru.isNotEmpty ? '$guru: $isi' : isi);
      }
    }

    // Show preview dialog
    final confirmed = await showDialog<bool>(
      context: dialogCtx,
      barrierDismissible: false,
      builder: (previewCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1A5F2D), Color(0xFF2E7D32)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.preview, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 12),
            const Text('Preview Pengajian'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Summary Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF1A5F2D).withOpacity(0.1),
                      const Color(0xFF2E7D32).withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF1A5F2D).withOpacity(0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPreviewRow(
                      Icons.title,
                      'Judul',
                      titleController.text,
                    ),
                    const SizedBox(height: 12),
                    _buildPreviewRow(
                      Icons.location_on,
                      'Lokasi',
                      locationController.text,
                    ),
                    const SizedBox(height: 12),
                    _buildPreviewRow(Icons.calendar_today, 'Tanggal', dateStr),
                    const SizedBox(height: 12),
                    _buildPreviewRow(
                      Icons.access_time,
                      'Waktu',
                      '$startTimeStr - $endTimeStr',
                    ),
                    const SizedBox(height: 12),
                    _buildPreviewRow(Icons.groups, 'Target', targetName),
                    if (roomCodeController.text.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _buildPreviewRow(
                        Icons.qr_code,
                        'Kode Room',
                        roomCodeController.text.toUpperCase(),
                      ),
                    ],
                    if (materiList.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _buildPreviewRow(
                        Icons.book,
                        'Materi',
                        materiList.join('\n'),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Info banner
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.blue.shade700,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Setelah konfirmasi, QR akan otomatis dikirimkan ke semua peserta target.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(previewCtx, false),
            child: const Text('Kembali'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(previewCtx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A5F2D),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.check_circle, size: 20),
            label: const Text('Konfirmasi & Kirim QR'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Show loading dialog with modern animation
    if (!dialogCtx.mounted) return;

    showDialog(
      context: dialogCtx,
      barrierDismissible: false,
      builder: (loadingCtx) => WillPopScope(
        onWillPop: () async => false,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Modern loading animation
              Stack(
                alignment: Alignment.center,
                children: [
                  // Outer pulse ring
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.8, end: 1.2),
                    duration: const Duration(milliseconds: 1000),
                    curve: Curves.easeInOut,
                    builder: (context, value, child) {
                      return Container(
                        width: 100 * value,
                        height: 100 * value,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(
                              0xFF1A5F2D,
                            ).withOpacity(0.3 / value),
                            width: 3,
                          ),
                        ),
                      );
                    },
                  ),
                  // Inner container with icon
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF1A5F2D), Color(0xFF2E7D32)],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1A5F2D).withOpacity(0.3),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.qr_code_2,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                'Membuat Room & Mengirim QR',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A5F2D),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Mohon tunggu sebentar...',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 16),
              // Progress indicator
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  backgroundColor: Colors.grey.shade200,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFF1A5F2D),
                  ),
                  minHeight: 6,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      // Prepare dates
      final combinedStartTime = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        selectedTime.hour,
        selectedTime.minute,
      );
      final combinedEndTime = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        selectedEndTime.hour,
        selectedEndTime.minute,
      );

      // Hierarchical context resolution
      String? orgDaerahId = widget.user.orgDaerahId;
      String? orgDesaId = widget.user.orgDesaId;
      String? orgKelompokId = widget.user.orgKelompokId;

      if (widget.user.adminLevel == 1) orgDaerahId ??= widget.user.adminOrgId;
      if (widget.user.adminLevel == 2) orgDesaId ??= widget.user.adminOrgId;
      if (widget.user.adminLevel == 3) orgKelompokId ??= widget.user.adminOrgId;

      if (selectedDesaId != null) {
        orgDesaId = selectedDesaId;
        final selectedDesa = desaList.firstWhere(
          (o) => o.id == selectedDesaId,
          orElse: () => Organization(id: '', name: '', type: 'desa'),
        );
        if (selectedDesa.parentId != null) orgDaerahId = selectedDesa.parentId;
      }
      if (selectedKelompokId != null) orgKelompokId = selectedKelompokId;

      // Determine target org
      String targetOrgId;
      if (templateLevel == 2 && selectedKelompokId != null) {
        targetOrgId = selectedKelompokId!;
      } else if (templateLevel == 1 && selectedDesaId != null) {
        targetOrgId = selectedDesaId!;
      } else {
        targetOrgId = widget.orgId;
      }

      // Collect materi
      List<String> guruNames = [];
      List<String> contentParts = [];
      for (var entry in materiEntries) {
        final name = entry['guru']?.text.trim() ?? '';
        final content = entry['isi']?.text.trim() ?? '';
        if (name.isNotEmpty) guruNames.add(name);
        if (content.isNotEmpty) contentParts.add(content);
      }

      // Create pengajian
      await _pengajianService.createPengajian(
        Pengajian(
          id: '',
          orgId: targetOrgId,
          title: titleController.text,
          description: descriptionController.text,
          location: locationController.text,
          targetAudience: selectedAudience,
          roomCode: roomCodeController.text.trim().toUpperCase(),
          isTemplate: false,
          startedAt: combinedStartTime,
          endedAt: combinedEndTime,
          level: template.level,
          orgDaerahId: orgDaerahId,
          orgDesaId: orgDesaId,
          orgKelompokId: orgKelompokId,
          materiGuru: guruNames.isNotEmpty ? guruNames : null,
          materiIsi: contentParts.isNotEmpty ? contentParts.join(", ") : null,
          targetKriteriaId: selectedTargetKriteriaId,
        ),
      );

      // Small delay for perceived progress
      await Future.delayed(const Duration(milliseconds: 500));

      // Close loading and main dialogs
      if (dialogCtx.mounted) {
        Navigator.pop(dialogCtx); // Close loading
        Navigator.pop(dialogCtx); // Close main form
      }

      // Show success message
      if (parentContext.mounted) {
        showDialog(
          context: parentContext,
          builder: (successCtx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Success animation
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1A5F2D), Color(0xFF4CAF50)],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF4CAF50).withOpacity(0.3),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    color: Colors.white,
                    size: 50,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Berhasil! 🎉',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A5F2D),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Room pengajian sudah aktif dan QR sudah dikirimkan ke semua peserta target.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A5F2D).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Target: $targetName',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF1A5F2D),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              Center(
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(successCtx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A5F2D),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.done, size: 20),
                  label: const Text('Tutup'),
                ),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      // Close loading dialog
      if (dialogCtx.mounted) Navigator.pop(dialogCtx);

      // Show error
      if (parentContext.mounted) {
        String msg = e.toString();
        if (msg.startsWith('Exception: ')) {
          msg = msg.replaceFirst('Exception: ', '');
        }
        ScaffoldMessenger.of(parentContext).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text(msg)),
              ],
            ),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Widget _buildPreviewRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: const Color(0xFF1A5F2D)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A5F2D),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showAddTemplateDialog(
    BuildContext context,
    String level, {
    Pengajian? template,
  }) {
    final isEdit = template != null;
    final titleController = TextEditingController(text: template?.title ?? '');
    final descController = TextEditingController(
      text: template?.description ?? "Pengajian rutin $level",
    );

    String? selectedTargetKriteriaId = template?.targetKriteriaId;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isEdit
                        ? 'Edit Menu Cepat ($level)'
                        : 'Tambah Menu Cepat ($level)',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 1. Nama Pengajian
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Nama Pengajian',
                      hintText: 'Contoh: Pengajian Rutin Islah',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 2. Target Peserta
                  DropdownButtonFormField<String>(
                    value: selectedTargetKriteriaId,
                    isExpanded: true,
                    items: _targetList.map((t) {
                      return DropdownMenuItem(
                        value: t.id,
                        child: Text(
                          t.namaTarget,
                          style: const TextStyle(fontSize: 14),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) =>
                        setStateDialog(() => selectedTargetKriteriaId = val),
                    decoration: const InputDecoration(
                      labelText: 'Target Peserta',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 3. Deskripsi
                  TextField(
                    controller: descController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Deskripsi (Default)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Actions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Batal'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () async {
                          if (titleController.text.isNotEmpty) {
                            try {
                              debugPrint(
                                'Saving template for OrgID: ${widget.orgId}',
                              );
                              if (isEdit) {
                                await _pengajianService.updateTemplate(
                                  Pengajian(
                                    id: template.id,
                                    orgId: widget.orgId,
                                    title: titleController.text,
                                    description: descController.text,
                                    location:
                                        null, // Lokasi diisi saat membuat room
                                    targetAudience:
                                        selectedTargetKriteriaId != null
                                        ? _targetList
                                              .firstWhere(
                                                (t) =>
                                                    t.id ==
                                                    selectedTargetKriteriaId,
                                              )
                                              .namaTarget
                                        : null,
                                    targetKriteriaId: selectedTargetKriteriaId,
                                    roomCode:
                                        null, // Kode room diisi saat membuat room
                                    startedAt: template.startedAt,
                                    isTemplate: true,
                                    templateName: titleController.text,
                                    level: template.level,
                                  ),
                                );
                              } else {
                                await _pengajianService.createTemplate(
                                  Pengajian(
                                    id: '',
                                    orgId: widget.orgId,
                                    title: titleController.text,
                                    description: descController.text,
                                    location:
                                        null, // Lokasi diisi saat membuat room
                                    targetAudience:
                                        selectedTargetKriteriaId != null
                                        ? _targetList
                                              .firstWhere(
                                                (t) =>
                                                    t.id ==
                                                    selectedTargetKriteriaId,
                                              )
                                              .namaTarget
                                        : null,
                                    targetKriteriaId: selectedTargetKriteriaId,
                                    roomCode:
                                        null, // Kode room diisi saat membuat room
                                    startedAt: DateTime.now(),
                                    isTemplate: true,
                                    templateName: titleController.text,
                                    level: _levelToInt(level),
                                  ),
                                );
                              }

                              if (context.mounted) {
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      isEdit
                                          ? 'Menu cepat berhasil diperbarui'
                                          : 'Menu cepat berhasil ditambahkan',
                                    ),
                                  ),
                                );
                              }
                            } catch (e) {
                              debugPrint('Error saving template: $e');
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Gagal menyimpan: $e'),
                                  ),
                                );
                              }
                            }
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Nama Pengajian wajib diisi'),
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1A5F2D),
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Simpan'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, Pengajian template) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Menu Cepat?'),
        content: Text("Akan menghapus '${template.templateName}'. Lanjutkan?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await _pengajianService.deleteTemplate(template.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Menu cepat berhasil dihapus')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Gagal menghapus: $e')));
        }
      }
    }
  }
}
