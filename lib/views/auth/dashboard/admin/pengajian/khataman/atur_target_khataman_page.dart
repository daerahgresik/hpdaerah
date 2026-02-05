import 'package:flutter/material.dart';
import 'package:hpdaerah/models/user_model.dart';

/// Halaman untuk mengatur target khataman per kelas dan per user
class AturTargetKhatamanPage extends StatefulWidget {
  final UserModel user;
  final String orgId;

  const AturTargetKhatamanPage({
    super.key,
    required this.user,
    required this.orgId,
  });

  @override
  State<AturTargetKhatamanPage> createState() => _AturTargetKhatamanPageState();
}

class _AturTargetKhatamanPageState extends State<AturTargetKhatamanPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: TabBar(
                  controller: _tabController,
                  labelColor: const Color(0xFF1A5F2D),
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: const Color(0xFF1A5F2D),
                  indicatorSize: TabBarIndicatorSize.label,
                  tabs: const [
                    Tab(icon: Icon(Icons.school, size: 20), text: 'Per Kelas'),
                    Tab(icon: Icon(Icons.person, size: 20), text: 'Per User'),
                  ],
                ),
              ),
              const Divider(height: 1),
              SizedBox(
                height: 400, // Fixed height for embedded tab view
                child: TabBarView(
                  controller: _tabController,
                  children: [_buildTargetKelasTab(), _buildTargetUserTab()],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _showAddTargetDialog,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A5F2D),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 4,
            ),
            icon: const Icon(Icons.add_circle_outline),
            label: const Text(
              'Tambah Target Baru',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTargetKelasTab() {
    return RefreshIndicator(
      onRefresh: () async {
        // TODO: Refresh data
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Info Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.amber.shade400, Colors.orange.shade400],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.auto_stories,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Target Khataman Kelas',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Atur target khataman Al-Quran untuk setiap kelas',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Placeholder - will be replaced with actual data
          _buildEmptyState(
            icon: Icons.school_outlined,
            title: 'Belum Ada Target Kelas',
            subtitle:
                'Tekan tombol "Tambah Target" untuk mengatur target khataman per kelas',
          ),
        ],
      ),
    );
  }

  Widget _buildTargetUserTab() {
    return RefreshIndicator(
      onRefresh: () async {
        // TODO: Refresh data
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Info Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.teal.shade400, Colors.green.shade400],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Target Khataman User',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Atur target khataman Al-Quran untuk user tertentu',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Placeholder
          _buildEmptyState(
            icon: Icons.person_outline,
            title: 'Belum Ada Target User',
            subtitle:
                'Tekan tombol "Tambah Target" untuk mengatur target khataman per user',
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 48, color: Colors.grey[400]),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[500],
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  void _showAddTargetDialog() {
    final isKelas = _tabController.index == 0;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          isKelas ? 'Tambah Target Kelas' : 'Tambah Target User',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Dropdown pilih kelas/user
            DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: isKelas ? 'Pilih Kelas' : 'Pilih User',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              items: const [], // TODO: Fill with data
              onChanged: (val) {},
            ),
            const SizedBox(height: 16),

            // Target Juz
            TextFormField(
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Target Juz (1-30)',
                hintText: 'Contoh: 30',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Target Deadline
            TextFormField(
              readOnly: true,
              decoration: InputDecoration(
                labelText: 'Target Selesai',
                hintText: 'Pilih tanggal',
                suffixIcon: const Icon(Icons.calendar_today),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onTap: () async {
                await showDatePicker(
                  context: context,
                  initialDate: DateTime.now().add(const Duration(days: 30)),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                );
              },
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
              // TODO: Save target
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Target berhasil ditambahkan!'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A5F2D),
              foregroundColor: Colors.white,
            ),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }
}
