import 'package:flutter/material.dart';
import 'package:hpdaerah/models/user_model.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:barcode_widget/barcode_widget.dart';

class QrCodeTab extends StatelessWidget {
  final UserModel user;
  const QrCodeTab({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Text(
                      'Identitas Presensi',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A5F2D),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Scan untuk mencatat kehadiran',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                    const SizedBox(height: 32),

                    // QR IMAGE
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A5F2D).withOpacity(0.05),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: QrImageView(
                        data: user.username,
                        version: QrVersions.auto,
                        size: 200.0,
                        backgroundColor: Colors.transparent,
                        foregroundColor: const Color(0xFF1A5F2D),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // BARCODE 1D
                    Column(
                      children: [
                        BarcodeWidget(
                          barcode: Barcode.code128(),
                          data: user.username,
                          width: 250,
                          height: 70,
                          drawText: false,
                          color: Colors.black87,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          user.username.toUpperCase(),
                          style: const TextStyle(
                            letterSpacing: 2,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    const Divider(),
                    const SizedBox(height: 16),

                    Text(
                      user.nama,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'ID Anggota: ${user.username}',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 60), // Extra space for bottom nav
            ],
          ),
        ),
      ),
    );
  }
}
