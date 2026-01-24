import 'package:flutter/material.dart';
import 'package:hpdaerah/views/auth/dashboard/admin/presensi/daftar_hadir_page.dart';

class PresensiCenterPage extends StatefulWidget {
  const PresensiCenterPage({super.key});

  @override
  State<PresensiCenterPage> createState() => _PresensiCenterPageState();
}

class _PresensiCenterPageState extends State<PresensiCenterPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
        title: const Text(
          'Presensi Center',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF1A5F2D),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.white,
          indicatorSize: TabBarIndicatorSize.label,
          indicatorWeight: 3,
          dividerColor: Colors.transparent,
          tabs: const [
            Tab(text: 'Manual', icon: Icon(Icons.edit_note_rounded)),
            Tab(text: 'Izin', icon: Icon(Icons.assignment_late_outlined)),
            Tab(text: 'Rekap', icon: Icon(Icons.bar_chart_rounded)),
          ],
        ),
      ),
      body: Container(
        margin: const EdgeInsets.only(top: 16),
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildPlaceholder('Halaman Approve Manual'),
            _buildPlaceholder('Halaman Kelola Izin'),
            const DaftarHadirPage(), // New Page
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder(String title) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey[200],
            ),
            child: Icon(
              Icons.build_circle_outlined,
              size: 48,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "(Segera Hadir)",
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
