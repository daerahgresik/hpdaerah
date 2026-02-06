import 'package:flutter/material.dart';
import 'package:hpdaerah/models/user_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Info User - Compact & Mobile Friendly
class KhatamanUserPage extends StatefulWidget {
  final UserModel user;
  final String orgId;

  const KhatamanUserPage({super.key, required this.user, required this.orgId});

  @override
  State<KhatamanUserPage> createState() => _KhatamanUserPageState();
}

class _KhatamanUserPageState extends State<KhatamanUserPage> {
  final _supabase = Supabase.instance.client;
  final _searchController = TextEditingController();

  bool _isLoading = true;
  List<Map<String, dynamic>> _userProgressList = [];
  List<Map<String, dynamic>> _filteredList = [];
  String _filter = 'Semua';

  // Stats
  int _totalUser = 0;
  int _totalKhatam = 0;
  double _avgProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _applyFilter();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      // 1. Get User Assignments with User details and Target details
      final assignments = await _supabase
          .from('khataman_assignment')
          .select(
            'id, user_id, master_target_id, users(nama), master_target_khataman(nama, jumlah_halaman)',
          )
          .eq('org_id', widget.orgId)
          .eq('target_type', 'user')
          .eq('is_active', true);

      if ((assignments as List).isEmpty) {
        if (mounted) {
          setState(() {
            _userProgressList = [];
            _filteredList = [];
            _isLoading = false;
          });
        }
        return;
      }

      final assignmentIds = assignments.map((e) => e['id'] as String).toList();

      // 2. Get Progress for these assignments
      final progressData = await _supabase
          .from('khataman_progress')
          .select('assignment_id, halaman_selesai')
          .inFilter('assignment_id', assignmentIds);

      // 3. Aggregate Data
      Map<String, int> progressMap = {}; // assignment_id -> total_read
      for (var p in (progressData as List)) {
        final aId = p['assignment_id'] as String;
        final pages = p['halaman_selesai'] as int? ?? 0;
        progressMap[aId] = (progressMap[aId] ?? 0) + pages;
      }

      List<Map<String, dynamic>> processedList = [];
      int khatamCount = 0;
      double totalProgressSum = 0.0;

      for (var a in assignments) {
        final user = a['users'] as Map<String, dynamic>?;
        final target = a['master_target_khataman'] as Map<String, dynamic>?;

        if (user == null || target == null) continue;

        final targetPages = target['jumlah_halaman'] as int? ?? 1;
        final readPages = progressMap[a['id']] ?? 0;
        final progress = (readPages / targetPages).clamp(0.0, 1.0);

        if (progress >= 1.0) khatamCount++;
        totalProgressSum += progress;

        processedList.add({
          'id': a['id'],
          'user_nama': user['nama'] ?? 'Unknown',
          'target_nama': target['nama'] ?? '-',
          'target_pages': targetPages,
          'read_pages': readPages,
          'progress': progress,
          'is_khatam': progress >= 1.0,
        });
      }

      // Update State
      if (mounted) {
        setState(() {
          _userProgressList = processedList;
          _totalUser = processedList.length;
          _totalKhatam = khatamCount;
          _avgProgress = _totalUser > 0 ? (totalProgressSum / _totalUser) : 0.0;
          _isLoading = false;
        });
        _applyFilter();
      }
    } catch (e) {
      debugPrint('Error loading user progress: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFilter() {
    final query = _searchController.text.toLowerCase();

    setState(() {
      _filteredList = _userProgressList.where((item) {
        final nameMatches = (item['user_nama'] as String)
            .toLowerCase()
            .contains(query);

        bool statusMatches = true;
        if (_filter == 'Khatam') {
          statusMatches = item['is_khatam'] == true;
        } else if (_filter == 'Proses') {
          statusMatches = item['is_khatam'] == false;
        }

        return nameMatches && statusMatches;
      }).toList();
    });
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
              colors: [Colors.teal.shade400, Colors.green.shade400],
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
                child: const Icon(Icons.people, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Progress User',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      'Kemajuan khataman per anggota',
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
            _buildStat('$_totalUser', 'User Target', Colors.teal),
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

        // Search
        Container(
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
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Cari user...',
              hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
              prefixIcon: Icon(Icons.search, size: 20, color: Colors.grey[400]),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              isDense: true,
            ),
            style: const TextStyle(fontSize: 13),
          ),
        ),
        const SizedBox(height: 10),

        // Filter chips
        Row(
          children: [
            const Text(
              'Daftar',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            _buildChip('Semua'),
            const SizedBox(width: 6),
            _buildChip('Khatam'),
            const SizedBox(width: 6),
            _buildChip('Proses'),
          ],
        ),
        const SizedBox(height: 10),

        // List Content
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_filteredList.isEmpty)
          _buildEmptyState()
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _filteredList.length,
            itemBuilder: (context, index) =>
                _buildUserItem(_filteredList[index]),
          ),
      ],
    );
  }

  Widget _buildUserItem(Map<String, dynamic> item) {
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
                    : Colors.teal.shade50,
                child: Icon(
                  isKhatam ? Icons.check : Icons.person,
                  size: 16,
                  color: isKhatam ? Colors.green : Colors.teal,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['user_nama'],
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

  Widget _buildChip(String label) {
    final isActive = _filter == label;
    return InkWell(
      onTap: () => setState(() {
        _filter = label;
        _applyFilter();
      }),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF1A5F2D) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: isActive ? Colors.white : Colors.grey[600],
          ),
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
          Icon(Icons.person_search_outlined, size: 36, color: Colors.grey[400]),
          const SizedBox(height: 8),
          Text(
            _searchController.text.isNotEmpty
                ? 'Tidak ditemukan'
                : 'Belum Ada Data Target',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _searchController.text.isNotEmpty
                ? 'Coba kata kunci lain'
                : 'Atur target khataman untuk\nmelihat progress user',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }
}
