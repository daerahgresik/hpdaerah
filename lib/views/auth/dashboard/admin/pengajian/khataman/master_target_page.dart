import 'package:flutter/material.dart';
import 'package:hpdaerah/models/master_target_khataman_model.dart';
import 'package:hpdaerah/models/user_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Master Target Page - Compact & Mobile Friendly
class MasterTargetPage extends StatefulWidget {
  final UserModel user;
  final String orgId;

  const MasterTargetPage({super.key, required this.user, required this.orgId});

  @override
  State<MasterTargetPage> createState() => _MasterTargetPageState();
}

class _MasterTargetPageState extends State<MasterTargetPage> {
  final _supabase = Supabase.instance.client;
  List<MasterTargetKhataman> _targets = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTargets();
  }

  Future<void> _loadTargets() async {
    setState(() => _isLoading = true);
    try {
      final response = await _supabase
          .from('master_target_khataman')
          .select()
          .eq('org_id', widget.orgId)
          .eq('is_active', true)
          .order('created_at', ascending: false);

      setState(() {
        _targets = (response as List)
            .map((e) => MasterTargetKhataman.fromJson(e))
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _saveTarget(MasterTargetKhataman target) async {
    try {
      if (target.id.isEmpty) {
        await _supabase.from('master_target_khataman').insert(target.toJson());
      } else {
        await _supabase
            .from('master_target_khataman')
            .update(target.toJson())
            .eq('id', target.id);
      }
      _loadTargets();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Berhasil disimpan!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteTarget(String id) async {
    try {
      await _supabase
          .from('master_target_khataman')
          .update({'is_active': false})
          .eq('id', id);
      _loadTargets();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Berhasil dihapus!'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showTargetDialog({MasterTargetKhataman? target}) {
    final isEdit = target != null;
    final namaController = TextEditingController(text: target?.nama ?? '');
    final halamanController = TextEditingController(
      text: target?.jumlahHalaman.toString() ?? '',
    );
    final keteranganController = TextEditingController(
      text: target?.keterangan ?? '',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Title
              Text(
                isEdit ? 'Edit Target' : 'Tambah Target',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              // Form
              TextField(
                controller: namaController,
                decoration: InputDecoration(
                  labelText: 'Nama Target',
                  hintText: 'Contoh: Al-Quran',
                  prefixIcon: const Icon(Icons.auto_stories, size: 20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  isDense: true,
                ),
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 12),

              TextField(
                controller: halamanController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Jumlah Halaman',
                  hintText: 'Contoh: 604',
                  prefixIcon: const Icon(Icons.menu_book, size: 20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  isDense: true,
                ),
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 12),

              TextField(
                controller: keteranganController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Keterangan (opsional)',
                  hintText: 'Catatan tambahan...',
                  prefixIcon: const Padding(
                    padding: EdgeInsets.only(bottom: 24),
                    child: Icon(Icons.note, size: 20),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  isDense: true,
                ),
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),

              // Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('Batal'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        final nama = namaController.text.trim();
                        final halaman =
                            int.tryParse(halamanController.text.trim()) ?? 0;
                        final keterangan = keteranganController.text.trim();

                        if (nama.isEmpty || halaman <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Lengkapi data!'),
                              backgroundColor: Colors.orange,
                            ),
                          );
                          return;
                        }

                        final newTarget = MasterTargetKhataman(
                          id: target?.id ?? '',
                          orgId: widget.orgId,
                          nama: nama,
                          jumlahHalaman: halaman,
                          keterangan: keterangan.isNotEmpty ? keterangan : null,
                          createdBy: widget.user.id,
                        );

                        Navigator.pop(ctx);
                        _saveTarget(newTarget);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1A5F2D),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(isEdit ? 'Simpan' : 'Tambah'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.purple.shade400, Colors.deepPurple.shade400],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.library_books,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Master Target',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      'Daftar target bacaan',
                      style: TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ],
                ),
              ),
              // Add button
              InkWell(
                onTap: () => _showTargetDialog(),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add, size: 16, color: Colors.purple.shade700),
                      const SizedBox(width: 4),
                      Text(
                        'Tambah',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.purple.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Content
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_targets.isEmpty)
          _buildEmptyState()
        else
          ..._targets.map((t) => _buildTargetItem(t)),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(Icons.library_books_outlined, size: 40, color: Colors.grey[400]),
          const SizedBox(height: 8),
          Text(
            'Belum Ada Target',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tambahkan target bacaan\nseperti Al-Quran, Hadis, dll',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildTargetItem(MasterTargetKhataman target) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF1A5F2D).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.auto_stories,
            color: Color(0xFF1A5F2D),
            size: 18,
          ),
        ),
        title: Text(
          target.nama,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        subtitle: Text(
          '${target.jumlahHalaman} halaman${target.keterangan != null ? ' • ${target.keterangan}' : ''}',
          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: PopupMenuButton<String>(
          icon: Icon(Icons.more_vert, size: 18, color: Colors.grey[400]),
          padding: EdgeInsets.zero,
          itemBuilder: (ctx) => [
            const PopupMenuItem(
              value: 'edit',
              child: Text('Edit', style: TextStyle(fontSize: 13)),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Text(
                'Hapus',
                style: TextStyle(fontSize: 13, color: Colors.red),
              ),
            ),
          ],
          onSelected: (val) {
            if (val == 'edit') {
              _showTargetDialog(target: target);
            } else if (val == 'delete') {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text(
                    'Hapus Target?',
                    style: TextStyle(fontSize: 15),
                  ),
                  content: Text(
                    'Hapus "${target.nama}"?',
                    style: const TextStyle(fontSize: 13),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Batal'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _deleteTarget(target.id);
                      },
                      child: const Text(
                        'Hapus',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              );
            }
          },
        ),
        onTap: () => _showTargetDialog(target: target),
      ),
    );
  }
}
