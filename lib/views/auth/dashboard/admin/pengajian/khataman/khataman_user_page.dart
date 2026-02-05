import 'package:flutter/material.dart';
import 'package:hpdaerah/models/user_model.dart';

/// Halaman untuk melihat progress khataman per user
class KhatamanUserPage extends StatefulWidget {
  final UserModel user;
  final String orgId;

  const KhatamanUserPage({super.key, required this.user, required this.orgId});

  @override
  State<KhatamanUserPage> createState() => _KhatamanUserPageState();
}

class _KhatamanUserPageState extends State<KhatamanUserPage> {
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Summary Card
        _buildSummaryCard(),
        const SizedBox(height: 20),

        // Search Bar
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Cari nama user...',
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        setState(() {
                          _searchController.clear();
                          _searchQuery = '';
                        });
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
            onChanged: (val) => setState(() => _searchQuery = val),
          ),
        ),
        const SizedBox(height: 20),

        // Header
        Row(
          children: [
            const Text(
              'Daftar User',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            _buildFilterChip('Semua', true),
            const SizedBox(width: 8),
            _buildFilterChip('Khatam', false),
            const SizedBox(width: 8),
            _buildFilterChip('Proses', false),
          ],
        ),
        const SizedBox(height: 12),

        // Content
        _buildEmptyState(),
      ],
    );
  }

  Widget _buildFilterChip(String label, bool isSelected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF1A5F2D) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected ? const Color(0xFF1A5F2D) : Colors.grey.shade300,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: isSelected ? Colors.white : Colors.grey[600],
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.teal.shade400, Colors.green.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Progress Khataman User',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Pantau kemajuan khataman setiap anggota',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _buildStatItem('0', 'Total User'),
              _buildStatItem('0', 'Sudah Khatam'),
              _buildStatItem('0%', 'Rata-rata'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
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
              color: Colors.teal.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.person_search_outlined,
              size: 48,
              color: Colors.teal[400],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Belum Ada Data Khataman User',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Atur target khataman terlebih dahulu untuk melihat progress',
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
}
