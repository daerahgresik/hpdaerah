import 'package:flutter/material.dart';
import 'package:hpdaerah/models/user_model.dart';
import 'package:hpdaerah/models/pengajian_model.dart';
import 'package:hpdaerah/services/pengajian_service.dart';
import 'package:hpdaerah/services/organization_service.dart';
import 'package:hpdaerah/models/organization_model.dart';
import 'package:hpdaerah/services/target_kriteria_service.dart';
import 'package:hpdaerah/models/target_kriteria_model.dart';

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

  // Inline Management State
  bool _isTargetExpanded = false;
  List<TargetKriteria> _targetList = [];
  bool _isLoadingTargets = false;

  @override
  void initState() {
    super.initState();
    _initStream();
    _fetchTargets();
  }

  Future<void> _fetchTargets() async {
    if (mounted) setState(() => _isLoadingTargets = true);
    final list = await _targetService.fetchAllTargetsInHierarchy(
      orgId: widget.orgId,
      adminLevel: widget.user.adminLevel ?? 4,
    );
    if (mounted) {
      setState(() {
        _targetList = list;
        _isLoadingTargets = false;
      });
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
            // 0. KELOLA TARGET PESERTA (INLINE)
            _buildInlineTargetManager(),
            const SizedBox(height: 12),

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

            // 4. KATEGORI (Muncul untuk semua level admin)
            _buildSection(
              context,
              title: 'KATEGORI / KELAS',
              level: 'Kategori',
              color: Colors.orange,
              icon: Icons.school,
              templates: templates,
            ),
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

    // Sub-organization selection
    String? selectedSubOrgId;
    List<Organization> subOrgs = [];
    bool isLoadingSubOrgs = false;
    bool needsSubOrg =
        template.level != null && template.level! >= widget.adminLevel;

    // Fetch sub-orgs if needed
    if (needsSubOrg) {
      isLoadingSubOrgs = true;
      _orgService
          .fetchChildren(widget.orgId)
          .then((list) {
            subOrgs = list;
            isLoadingSubOrgs = false;
            // Optionally auto-select if only one
            // if (subOrgs.length == 1) selectedSubOrgId = subOrgs.first.id;
          })
          .catchError((e) {
            debugPrint("Error fetching sub-orgs: $e");
          });
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

                  // 1. SELECT TARGET AUDIENCE
                  const Text(
                    "Target Peserta:",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: selectedAudience,
                    decoration: InputDecoration(
                      isDense: true,
                      filled: true,
                      fillColor: Colors.grey[50],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                    items: audienceOptions
                        .map(
                          (val) => DropdownMenuItem<String>(
                            value: val,
                            child: Text(val),
                          ),
                        )
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setStateDialog(() {
                          selectedAudience = val;
                          // Update the ID find the matching target
                          if (val == 'Semua') {
                            selectedTargetKriteriaId = null;
                          } else {
                            final match = customTargets.firstWhere(
                              (t) => t.namaTarget == val,
                            );
                            selectedTargetKriteriaId = match.id;
                          }
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),

                  // 2. SELECT TARGET WILAYAH (SUBO-ORG)
                  if (needsSubOrg) ...[
                    const Text(
                      "Wilayah Target (Sub-Organisasi):",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (isLoadingSubOrgs)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(8.0),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    else if (subOrgs.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          "Tidak ada sub-organisasi ditemukan. Pengajian akan dibuat di level ini.",
                          style: TextStyle(fontSize: 12, color: Colors.orange),
                        ),
                      )
                    else
                      DropdownButtonFormField<String>(
                        value: selectedSubOrgId,
                        hint: const Text("Pilih Sub-Organisasi"),
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
                        items: subOrgs
                            .map(
                              (org) => DropdownMenuItem(
                                value: org.id,
                                child: Text(org.name),
                              ),
                            )
                            .toList(),
                        onChanged: (val) {
                          setStateDialog(() => selectedSubOrgId = val);
                        },
                      ),
                    const SizedBox(height: 16),
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
                onPressed: () async {
                  try {
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
                    String targetOrgId = selectedSubOrgId ?? widget.orgId;
                    String? orgDaerahId = widget.user.orgDaerahId;
                    String? orgDesaId = widget.user.orgDesaId;
                    String? orgKelompokId = widget.user.orgKelompokId;

                    // If a sub-org was selected, we need to update the hierarchy IDs
                    if (selectedSubOrgId != null) {
                      final selectedOrg = subOrgs.firstWhere(
                        (o) => o.id == selectedSubOrgId,
                      );
                      // Determine which level of ID to update
                      if (selectedOrg.type == 'daerah') {
                        orgDaerahId = selectedOrg.id;
                      } else if (selectedOrg.type == 'desa') {
                        orgDesaId = selectedOrg.id;
                      } else if (selectedOrg.type == 'kelompok') {
                        orgKelompokId = selectedOrg.id;
                        // If we pick a Kelompok, the parent is the Desa
                        orgDesaId = selectedOrg.parentId;
                      }
                    }

                    // 2. Consolidate Materi (Jika diisi)
                    final List<String> guruNames = [];
                    final List<String> contentParts = [];

                    for (var entry in materiEntries) {
                      final name = entry['guru']?.text.trim() ?? '';
                      final content = entry['isi']?.text.trim() ?? '';

                      if (name.isNotEmpty) guruNames.add(name);
                      if (content.isNotEmpty) contentParts.add(content);
                    }

                    // 3. Buat Pengajian (Termasuk Materi)
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
                        materiIsi: contentParts.isNotEmpty
                            ? contentParts.join(", ")
                            : null,
                        targetKriteriaId: selectedTargetKriteriaId,
                      ),
                    );

                    if (context.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Row(
                            children: [
                              Icon(Icons.check_circle, color: Colors.white),
                              SizedBox(width: 12),
                              Text('Pengajian & Materi berhasil dibuat!'),
                            ],
                          ),
                          backgroundColor: const Color(0xFF1A5F2D),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      String msg = e.toString();
                      if (msg.startsWith('Exception: ')) {
                        msg = msg.replaceFirst('Exception: ', '');
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(msg),
                          backgroundColor: Colors.red[700],
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 4),
                        ),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A5F2D),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Konfirmasi & Buat'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAddTemplateDialog(
    BuildContext context,
    String level, {
    Pengajian? template,
  }) {
    final isEdit = template != null;
    final titleController = TextEditingController(text: template?.title ?? '');
    final locationController = TextEditingController(
      text: template?.location ?? '',
    );
    final descController = TextEditingController(
      text: template?.description ?? "Pengajian rutin $level",
    );
    final roomCodeController = TextEditingController(
      text: template?.roomCode ?? '',
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

                  // 2. Lokasi
                  TextField(
                    controller: locationController,
                    decoration: const InputDecoration(
                      labelText: 'Lokasi (Default)',
                      hintText: 'Contoh: Masjid Al-Ikhlas',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 3. Target Peserta
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

                  // 4. Deskripsi
                  TextField(
                    controller: descController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Deskripsi (Default)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 5. Kode Room (Template)
                  TextField(
                    controller: roomCodeController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Kode Room Default (Opsional)',
                      hintText: 'Contoh: NGAJI01',
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
                                    location: locationController.text,
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
                                    roomCode: roomCodeController.text
                                        .trim()
                                        .toUpperCase(),
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
                                    location: locationController.text,
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
                                    roomCode: roomCodeController.text
                                        .trim()
                                        .toUpperCase(),
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

  Widget _buildInlineTargetManager() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          ListTile(
            onTap: () => setState(() => _isTargetExpanded = !_isTargetExpanded),
            leading: const Icon(
              Icons.settings_suggest,
              color: Color(0xFF1A5F2D),
            ),
            title: const Text(
              "Manajemen Target Peserta",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            subtitle: const Text(
              "Kelola kriteria umur & status peserta",
              style: TextStyle(fontSize: 11),
            ),
            trailing: Icon(
              _isTargetExpanded ? Icons.expand_less : Icons.expand_more,
            ),
          ),
          if (_isTargetExpanded) ...[
            const Divider(height: 1),
            if (_isLoadingTargets)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_targetList.isEmpty)
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    const Text(
                      "Belum ada target kustom",
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: _showAddTargetDialog,
                      icon: const Icon(Icons.add),
                      label: const Text("Buat Target Pertama"),
                    ),
                  ],
                ),
              )
            else
              Column(
                children: [
                  ..._targetList.map((t) {
                    final isMine = t.orgId == widget.orgId;
                    return ListTile(
                      dense: true,
                      title: Text(
                        t.namaTarget,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        "${t.jenisKelamin}, ${t.minUmur}-${t.maxUmur} thn, ${t.statusWarga}, ${t.statusPernikahan}",
                        style: const TextStyle(fontSize: 11),
                      ),
                      trailing: isMine
                          ? IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.red,
                                size: 20,
                              ),
                              onPressed: () async {
                                await _targetService.deleteTarget(t.id);
                                _fetchTargets();
                              },
                            )
                          : Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                "Pinjaman",
                                style: TextStyle(
                                  fontSize: 9,
                                  color: Colors.blue,
                                ),
                              ),
                            ),
                    );
                  }),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: ElevatedButton.icon(
                      onPressed: _showAddTargetDialog,
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text("Tambah Target Baru"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1A5F2D),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 36),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ],
      ),
    );
  }

  void _showAddTargetDialog() {
    final nameController = TextEditingController();
    int minUmur = 0;
    int maxUmur = 100;
    String selectedJK = 'Semua';
    String selectedStatus = 'Semua';
    String selectedKeperluan = 'Semua';
    String selectedNikah = 'Semua';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: const Text("Buat Target Baru"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: "Nama Target",
                    hintText: "Contoh: Remaja Perantau Pria",
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  "Range Umur",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: "Min"),
                        onChanged: (val) => minUmur = int.tryParse(val) ?? 0,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextField(
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: "Max"),
                        onChanged: (val) => maxUmur = int.tryParse(val) ?? 100,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedJK,
                  decoration: const InputDecoration(labelText: "Jenis Kelamin"),
                  items: ['Semua', 'Pria', 'Wanita']
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (val) => setModalState(() => selectedJK = val!),
                ),
                DropdownButtonFormField<String>(
                  value: selectedStatus,
                  decoration: const InputDecoration(labelText: "Status Warga"),
                  items: ['Semua', 'Warga Asli', 'Perantau']
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (val) =>
                      setModalState(() => selectedStatus = val!),
                ),
                DropdownButtonFormField<String>(
                  value: selectedKeperluan,
                  decoration: const InputDecoration(labelText: "Keperluan"),
                  items: ['Semua', 'MT', 'Kuliah', 'Bekerja']
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (val) =>
                      setModalState(() => selectedKeperluan = val!),
                ),
                DropdownButtonFormField<String>(
                  value: selectedNikah,
                  decoration: const InputDecoration(
                    labelText: "Status Pernikahan",
                  ),
                  items: ['Semua', 'Kawin', 'Belum Kawin']
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (val) => setModalState(() => selectedNikah = val!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Batal"),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.isEmpty) return;
                final newTarget = TargetKriteria(
                  id: '',
                  orgId: widget.orgId,
                  orgDaerahId: widget.user.orgDaerahId,
                  orgDesaId: widget.user.orgDesaId,
                  orgKelompokId: widget.user.orgKelompokId,
                  namaTarget: nameController.text.trim(),
                  minUmur: minUmur,
                  maxUmur: maxUmur,
                  jenisKelamin: selectedJK,
                  statusWarga: selectedStatus,
                  keperluan: selectedKeperluan,
                  statusPernikahan: selectedNikah,
                  createdBy: widget.user.id,
                );
                await _targetService.createTarget(newTarget);
                Navigator.pop(ctx);
                _fetchTargets();
              },
              child: const Text("Simpan"),
            ),
          ],
        ),
      ),
    );
  }
}
