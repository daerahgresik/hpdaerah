import 'package:flutter/material.dart';
import 'package:hpdaerah/models/organization_model.dart';
import 'package:hpdaerah/services/organization_service.dart';
import 'package:hpdaerah/views/auth/dashboard/admin/organisasi/organisasi_form_page.dart';

class OrganisasiListPage extends StatelessWidget {
  final String? parentId;
  final int level;
  // ParentName opsional untuk judul

  const OrganisasiListPage({
    super.key,
    this.parentId,
    this.level = 0,
    String? parentName,
  });

  @override
  Widget build(BuildContext context) {
    final OrganizationService orgService = OrganizationService();

    // Pilih Stream berdasarkan apakah ini halaman Root (Daerah) atau Sub-halaman (jarang dipakai di mode tree)
    // Di mode TreeView design baru, halaman ini HANYA menampilkan ROOT (Daerah).
    // Anak-anak akan dirender oleh Widget TreeItem secara rekursif via Stream.
    final stream = (level == 0 && parentId == null)
        ? orgService.streamDaerah()
        : orgService.streamChildren(parentId!);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA), // Modern minimalist background
      appBar: AppBar(
        title: const Text(
          'Manajemen Organisasi',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF1A5F2D),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      floatingActionButton: level == 0
          ? FloatingActionButton.extended(
              onPressed: () => _showAddDialog(context, null, 0),
              backgroundColor: const Color(0xFF1A5F2D),
              elevation: 4,
              icon: const Icon(Icons.add, weight: 600),
              label: const Text(
                'Tambah Daerah',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            )
          : null,
      body: StreamBuilder<List<Organization>>(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final list = snapshot.data ?? [];

          if (list.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.folder_off_outlined,
                    size: 60,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "Belum ada data",
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            itemCount: list.length,
            itemBuilder: (context, index) {
              return ModernOrgTreeItem(org: list[index]);
            },
          );
        },
      ),
    );
  }

  void _showAddDialog(BuildContext context, String? parentId, int parentLevel) {
    showDialog(
      context: context,
      builder: (_) =>
          OrganisasiFormDialog(parentId: parentId, parentLevel: parentLevel),
    );
  }
}

// --- MODERN TREE ITEM (RECURSIVE & REALTIME) ---

class ModernOrgTreeItem extends StatefulWidget {
  final Organization org;

  const ModernOrgTreeItem({super.key, required this.org});

  @override
  State<ModernOrgTreeItem> createState() => _ModernOrgTreeItemState();
}

class _ModernOrgTreeItemState extends State<ModernOrgTreeItem>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  final OrganizationService _service = OrganizationService();

  // Warna level yang lebih soft & modern
  Color get _levelColor {
    switch (widget.org.level) {
      case 0:
        return const Color(0xFF1A5F2D); // Dark Green
      case 1:
        return const Color(0xFF2E7D32); // Green
      case 2:
        return const Color(0xFF43A047); // Light Green
      case 3:
        return const Color(0xFF66BB6A); // Lighter Green
      default:
        return Colors.grey;
    }
  }

  String get _levelName {
    switch (widget.org.level) {
      case 0:
        return 'DAERAH';
      case 1:
        return 'DESA';
      case 2:
        return 'KELOMPOK';
      case 3:
        return 'KATEGORI';
      default:
        return 'ORG';
    }
  }

  void _toggleExpand() {
    setState(() => _isExpanded = !_isExpanded);
  }

  @override
  Widget build(BuildContext context) {
    final isLeaf = (widget.org.level ?? 0) >= 3;

    return Column(
      children: [
        // --- CARD UTAMA ---
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
            border: Border.all(
              color: _isExpanded
                  ? _levelColor.withValues(alpha: 0.5)
                  : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: isLeaf ? null : _toggleExpand,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    // Icon Box
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: _levelColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        isLeaf
                            ? Icons.person_outline
                            : (_isExpanded ? Icons.folder_open : Icons.folder),
                        color: _levelColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Texts
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.org.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  _levelName,
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ),
                              if (widget.org.level == 3 &&
                                  widget.org.ageCategory != null)
                                Padding(
                                  padding: const EdgeInsets.only(left: 6.0),
                                  child: Text(
                                    widget.org.ageCategory!
                                        .replaceAll('_', '-')
                                        .toUpperCase(), // Tampilkan format user friendly
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: _levelColor,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          // --- TAMBAHAN STATISTIK ---
                          if (!isLeaf)
                            Builder(
                              builder: (context) {
                                // CASE: DAERAH (Level 0) -> Tampilkan Desa & Kelompok
                                if (widget.org.level == 0) {
                                  return FutureBuilder<List<int>>(
                                    future: Future.wait([
                                      _service.getChildrenCount(widget.org.id),
                                      _service.getKelompokCountForDaerah(
                                        widget.org.id,
                                      ),
                                    ]),
                                    builder: (context, snapshot) {
                                      if (!snapshot.hasData) {
                                        return const SizedBox.shrink();
                                      }
                                      final desaCount = snapshot.data?[0] ?? 0;
                                      final kelompokCount =
                                          snapshot.data?[1] ?? 0;

                                      return Padding(
                                        padding: const EdgeInsets.only(top: 6),
                                        child: Row(
                                          children: [
                                            // Badge info Desa
                                            _buildStatBadge(
                                              '$desaCount Desa',
                                              Colors.blue,
                                            ),
                                            const SizedBox(width: 8),
                                            // Badge info Kelompok
                                            _buildStatBadge(
                                              '$kelompokCount Kelompok',
                                              Colors.orange,
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  );
                                }

                                // CASE: STANDAR (Desa/Kelompok) -> Tampilkan Anak langsung saja
                                return FutureBuilder<int>(
                                  future: _service.getChildrenCount(
                                    widget.org.id,
                                  ),
                                  builder: (context, snapshot) {
                                    if (!snapshot.hasData) {
                                      return const SizedBox.shrink();
                                    }
                                    final count = snapshot.data ?? 0;
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.subdirectory_arrow_right,
                                            size: 12,
                                            color: Colors.grey[500],
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            "$count ${_getNextLevelName()}",
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey[600],
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                    // Actions
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Edit
                        IconButton(
                          icon: const Icon(
                            Icons.edit_outlined,
                            size: 20,
                            color: Colors.blueGrey,
                          ),
                          visualDensity: VisualDensity.compact,
                          onPressed: () => _showEditDialog(context),
                        ),
                        // Delete
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            size: 20,
                            color: Colors.redAccent,
                          ),
                          visualDensity: VisualDensity.compact,
                          onPressed: _confirmDelete,
                        ),
                        // Arrow for expand
                        if (!isLeaf)
                          Icon(
                            _isExpanded
                                ? Icons.keyboard_arrow_up
                                : Icons.keyboard_arrow_down,
                            color: Colors.grey[400],
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // --- CHILDREN TREE ---
        if (_isExpanded && !isLeaf)
          StreamBuilder<List<Organization>>(
            stream: _service.streamChildren(widget.org.id),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              }

              var children = snapshot.data ?? [];

              // Custom Sort: Urutkan Kategori berdasarkan jenjang usia
              children.sort((a, b) {
                const sortOrder = {
                  'caberawit': 1,
                  'praremaja': 2,
                  'muda-mudi': 3,
                  'kelompok': 4,
                };

                final kA = a.ageCategory?.toLowerCase() ?? '';
                final kB = b.ageCategory?.toLowerCase() ?? '';

                final pA = sortOrder[kA] ?? 99;
                final pB = sortOrder[kB] ?? 99;

                if (pA != pB) return pA.compareTo(pB);
                return a.name.compareTo(b.name);
              });

              return Container(
                margin: const EdgeInsets.only(left: 22), // Indentasi
                padding: const EdgeInsets.only(left: 16, top: 8),
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(color: Colors.grey.shade300, width: 2),
                  ), // Tree Line
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header "Daftar Anak" + Tombol Tambah
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12, left: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Daftar ${_getNextLevelName()}",
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),

                          // Tombol Tambah Pintar
                          InkWell(
                            onTap: () => _showAddChildDialog(context),
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _levelColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: _levelColor.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.add, size: 14, color: _levelColor),
                                  const SizedBox(width: 4),
                                  Text(
                                    "Tambah",
                                    style: TextStyle(
                                      color: _levelColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // List Anak (Rekursif)
                    if (children.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16, left: 4),
                        child: Text(
                          "Belum ada data.",
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      )
                    else
                      Column(
                        children: children
                            .map((child) => ModernOrgTreeItem(org: child))
                            .toList(),
                      ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  String _getNextLevelName() {
    switch (widget.org.level) {
      case 0:
        return "Desa";
      case 1:
        return "Kelompok";
      case 2:
        return "Kategori";
      default:
        return "Item";
    }
  }

  Widget _buildStatBadge(String text, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.shade200),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color.shade700,
        ),
      ),
    );
  }

  void _showAddChildDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => OrganisasiFormDialog(
        parentId: widget.org.id,
        parentLevel: widget.org.level ?? 0,
      ),
    );
  }

  void _showEditDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => OrganisasiFormDialog(
        parentId: widget.org.parentId,
        parentLevel: widget.org.level ?? 0, // Level tidak berubah
        organization: widget.org,
      ),
    );
  }

  Future<void> _confirmDelete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Organisasi'),
        content: Text(
          'Anda yakin ingin menghapus "${widget.org.name}"?\nData anak di bawahnya akan ikut terhapus otomatis.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Hapus Permanen',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _service.deleteOrganization(widget.org.id);
        // Tidak perlu refresh manual, karena Stream akan otomatis update UI
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Berhasil dihapus")));
      } catch (e) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Gagal: $e")));
      }
    }
  }
}
