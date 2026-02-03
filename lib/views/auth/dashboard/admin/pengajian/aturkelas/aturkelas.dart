import 'package:flutter/material.dart';
import 'package:hpdaerah/models/user_model.dart';
import 'package:hpdaerah/models/kelas_model.dart';
import 'package:hpdaerah/models/organization_model.dart';
import 'package:hpdaerah/services/kelas_service.dart';
import 'package:hpdaerah/services/organization_service.dart';

class AturKelasPage extends StatefulWidget {
  final UserModel user;
  final String orgId;

  const AturKelasPage({super.key, required this.user, required this.orgId});

  @override
  State<AturKelasPage> createState() => _AturKelasPageState();
}

class _AturKelasPageState extends State<AturKelasPage> {
  final _kelasService = KelasService();
  final _orgService = OrganizationService();

  // State
  List<Kelas> _kelasList = [];
  List<Organization> _desaList = [];
  List<Organization> _kelompokList = [];
  List<Map<String, dynamic>> _unassignedUsers = [];
  bool _isLoading = true;
  String? _selectedDesaId;
  String? _selectedKelompokId;
  Map<String, int> _memberCounts = {};

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final adminLevel = widget.user.adminLevel ?? 4;

    if (adminLevel == 3) {
      // Admin Kelompok - langsung load kelas
      _selectedKelompokId = widget.orgId;
      await _loadKelas();
    } else if (adminLevel <= 2) {
      // Admin Daerah atau Desa - perlu pilih kelompok dulu
      await _loadDesaList();
    }

    setState(() => _isLoading = false);
  }

  Future<void> _loadDesaList() async {
    final adminLevel = widget.user.adminLevel ?? 4;

    if (adminLevel == 1) {
      // Admin Daerah - load semua desa
      final children = await _orgService.fetchChildren(widget.orgId);
      _desaList = children.where((o) => o.level == 1).toList();
    } else if (adminLevel == 2) {
      // Admin Desa - auto-select desa mereka
      _selectedDesaId = widget.orgId;
      await _loadKelompokList(_selectedDesaId!);
    }
    setState(() {});
  }

  Future<void> _loadKelompokList(String desaId) async {
    final children = await _orgService.fetchChildren(desaId);
    setState(() {
      _kelompokList = children.where((o) => o.level == 2).toList();
      _selectedKelompokId = null;
      _kelasList = [];
    });
  }

  Future<void> _loadKelas() async {
    if (_selectedKelompokId == null) return;
    if (!mounted) return;

    setState(() => _isLoading = true);
    try {
      _kelasList = await _kelasService.fetchKelasByKelompok(
        _selectedKelompokId!,
      );
      _memberCounts = await _kelasService.getKelasMemberCounts(
        _selectedKelompokId!,
      );
      _unassignedUsers = await _kelasService.getUnassignedUsers(
        _selectedKelompokId!,
      );
    } catch (e) {
      debugPrint("Error loading kelas: $e");
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final adminLevel = widget.user.adminLevel ?? 4;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        _buildHeader(),
        const SizedBox(height: 20),

        // Cascading Dropdowns (untuk admin level atas)
        if (adminLevel <= 2) ...[
          _buildScopeSelectors(),
          const SizedBox(height: 16),
        ],

        if (_unassignedUsers.isNotEmpty) ...[
          _buildUnassignedBanner(),
          const SizedBox(height: 16),
        ],

        // Content
        if (_isLoading)
          const Center(child: CircularProgressIndicator())
        else if (_selectedKelompokId == null)
          _buildEmptyState("Pilih Kelompok untuk melihat daftar kelas")
        else if (_kelasList.isEmpty && _unassignedUsers.isEmpty)
          _buildEmptyState("Belum ada kelas di kelompok ini")
        else if (_kelasList.isNotEmpty)
          _buildKelasList(),
      ],
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.teal.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.school_rounded, color: Colors.teal, size: 24),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Atur Kelas",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              Text(
                "Kelola kelas pengajian per kelompok",
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
        if (_selectedKelompokId != null)
          ElevatedButton.icon(
            onPressed: () => _showAddEditDialog(),
            icon: const Icon(Icons.add, size: 18),
            label: const Text("Tambah Kelas"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildScopeSelectors() {
    final adminLevel = widget.user.adminLevel ?? 4;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Pilih Kelompok:",
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(height: 12),

          // Dropdown Desa (untuk Admin Daerah)
          if (adminLevel == 1) ...[
            DropdownButtonFormField<String>(
              value: _selectedDesaId,
              hint: const Text("Pilih Desa"),
              isExpanded: true,
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
              items: _desaList
                  .map(
                    (d) => DropdownMenuItem(value: d.id, child: Text(d.name)),
                  )
                  .toList(),
              onChanged: (val) {
                setState(() => _selectedDesaId = val);
                if (val != null) _loadKelompokList(val);
              },
            ),
            const SizedBox(height: 12),
          ],

          // Dropdown Kelompok
          DropdownButtonFormField<String>(
            value: _selectedKelompokId,
            hint: const Text("Pilih Kelompok"),
            isExpanded: true,
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
            ),
            items: _kelompokList
                .map((k) => DropdownMenuItem(value: k.id, child: Text(k.name)))
                .toList(),
            onChanged: (val) {
              setState(() => _selectedKelompokId = val);
              if (val != null) _loadKelas();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(Icons.school_outlined, size: 48, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600]),
          ),
          if (_selectedKelompokId != null) ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _showAddEditDialog(),
              icon: const Icon(Icons.add),
              label: const Text("Tambah Kelas Pertama"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildKelasList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _kelasList.length,
      itemBuilder: (context, index) {
        final kelas = _kelasList[index];
        final count = _memberCounts[kelas.id] ?? 0;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            onTap: () => _showKelasDetail(kelas),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Icon
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.teal.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.groups_rounded, color: Colors.teal),
                  ),
                  const SizedBox(width: 16),

                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          kelas.nama,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        if (kelas.deskripsi?.isNotEmpty == true)
                          Text(
                            kelas.deskripsi!,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            "$count anggota",
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.blue[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Actions
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    onSelected: (action) {
                      if (action == 'edit') {
                        _showAddEditDialog(kelas: kelas);
                      } else if (action == 'delete') {
                        _confirmDelete(kelas);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 18),
                            SizedBox(width: 8),
                            Text('Edit'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, size: 18, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Hapus', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showAddEditDialog({Kelas? kelas}) {
    final isEdit = kelas != null;
    final nameController = TextEditingController(text: kelas?.nama ?? '');
    final descController = TextEditingController(text: kelas?.deskripsi ?? '');

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isEdit ? "Edit Kelas" : "Tambah Kelas Baru",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: "Nama Kelas",
                  hintText: "Contoh: Muda-Mudi",
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: "Deskripsi (Opsional)",
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text("Batal"),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () async {
                      if (nameController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Nama kelas wajib diisi"),
                          ),
                        );
                        return;
                      }

                      try {
                        if (isEdit) {
                          await _kelasService.updateKelas(
                            kelas.copyWith(
                              nama: nameController.text.trim(),
                              deskripsi: descController.text.trim(),
                            ),
                          );
                        } else {
                          await _kelasService.createKelas(
                            Kelas(
                              id: '',
                              orgKelompokId: _selectedKelompokId!,
                              nama: nameController.text.trim(),
                              deskripsi: descController.text.trim(),
                            ),
                          );
                        }

                        if (context.mounted) {
                          Navigator.pop(ctx);
                          _loadKelas();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                isEdit
                                    ? "Kelas berhasil diperbarui"
                                    : "Kelas berhasil ditambahkan",
                              ),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("Error: $e"),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(isEdit ? "Simpan" : "Tambah"),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(Kelas kelas) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Hapus Kelas?"),
        content: Text(
          "Yakin ingin menghapus kelas \"${kelas.nama}\"?\n\nAnggota kelas ini akan menjadi tidak memiliki kelas.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Batal"),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await _kelasService.deleteKelas(kelas.id);
                if (context.mounted) {
                  Navigator.pop(ctx);
                  _loadKelas();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Kelas berhasil dihapus"),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Error: $e"),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text("Hapus"),
          ),
        ],
      ),
    );
  }

  void _showKelasDetail(Kelas kelas) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.teal.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.groups, color: Colors.teal),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          kelas.nama,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (kelas.deskripsi?.isNotEmpty == true)
                          Text(
                            kelas.deskripsi!,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 24),
            // Members List
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _kelasService.getKelasMembers(kelas.id),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final members = snapshot.data ?? [];
                  if (members.isEmpty) {
                    return Center(
                      child: Text(
                        "Belum ada anggota",
                        style: TextStyle(color: Colors.grey[500]),
                      ),
                    );
                  }
                  return ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: members.length,
                    itemBuilder: (context, index) {
                      final m = members[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: m['foto_profil'] != null
                              ? NetworkImage(m['foto_profil'])
                              : null,
                          child: m['foto_profil'] == null
                              ? Text(
                                  (m['nama'] as String?)?.isNotEmpty == true
                                      ? m['nama'][0].toUpperCase()
                                      : '?',
                                )
                              : null,
                        ),
                        title: Text(m['nama'] ?? '-'),
                        subtitle: Text("@${m['username'] ?? '-'}"),
                        trailing: IconButton(
                          icon: const Icon(Icons.swap_horiz),
                          tooltip: "Pindah Kelas",
                          onPressed: () =>
                              _showMoveUserDialog(m['id'], m['nama'], kelas.id),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMoveUserDialog(
    String userId,
    String userName,
    String currentKelasId, {
    bool closeParentSheet = true,
  }) {
    String? targetKelasId;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text("Pindah Kelas"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Pindahkan $userName ke kelas:"),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: targetKelasId,
                hint: const Text("Pilih Kelas Tujuan"),
                isExpanded: true,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: _kelasList
                    .where((k) => k.id != currentKelasId)
                    .map(
                      (k) => DropdownMenuItem(value: k.id, child: Text(k.nama)),
                    )
                    .toList(),
                onChanged: (val) => setStateDialog(() => targetKelasId = val),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Batal"),
            ),
            ElevatedButton(
              onPressed: targetKelasId == null
                  ? null
                  : () async {
                      try {
                        await _kelasService.moveUserToKelas(
                          userId: userId,
                          kelasId: targetKelasId,
                        );
                        if (context.mounted) {
                          Navigator.pop(ctx);
                          if (closeParentSheet) {
                            Navigator.pop(context); // Close bottom sheet
                          }
                          _loadKelas();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("$userName berhasil dipindahkan"),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("Error: $e"),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
              ),
              child: const Text("Pindahkan"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnassignedBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange[800]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "${_unassignedUsers.length} Anggota Belum Memiliki Kelas",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange[900],
                  ),
                ),
                Text(
                  "Anggota ini terdaftar di kelompok tapi belum masuk kelas manapun.",
                  style: TextStyle(fontSize: 12, color: Colors.orange[800]),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => _showUnassignedDialog(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange[100],
              foregroundColor: Colors.orange[900],
              elevation: 0,
            ),
            child: const Text("Atur"),
          ),
        ],
      ),
    );
  }

  void _showUnassignedDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                // Handle
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Icon(
                        Icons.group_add,
                        color: Colors.orange[700],
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Atur Anggota",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              "${_unassignedUsers.length} anggota perlu ditempatkan",
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _unassignedUsers.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (context, index) {
                      final u = _unassignedUsers[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: u['foto_profil'] != null
                              ? NetworkImage(u['foto_profil'])
                              : null,
                          child: u['foto_profil'] == null
                              ? Text((u['nama'] as String)[0].toUpperCase())
                              : null,
                        ),
                        title: Text(u['nama'] ?? '-'),
                        subtitle: Text("@${u['username'] ?? '-'}"),
                        trailing: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context); // close sheet
                            _showMoveUserDialog(
                              u['id'],
                              u['nama'],
                              'unassigned',
                              closeParentSheet: false,
                            ); // reuse dialog
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                          child: const Text("Pilih Kelas"),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
