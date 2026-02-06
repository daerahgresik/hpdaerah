import 'package:flutter/material.dart';
import 'package:hpdaerah/models/organization_model.dart';
import 'package:hpdaerah/models/user_model.dart';
import 'package:hpdaerah/services/auth_service.dart';
import 'package:hpdaerah/services/organization_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:ui';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final OrganizationService _orgService = OrganizationService();
  final AuthService _authService = AuthService();

  // Selection States
  Organization? _selectedDaerah;
  Organization? _selectedDesa;
  Organization? _selectedKelompok;

  // Data Lists
  List<Organization> _daerahList = [];
  List<Organization> _desaList = [];
  List<Organization> _kelompokList = [];

  // Admin Results
  List<UserModel> _admins = [];
  bool _isLoadingAdmins = false;

  @override
  void initState() {
    super.initState();
    _loadDaerah();
  }

  Future<void> _loadDaerah() async {
    final list = await _orgService.fetchDaerah();
    if (mounted) {
      setState(() {
        _daerahList = list;
      });
    }
  }

  Future<void> _loadDesa(String districtsId) async {
    final list = await _orgService.fetchChildren(districtsId);
    if (mounted) {
      setState(() {
        _desaList = list;
        _selectedDesa = null;
        _kelompokList = [];
        _selectedKelompok = null;
        _admins = [];
      });
    }
  }

  Future<void> _loadKelompok(String villageId) async {
    final list = await _orgService.fetchChildren(villageId);
    if (mounted) {
      setState(() {
        _kelompokList = list;
        _selectedKelompok = null;
        _admins = [];
      });
    }
  }

  Future<void> _findAdmins() async {
    if (_selectedDaerah == null) return;

    setState(() {
      _isLoadingAdmins = true;
      _admins = [];
    });

    try {
      List<UserModel> foundAdmins = [];

      // 1. Admin Kelompok (Level 3) - Jika Kelompok dipilih
      if (_selectedKelompok != null) {
        final admins = await _authService.getAdminsByOrg(
          _selectedKelompok!.id,
          3,
        );
        foundAdmins.addAll(admins);
      }

      // 2. Admin Desa (Level 2) - Jika Desa dipilih
      if (_selectedDesa != null) {
        final admins = await _authService.getAdminsByOrg(_selectedDesa!.id, 2);
        foundAdmins.addAll(admins);
      }

      // 3. Admin Daerah (Level 1) - Selalu ambil jika Daerah dipilih
      if (_selectedDaerah != null) {
        final admins = await _authService.getAdminsByOrg(
          _selectedDaerah!.id,
          1,
        );
        foundAdmins.addAll(admins);
      }

      if (mounted) {
        setState(() {
          _admins = foundAdmins;
        });
      }
    } catch (e) {
      debugPrint("Error finding admins: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingAdmins = false;
        });
      }
    }
  }

  Future<void> _launchWhatsApp(String? number, String name) async {
    if (number == null || number.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Maaf, nomor WhatsApp $name tidak tersedia.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    // Format number: replace 08 with 628
    String phone = number.trim();
    if (phone.startsWith('0')) {
      phone = '62${phone.substring(1)}';
    }

    final url = Uri.parse(
      'https://wa.me/$phone?text=Assalamualaikum admin $name, saya lupa password akun saya. Mohon bantuannya.',
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tidak dapat membuka WhatsApp.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient (Matched with Login Page)
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0D4F21),
                  Color(0xFF1A5F2D),
                  Color(0xFF2E7D32),
                  Color(0xFF00695C),
                ],
                stops: [0.0, 0.3, 0.6, 1.0],
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Back Button
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  const Text(
                    'Lupa Password',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Pilih lokasi Anda untuk menemukan Admin yang dapat membantu mereset password.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Selection Card
                  ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Column(
                          children: [
                            _buildDropdown(
                              label: 'Daerah',
                              value: _selectedDaerah,
                              items: _daerahList,
                              onChanged: (val) {
                                setState(() {
                                  _selectedDaerah = val;
                                  _loadDesa(val!.id);
                                  _findAdmins(); // Refresh admins immediately
                                });
                              },
                            ),
                            const SizedBox(height: 16),
                            if (_selectedDaerah != null)
                              _buildDropdown(
                                label: 'Desa',
                                value: _selectedDesa,
                                items: _desaList,
                                onChanged: (val) {
                                  setState(() {
                                    _selectedDesa = val;
                                    _loadKelompok(val!.id);
                                    _findAdmins();
                                  });
                                },
                              ),
                            const SizedBox(height: 16),
                            if (_selectedDesa != null)
                              _buildDropdown(
                                label: 'Kelompok',
                                value: _selectedKelompok,
                                items: _kelompokList,
                                onChanged: (val) {
                                  setState(() {
                                    _selectedKelompok = val;
                                    _findAdmins();
                                  });
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Admin List
                  if (_isLoadingAdmins)
                    const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    )
                  else if (_admins.isNotEmpty) ...[
                    const Text(
                      'Admin yang Tersedia',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _admins.length,
                      itemBuilder: (context, index) {
                        final admin = _admins[index];
                        return _buildAdminCard(admin);
                      },
                    ),
                  ] else if (_selectedDaerah != null) ...[
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Belum ada admin terdaftar untuk wilayah ini.',
                          style: TextStyle(color: Colors.white),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required Organization? value,
    required List<Organization> items,
    required ValueChanged<Organization?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<Organization>(
              value: value,
              isExpanded: true,
              dropdownColor: const Color(0xFF1A5F2D),
              style: const TextStyle(color: Colors.white),
              icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
              hint: Text(
                'Pilih $label',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
              ),
              items: items.map((org) {
                return DropdownMenuItem(value: org, child: Text(org.name));
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAdminCard(UserModel admin) {
    String role = 'Admin';
    if (admin.adminLevel == 1) role = 'Admin Daerah';
    if (admin.adminLevel == 2) role = 'Admin Desa';
    if (admin.adminLevel == 3) role = 'Admin Kelompok';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xFF1A5F2D).withValues(alpha: 0.1),
            child: Text(
              admin.nama.isNotEmpty ? admin.nama[0].toUpperCase() : 'A',
              style: const TextStyle(
                color: Color(0xFF1A5F2D),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  admin.nama,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  role,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _launchWhatsApp(admin.noWa, admin.nama),
            icon: const Icon(
              Icons
                  .perm_phone_msg, // Or Icons.whatsapp if available in updated icons
              color: Color(0xFF25D366), // WhatsApp Green
              size: 28,
            ),
          ),
        ],
      ),
    );
  }
}
