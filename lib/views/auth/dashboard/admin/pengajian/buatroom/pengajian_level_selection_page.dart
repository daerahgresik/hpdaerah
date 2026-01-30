import 'package:flutter/material.dart';
import 'package:hpdaerah/models/user_model.dart';
import 'package:hpdaerah/models/pengajian_template_model.dart';
import 'package:hpdaerah/models/pengajian_model.dart';
import 'package:hpdaerah/services/pengajian_template_service.dart';
import 'package:hpdaerah/views/auth/dashboard/admin/pengajian/buatroom/pengajian_form_page.dart';

class PengajianLevelPage extends StatefulWidget {
  final UserModel user;
  final String orgId;

  const PengajianLevelPage({
    super.key,
    required this.user,
    required this.orgId,
  });

  @override
  State<PengajianLevelPage> createState() => _PengajianLevelPageState();
}

class _PengajianLevelPageState extends State<PengajianLevelPage> {
  final _templateService = PengajianTemplateService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pilih Tingkat Pengajian'),
        backgroundColor: const Color(0xFF1A5F2D),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<PengajianTemplate>>(
        stream: _templateService.streamTemplates(widget.orgId),
        builder: (context, snapshot) {
          final templates = snapshot.data ?? [];

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildSection(
                context,
                title: 'DAERAH',
                level: 'Daerah',
                color: Colors.red,
                icon: Icons.flag,
                templates: templates,
              ),
              const SizedBox(height: 24),
              _buildSection(
                context,
                title: 'DESA',
                level: 'Desa',
                color: Colors.blue,
                icon: Icons.home_work,
                templates: templates,
              ),
              const SizedBox(height: 24),
              _buildSection(
                context,
                title: 'KELOMPOK',
                level: 'Kelompok',
                color: Colors.green,
                icon: Icons.groups,
                templates: templates,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required String level,
    required Color color,
    required IconData icon,
    required List<PengajianTemplate> templates,
  }) {
    // Filter templates for this level
    final levelTemplates = templates.where((t) => t.level == level).toList();

    return Column(
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
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color.withValues(alpha: 0.8),
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // 1. Tombol Manual (Selalu Ada)
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _navigateToForm(context, level: level),
            icon: const Icon(Icons.edit_square, size: 18),
            label: Text('Buat Pengajian $level Manual'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black87,
              elevation: 1,
              padding: const EdgeInsets.symmetric(vertical: 12),
              alignment: Alignment.centerLeft,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade300),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // 2. Menu Cepat (Templates)
        if (levelTemplates.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: levelTemplates.map((t) {
              return ActionChip(
                avatar: const Icon(
                  Icons.flash_on,
                  size: 14,
                  color: Colors.amber,
                ),
                label: Text(t.name),
                backgroundColor: color.withValues(alpha: 0.05),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: color.withValues(alpha: 0.2)),
                ),
                onPressed: () => _navigateToForm(context, template: t),
              );
            }).toList(),
          ),

        // 3. Tombol Tambah Menu Cepat
        Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: InkWell(
            onTap: () => _showAddTemplateDialog(context, level),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade400),
                borderRadius: BorderRadius.circular(20),
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
    );
  }

  void _navigateToForm(
    BuildContext context, {
    String? level,
    PengajianTemplate? template,
  }) {
    // Jika manual: level ada, template null
    // Jika template: level ambil dari template, isi pre-filled data

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PengajianFormPage(
          user: widget.user,
          orgId: widget.orgId,
          scope: template?.level ?? level, // Level
          template: template != null
              ? Pengajian(
                  id: '',
                  orgId: widget.orgId,
                  title: template.defaultTitle,
                  description: template.defaultDescription,
                  location: template.defaultLocation,
                  startedAt: DateTime.now(),
                )
              : null,
        ),
      ),
    );
  }

  void _showAddTemplateDialog(BuildContext context, String level) {
    final nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Tambah Menu Cepat ($level)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Nama Menu (Label Tombol)',
                hintText: 'Contoh: Rutin Malam Jumat',
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Nantinya Anda bisa mengatur judul & deskripsi default untuk template ini.",
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                // Save
                _templateService.createTemplate(
                  PengajianTemplate(
                    id: '',
                    orgId: widget.orgId,
                    level: level,
                    name: nameController.text,
                    defaultTitle: "Pengajian $level - ${nameController.text}",
                    defaultDescription: "Pengajian rutin $level",
                  ),
                );
                Navigator.pop(ctx);
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }
}
