import 'package:flutter/material.dart';

class PengajianSearchPage extends StatelessWidget {
  const PengajianSearchPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cari Room Pengajian'),
        backgroundColor: const Color(0xFF1A5F2D),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_rounded, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              "Fitur Pencarian",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Akan segera hadir untuk mencari pengajian\nlintas daerah/desa.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }
}
