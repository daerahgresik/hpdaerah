import 'package:flutter/material.dart';
import 'package:hpdaerah/models/user_model.dart';
import 'dart:math' as math;
import 'atur_target_khataman_page.dart';
import 'khataman_kelas_page.dart';
import 'khataman_user_page.dart';

/// Dashboard Khataman yang modern dengan grafik dan animasi
class KhatamanPage extends StatefulWidget {
  final UserModel? user;
  final String? orgId;

  const KhatamanPage({super.key, this.user, this.orgId});

  @override
  State<KhatamanPage> createState() => _KhatamanPageState();
}

class _KhatamanPageState extends State<KhatamanPage>
    with TickerProviderStateMixin {
  late AnimationController _progressController;
  late AnimationController _pulseController;

  // State navigasi inline
  // 'dashboard', 'target', 'kelas', 'user'
  String _activeMenu = 'dashboard';

  // Dummy data - akan diganti dengan data real dari database
  final double _overallProgress = 0.65; // 65%
  final int _totalKelas = 12;
  final int _kelasKhatam = 4;
  final int _totalUser = 156;
  final int _userKhatam = 42;

  // Top performers
  final List<Map<String, dynamic>> _topKelas = [
    {'name': 'Kelas Dewasa Putra', 'progress': 0.92, 'juz': 28},
    {'name': 'Kelas Remaja Putri', 'progress': 0.85, 'juz': 26},
    {'name': 'Kelas Anak-Anak', 'progress': 0.78, 'juz': 23},
    {'name': 'Kelas Dewasa Putri', 'progress': 0.72, 'juz': 22},
  ];

  final List<Map<String, dynamic>> _topUsers = [
    {
      'name': 'Ahmad Fauzi',
      'progress': 1.0,
      'juz': 30,
      'kelas': 'Dewasa Putra',
    },
    {
      'name': 'Siti Aminah',
      'progress': 0.97,
      'juz': 29,
      'kelas': 'Dewasa Putri',
    },
    {
      'name': 'Muhammad Rizki',
      'progress': 0.93,
      'juz': 28,
      'kelas': 'Remaja Putra',
    },
    {
      'name': 'Fatimah Zahra',
      'progress': 0.90,
      'juz': 27,
      'kelas': 'Remaja Putri',
    },
    {
      'name': 'Abdullah Rahman',
      'progress': 0.87,
      'juz': 26,
      'kelas': 'Dewasa Putra',
    },
  ];

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..forward();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _progressController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  // Helper untuk mengubah menu aktif
  void _setActiveMenu(String menu) {
    setState(() {
      _activeMenu = menu;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header dengan Overall Progress Circle
        _buildHeaderWithCircularProgress(),
        const SizedBox(height: 20),

        // 3 Action Buttons - Modern Style (Inline switching)
        _buildActionButtons(),
        const SizedBox(height: 24),

        // Dynamic Content Area
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _buildContent(),
        ),
      ],
    );
  }

  Widget _buildContent() {
    switch (_activeMenu) {
      case 'target':
        return AturTargetKhatamanPage(
          key: const ValueKey('target'),
          user: widget.user!,
          orgId: widget.orgId!,
        );
      case 'kelas':
        return KhatamanKelasPage(
          key: const ValueKey('kelas'),
          user: widget.user!,
          orgId: widget.orgId!,
        );
      case 'user':
        return KhatamanUserPage(
          key: const ValueKey('user'),
          user: widget.user!,
          orgId: widget.orgId!,
        );
      case 'dashboard':
      default:
        return _buildDashboardView();
    }
  }

  // Dashboard View: Charts & Stats
  Widget _buildDashboardView() {
    return Column(
      key: const ValueKey('dashboard'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Stats Cards Row
        _buildStatsRow(),
        const SizedBox(height: 24),

        // Progress Kelas Section
        _buildKelasProgressSection(),
        const SizedBox(height: 24),

        // Top Users Leaderboard
        _buildUserLeaderboard(),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        _buildMenuButton(
          icon: Icons.settings,
          label: 'Atur Target',
          color: Colors.blue,
          MenuId: 'target',
        ),
        const SizedBox(width: 12),
        _buildMenuButton(
          icon: Icons.school,
          label: 'Info Kelas',
          color: Colors.amber.shade700,
          MenuId: 'kelas',
        ),
        const SizedBox(width: 12),
        _buildMenuButton(
          icon: Icons.person,
          label: 'Info User',
          color: Colors.teal,
          MenuId: 'user',
        ),
      ],
    );
  }

  Widget _buildMenuButton({
    required IconData icon,
    required String label,
    required Color color,
    required String MenuId,
  }) {
    bool isActive = _activeMenu == MenuId;

    return Expanded(
      child: InkWell(
        onTap: () {
          if (isActive) {
            // Toggle off (back to dashboard) if clicked again
            _setActiveMenu('dashboard');
          } else {
            _setActiveMenu(MenuId);
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isActive ? color : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: isActive ? 0.4 : 0.15),
                blurRadius: isActive ? 12 : 10,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(
              color: isActive ? color : color.withValues(alpha: 0.1),
              width: isActive ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isActive
                      ? Colors.white.withValues(alpha: 0.2)
                      : color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: isActive ? Colors.white : color,
                  size: 24,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: isActive ? Colors.white : Colors.grey[800],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ... (Sisa kode method _buildHeader, _buildStatsRow, _buildStatCard, dll tetap sama)
  // Saya copy implementation sisanya di bawah

  Widget _buildHeaderWithCircularProgress() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A5F2D), Color(0xFF2E8B57)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A5F2D).withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          // Circular Progress
          AnimatedBuilder(
            animation: _progressController,
            builder: (context, child) {
              return SizedBox(
                width: 120,
                height: 120,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Background circle
                    SizedBox(
                      width: 120,
                      height: 120,
                      child: CircularProgressIndicator(
                        value: 1,
                        strokeWidth: 10,
                        backgroundColor: Colors.transparent,
                        valueColor: AlwaysStoppedAnimation(
                          Colors.white.withValues(alpha: 0.2),
                        ),
                      ),
                    ),
                    // Animated progress
                    SizedBox(
                      width: 120,
                      height: 120,
                      child: CircularProgressIndicator(
                        value: _overallProgress * _progressController.value,
                        strokeWidth: 10,
                        strokeCap: StrokeCap.round,
                        backgroundColor: Colors.transparent,
                        valueColor: const AlwaysStoppedAnimation(Colors.white),
                      ),
                    ),
                    // Center text
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${(_overallProgress * 100 * _progressController.value).toInt()}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Text(
                          'Progress',
                          style: TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(width: 24),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.auto_stories,
                      color: Colors.white,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Kelola Khataman',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Pantau progress khataman Al-Quran\nseluruh kelas dan anggota',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                // Pulse indicator
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(
                          alpha: 0.15 + (_pulseController.value * 0.1),
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: Colors.greenAccent,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.greenAccent.withValues(
                                    alpha: _pulseController.value,
                                  ),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Live Tracking',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            icon: Icons.school,
            label: 'Kelas',
            value: '$_kelasKhatam/$_totalKelas',
            subtitle: 'Sudah khatam',
            progress: _kelasKhatam / _totalKelas,
            color: Colors.amber.shade700,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            icon: Icons.people,
            label: 'Anggota',
            value: '$_userKhatam/$_totalUser',
            subtitle: 'Sudah khatam',
            progress: _userKhatam / _totalUser,
            color: Colors.teal,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required String subtitle,
    required double progress,
    required Color color,
  }) {
    return AnimatedBuilder(
      animation: _progressController,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.15),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  const Spacer(),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                value,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
              const SizedBox(height: 12),
              // Progress bar
              Stack(
                children: [
                  Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 500),
                    height: 6,
                    width:
                        (MediaQuery.of(context).size.width / 2 - 50) *
                        progress *
                        _progressController.value,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [color, color.withValues(alpha: 0.7)],
                      ),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildKelasProgressSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.amber.shade400, Colors.orange.shade400],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.bar_chart,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Progress Per Kelas',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  // TODO: Navigate to full list
                },
                child: Text(
                  'Lihat Semua',
                  style: TextStyle(color: Colors.amber.shade700, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Bar Chart
          ...List.generate(_topKelas.length, (index) {
            final kelas = _topKelas[index];
            return AnimatedBuilder(
              animation: _progressController,
              builder: (context, child) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              kelas['name'],
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _getProgressColor(
                                kelas['progress'],
                              ).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'Juz ${kelas['juz']}/30',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: _getProgressColor(kelas['progress']),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Stack(
                        children: [
                          Container(
                            height: 10,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              return AnimatedContainer(
                                duration: Duration(
                                  milliseconds: 500 + (index * 100),
                                ),
                                height: 10,
                                width:
                                    constraints.maxWidth *
                                    (kelas['progress'] as double) *
                                    _progressController.value,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      _getProgressColor(kelas['progress']),
                                      _getProgressColor(
                                        kelas['progress'],
                                      ).withValues(alpha: 0.7),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(5),
                                  boxShadow: [
                                    BoxShadow(
                                      color: _getProgressColor(
                                        kelas['progress'],
                                      ).withValues(alpha: 0.3),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            );
          }),
        ],
      ),
    );
  }

  Widget _buildUserLeaderboard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.teal.shade400, Colors.green.shade400],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.emoji_events,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Top Performers',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Text(
                    'Anggota dengan progress tertinggi',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  // TODO: Navigate to full list
                },
                child: const Text(
                  'Lihat Semua',
                  style: TextStyle(color: Colors.teal, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Leaderboard list
          ...List.generate(_topUsers.length, (index) {
            final user = _topUsers[index];
            final isKhatam = (user['progress'] as double) >= 1.0;

            return AnimatedBuilder(
              animation: _progressController,
              builder: (context, child) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: index == 0
                        ? Colors.amber.shade50
                        : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: index == 0
                        ? Border.all(color: Colors.amber.shade200)
                        : null,
                  ),
                  child: Row(
                    children: [
                      // Rank badge
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: index == 0
                                ? [
                                    Colors.amber.shade400,
                                    Colors.orange.shade400,
                                  ]
                                : index == 1
                                ? [Colors.grey.shade400, Colors.grey.shade500]
                                : index == 2
                                ? [Colors.brown.shade300, Colors.brown.shade400]
                                : [Colors.grey.shade300, Colors.grey.shade400],
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: index < 3
                              ? const Icon(
                                  Icons.emoji_events,
                                  color: Colors.white,
                                  size: 16,
                                )
                              : Text(
                                  '${index + 1}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // User info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  user['name'],
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                                if (isKhatam) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.green,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'KHATAM',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 8,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            Text(
                              user['kelas'],
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Progress circle
                      SizedBox(
                        width: 44,
                        height: 44,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CircularProgressIndicator(
                              value:
                                  (user['progress'] as double) *
                                  _progressController.value,
                              strokeWidth: 4,
                              backgroundColor: Colors.grey.shade200,
                              valueColor: AlwaysStoppedAnimation(
                                _getProgressColor(user['progress']),
                              ),
                            ),
                            Text(
                              '${user['juz']}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: _getProgressColor(user['progress']),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          }),
        ],
      ),
    );
  }

  Color _getProgressColor(double progress) {
    if (progress >= 1.0) return Colors.green;
    if (progress >= 0.8) return Colors.teal;
    if (progress >= 0.5) return Colors.amber.shade700;
    return Colors.orange;
  }
}
