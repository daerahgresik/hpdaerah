import 'package:flutter/material.dart';
import 'package:hpdaerah/models/user_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Info Kelas - Compact & Mobile Friendly
class KhatamanKelasPage extends StatefulWidget {
  final UserModel user;
  final String orgId;

  const KhatamanKelasPage({super.key, required this.user, required this.orgId});

  @override
  State<KhatamanKelasPage> createState() => _KhatamanKelasPageState();
}

class _KhatamanKelasPageState extends State<KhatamanKelasPage> {
  final _supabase = Supabase.instance.client;

  bool _isLoading = true;
  List<Map<String, dynamic>> _kelasProgressList = [];

  // Stats
  int _totalKelas = 0;
  int _totalKhatam = 0;
  double _avgProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      // 1. Get Kelas Assignments
      final assignments = await _supabase
          .from('khataman_assignment')
          .select(
            'id, kelas_id, master_target_id, kelas(nama), master_target_khataman(nama, jumlah_halaman)',
          )
          .eq('org_id', widget.orgId)
          .eq('target_type', 'kelas')
          .eq('is_active', true);

      if ((assignments as List).isEmpty) {
        if (mounted) {
          setState(() {
            _kelasProgressList = [];
            _isLoading = false;
          });
        }
        return;
      }

      final assignmentIds = assignments.map((e) => e['id'] as String).toList();

      // 2. Get Progress
      final progressData = await _supabase
          .from('khataman_progress')
          .select('assignment_id, user_id, halaman_selesai')
          .inFilter('assignment_id', assignmentIds);

      // 3. Aggregate
      Map<String, int> progressMap = {}; // assignment_id -> total_read
      for (var p in (progressData as List)) {
        final aId = p['assignment_id'] as String;
        // In class context, multiple users contribute to one assignment
        final pages = p['halaman_selesai'] as int? ?? 0;
        progressMap[aId] = (progressMap[aId] ?? 0) + pages;
      }

      List<Map<String, dynamic>> processedList = [];
      int khatamCount = 0;
      double totalProgressSum = 0.0;

      for (var a in assignments) {
        final kelas = a['kelas'] as Map<String, dynamic>?;
        final target = a['master_target_khataman'] as Map<String, dynamic>?;

        if (kelas == null || target == null) continue;

        final targetPages = target['jumlah_halaman'] as int? ?? 1;
        final readPages = progressMap[a['id']] ?? 0;
        final progress = (readPages / targetPages).clamp(0.0, 1.0);

        if (progress >= 1.0) khatamCount++;
        totalProgressSum += progress;

        processedList.add({
          'id': a['id'],
          'kelas_nama': kelas['nama'] ?? 'Unknown',
          'target_nama': target['nama'] ?? '-',
          'target_pages': targetPages,
          'read_pages': readPages,
          'progress': progress,
          'is_khatam': progress >= 1.0,
        });
      }

      if (mounted) {
        setState(() {
          _kelasProgressList = processedList;
          _totalKelas = processedList.length;
          _totalKhatam = khatamCount;
          _avgProgress = _totalKelas > 0
              ? (totalProgressSum / _totalKelas)
              : 0.0;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading kelas progress: $e');
      if (mounted) setState(() => _isLoading = false);
    }
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
              colors: [Colors.amber.shade400, Colors.orange.shade400],
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
                child: const Icon(Icons.school, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Progress Kelas',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      'Kemajuan khataman per kelas',
                      style: TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white, size: 20),
                onPressed: _loadData,
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Stats Row
        Row(
          children: [
            _buildStat('$_totalKelas', 'Target Kelas', Colors.amber.shade700),
            const SizedBox(width: 8),
            _buildStat('$_totalKhatam', 'Khatam', Colors.green),
            const SizedBox(width: 8),
            _buildStat(
              '${(_avgProgress * 100).toInt()}%',
              'Avg Progress',
              Colors.blue,
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Filter (Placeholder for now)
        Row(
          children: [
            const Text(
              'Daftar Kelas',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.filter_list, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    'Filter',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // List Content
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_kelasProgressList.isEmpty)
          _buildEmptyState()
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _kelasProgressList.length,
            itemBuilder: (context, index) =>
                _buildKelasItem(_kelasProgressList[index]),
          ),
      ],
    );
  }

  Widget _buildKelasItem(Map<String, dynamic> item) {
    final progress = item['progress'] as double;
    final isKhatam = item['is_khatam'] as bool;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 4),
        ],
        border: isKhatam
            ? Border.all(color: Colors.green.withValues(alpha: 0.3))
            : null,
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: isKhatam
                    ? Colors.green.shade100
                    : Colors.amber.shade50,
                child: Icon(
                  isKhatam ? Icons.check : Icons.school,
                  size: 16,
                  color: isKhatam ? Colors.green : Colors.amber,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['kelas_nama'],
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      'Target: ${item['target_nama']}',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${(progress * 100).toInt()}%',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: isKhatam ? Colors.green : Colors.blue,
                    ),
                  ),
                  Text(
                    '${item['read_pages']} / ${item['target_pages']} Hal',
                    style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: Colors.grey.shade100,
              valueColor: AlwaysStoppedAnimation(
                isKhatam ? Colors.green : Colors.blue,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStat(String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: color.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Icon(Icons.school_outlined, size: 36, color: Colors.grey[400]),
          const SizedBox(height: 8),
          Text(
            'Belum Ada Data Target',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Atur target khataman untuk\nmelihat progress kelas',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }
}
