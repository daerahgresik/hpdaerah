import 'package:flutter/material.dart';
import 'package:hpdaerah/models/user_model.dart';

/// Halaman untuk melihat progress khataman per kelas
class KhatamanKelasPage extends StatefulWidget {
  final UserModel user;
  final String orgId;

  const KhatamanKelasPage({super.key, required this.user, required this.orgId});

  @override
  State<KhatamanKelasPage> createState() => _KhatamanKelasPageState();
}

class _KhatamanKelasPageState extends State<KhatamanKelasPage> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildSummaryCard(),
        const SizedBox(height: 20),
        Row(
          children: [
            const Text(
              'Daftar Kelas',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.filter_list, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    'Filter',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildEmptyState(),
      ],
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.amber.shade400, Colors.orange.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withValues(alpha: 0.3),
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
                child: const Icon(Icons.school, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Progress Khataman Kelas',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Pantau kemajuan khataman setiap kelas',
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
              _buildStatItem('0', 'Total Kelas'),
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
              color: Colors.amber.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.auto_stories_outlined,
              size: 48,
              color: Colors.amber[400],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Belum Ada Data Khataman Kelas',
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
