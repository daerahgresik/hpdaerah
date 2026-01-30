import 'package:flutter/material.dart';
import 'package:hpdaerah/models/target_kriteria_model.dart';
import 'package:hpdaerah/models/user_model.dart';
import 'package:hpdaerah/services/target_kriteria_service.dart';

class TargetKriteriaManagementPage extends StatefulWidget {
  final UserModel user;
  final String orgId;

  const TargetKriteriaManagementPage({
    super.key,
    required this.user,
    required this.orgId,
  });

  @override
  State<TargetKriteriaManagementPage> createState() =>
      _TargetKriteriaManagementPageState();
}

class _TargetKriteriaManagementPageState
    extends State<TargetKriteriaManagementPage> {
  final _service = TargetKriteriaService();
  bool _isLoading = true;
  List<TargetKriteria> _targets = [];

  @override
  void initState() {
    super.initState();
    _fetchTargets();
  }

  Future<void> _fetchTargets() async {
    setState(() => _isLoading = true);
    final list = await _service.fetchAllTargetsInHierarchy(
      orgId: widget.orgId,
      adminLevel: widget.user.adminLevel ?? 4,
    );
    setState(() {
      _targets = list;
      _isLoading = false;
    });
  }

  void _showAddDialog() {
    final nameController = TextEditingController();
    int minUmur = 0;
    int maxUmur = 100;
    String selectedJK = 'Semua';
    String selectedStatus = 'Semua';
    String selectedKeperluan = 'Semua';

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
                  createdBy: widget.user.id,
                );
                await _service.createTarget(newTarget);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Kelola Target Peserta"),
        backgroundColor: const Color(0xFF1A5F2D),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _targets.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.person_search, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  const Text("Belum ada target kustom"),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _showAddDialog,
                    child: const Text("Buat Target Pertama"),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _targets.length,
              itemBuilder: (context, index) {
                final t = _targets[index];
                final isMine = t.orgId == widget.orgId;

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isMine
                          ? Colors.green.shade200
                          : Colors.grey.shade200,
                    ),
                  ),
                  child: ListTile(
                    title: Text(
                      t.namaTarget,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      "Kriteria: ${t.jenisKelamin}, ${t.minUmur}-${t.maxUmur} thn, ${t.statusWarga}",
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: isMine
                        ? IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.red,
                            ),
                            onPressed: () async {
                              await _service.deleteTarget(t.id);
                              _fetchTargets();
                            },
                          )
                        : Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              "PINJAMAN",
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.blue,
                              ),
                            ),
                          ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        backgroundColor: const Color(0xFF1A5F2D),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
