import 'package:flutter/material.dart';
import 'package:hpdaerah/models/user_model.dart';
import 'package:hpdaerah/views/auth/login_page.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:hpdaerah/controllers/profile_controller.dart';

class ProfileTab extends StatefulWidget {
  final UserModel user;

  const ProfileTab({super.key, required this.user});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  late UserModel _currentUser;
  bool _isLoading = false;
  final ProfileController _profileController = ProfileController();

  @override
  void initState() {
    super.initState();
    _currentUser = widget.user;
  }

  Future<void> _updateProfile({
    required String nama,
    required String username,
    required String? asal,
    required String? status,
    required String? jenisKelamin,
    required DateTime? tanggalLahir,
    required String? asalDaerah,
    required String? keperluan,
    required String? detailKeperluan,
    required String? keterangan,
    required String? noWa,
    String? newPassword,
    dynamic newImageFile,
  }) async {
    setState(() => _isLoading = true);
    try {
      final updatedUser = await _profileController.updateProfile(
        currentUser: _currentUser,
        nama: nama,
        username: username,
        asal: asal,
        status: status,
        jenisKelamin: jenisKelamin,
        tanggalLahir: tanggalLahir,
        asalDaerah: asalDaerah,
        keperluan: keperluan,
        detailKeperluan: detailKeperluan,
        keterangan: keterangan,
        noWa: noWa,
        newPassword: newPassword,
        newImageFile: newImageFile,
      );

      setState(() {
        _currentUser = updatedUser;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Data profil berhasil disimpan!'),
            backgroundColor: Color(0xFF1A5F2D),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<dynamic> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: source,
      imageQuality: 70,
      maxWidth: 800,
    );

    if (pickedFile != null) {
      if (kIsWeb) return pickedFile;
      return File(pickedFile.path);
    }
    return null;
  }

  void _showEditFullProfileDialog() {
    final namaCtrl = TextEditingController(text: _currentUser.nama);
    final usernameCtrl = TextEditingController(text: _currentUser.username);
    final noWaCtrl = TextEditingController(text: _currentUser.noWa ?? '');
    final passwordCtrl = TextEditingController();
    final asalDaerahCtrl = TextEditingController(
      text: _currentUser.asalDaerah ?? '',
    );
    final detailKeperluanCtrl = TextEditingController(
      text: _currentUser.detailKeperluan ?? '',
    );
    final keteranganCtrl = TextEditingController(
      text: _currentUser.keterangan ?? '',
    );

    String? selectedCitizenStatus = _currentUser.asal;
    String? selectedMarriageStatus = _currentUser.status;
    String? selectedGender = _currentUser.jenisKelamin;
    DateTime? selectedBirthDate = _currentUser.tanggalLahir;
    String? selectedKeperluan = _currentUser.keperluan;
    bool obscurePassword = true;
    dynamic selectedImageFile; // Can be File or XFile
    Uint8List? selectedImageBytes;

    final statusOptions = ['Warga Asli', 'Perantau'];
    final keperluanOptions = ['MT', 'Kuliah', 'Bekerja'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.90,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SizedBox(height: 16),
                Center(
                  child: Container(
                    width: 50,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Edit Data Lengkap',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                Center(
                  child: Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 50,
                          backgroundColor: Colors.grey[200],
                          backgroundImage: selectedImageBytes != null
                              ? MemoryImage(selectedImageBytes!)
                              : (selectedImageFile != null && !kIsWeb
                                        ? FileImage(selectedImageFile as File)
                                        : (_currentUser.fotoProfil != null
                                              ? NetworkImage(
                                                  _currentUser.fotoProfil!,
                                                )
                                              : null))
                                    as ImageProvider?,
                          child:
                              (selectedImageFile == null &&
                                  _currentUser.fotoProfil == null)
                              ? const Icon(
                                  Icons.person,
                                  size: 50,
                                  color: Colors.grey,
                                )
                              : null,
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: () async {
                            showModalBottomSheet(
                              context: context,
                              builder: (ctx) => Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ListTile(
                                    leading: const Icon(Icons.camera_alt),
                                    title: const Text('Ambil Foto (Kamera)'),
                                    onTap: () async {
                                      Navigator.pop(ctx);
                                      final f = await _pickImage(
                                        ImageSource.camera,
                                      );
                                      if (f != null) {
                                        if (kIsWeb && f is XFile) {
                                          final bytes = await f.readAsBytes();
                                          setModalState(() {
                                            selectedImageFile = f;
                                            selectedImageBytes = bytes;
                                          });
                                        } else {
                                          setModalState(() {
                                            selectedImageFile = f;
                                          });
                                        }
                                      }
                                    },
                                  ),
                                  ListTile(
                                    leading: const Icon(Icons.photo_library),
                                    title: const Text('Pilih dari Galeri'),
                                    onTap: () async {
                                      Navigator.pop(ctx);
                                      final f = await _pickImage(
                                        ImageSource.gallery,
                                      );
                                      if (f != null) {
                                        if (kIsWeb && f is XFile) {
                                          final bytes = await f.readAsBytes();
                                          setModalState(() {
                                            selectedImageFile = f;
                                            selectedImageBytes = bytes;
                                          });
                                        } else {
                                          setModalState(() {
                                            selectedImageFile = f;
                                          });
                                        }
                                      }
                                    },
                                  ),
                                ],
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: Color(0xFF1A5F2D),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: ListView(
                    children: [
                      _buildSectionTitle('Info Utama'),
                      _buildTextField(namaCtrl, 'Nama Lengkap', Icons.person),
                      const SizedBox(height: 16),
                      _buildTextField(
                        usernameCtrl,
                        'Username',
                        Icons.alternate_email,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(noWaCtrl, 'No. WhatsApp', Icons.chat),
                      const SizedBox(height: 16),
                      _buildSectionTitle('Data Pribadi'),
                      // GENDER
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[500]!),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: ['Pria', 'Wanita'].contains(selectedGender)
                                ? selectedGender
                                : null,
                            hint: const Text('Pilih Jenis Kelamin'),
                            isExpanded: true,
                            items: ['Pria', 'Wanita']
                                .map(
                                  (e) => DropdownMenuItem(
                                    value: e,
                                    child: Text(e),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) =>
                                setModalState(() => selectedGender = val),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // MARRIAGE
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[500]!),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value:
                                [
                                  'Kawin',
                                  'Belum Kawin',
                                ].contains(selectedMarriageStatus)
                                ? selectedMarriageStatus
                                : null,
                            hint: const Text('Status Pernikahan'),
                            isExpanded: true,
                            items: ['Kawin', 'Belum Kawin']
                                .map(
                                  (e) => DropdownMenuItem(
                                    value: e,
                                    child: Text(e),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) => setModalState(
                              () => selectedMarriageStatus = val,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // BIRTH DATE
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: selectedBirthDate ?? DateTime(2000),
                            firstDate: DateTime(1900),
                            lastDate: DateTime.now(),
                            initialDatePickerMode: DatePickerMode.year,
                          );
                          if (picked != null) {
                            setModalState(() => selectedBirthDate = picked);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[500]!),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.calendar_today,
                                size: 20,
                                color: Colors.grey,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                selectedBirthDate == null
                                    ? 'Pilih Tanggal Lahir'
                                    : "${selectedBirthDate!.day}/${selectedBirthDate!.month}/${selectedBirthDate!.year}",
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildSectionTitle('Status Kewarganegaraan'),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[500]!),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: statusOptions.contains(selectedCitizenStatus)
                                ? selectedCitizenStatus
                                : null,
                            hint: const Text('Pilih Asal'),
                            isExpanded: true,
                            items: statusOptions
                                .map(
                                  (e) => DropdownMenuItem(
                                    value: e,
                                    child: Text(e),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) {
                              setModalState(() {
                                selectedCitizenStatus = val;
                                if (val == 'Warga Asli') {
                                  selectedKeperluan = null;
                                  asalDaerahCtrl.clear();
                                  detailKeperluanCtrl.clear();
                                }
                              });
                            },
                          ),
                        ),
                      ),
                      if (selectedCitizenStatus == 'Perantau') ...[
                        const SizedBox(height: 16),
                        _buildTextField(
                          asalDaerahCtrl,
                          'Asal Daerah (Kota/Kab)',
                          Icons.flight_land,
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[500]!),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value:
                                  keperluanOptions.contains(selectedKeperluan)
                                  ? selectedKeperluan
                                  : null,
                              hint: const Text('Pilih Keperluan'),
                              isExpanded: true,
                              items: keperluanOptions
                                  .map(
                                    (e) => DropdownMenuItem(
                                      value: e,
                                      child: Text(e),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (val) =>
                                  setModalState(() => selectedKeperluan = val),
                            ),
                          ),
                        ),
                        if (selectedKeperluan == 'Kuliah' ||
                            selectedKeperluan == 'Bekerja') ...[
                          const SizedBox(height: 16),
                          _buildTextField(
                            detailKeperluanCtrl,
                            selectedKeperluan == 'Kuliah'
                                ? 'Nama Kampus'
                                : 'Nama Tempat Kerja',
                            Icons.location_city,
                          ),
                        ],
                      ],
                      const SizedBox(height: 24),
                      _buildTextField(
                        keteranganCtrl,
                        'Catatan Tambahan (Opsional)',
                        Icons.note_alt,
                        maxLines: 2,
                      ),
                      const SizedBox(height: 24),
                      _buildSectionTitle('Keamanan (Opsional)'),
                      TextField(
                        controller: passwordCtrl,
                        obscureText: obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'Ganti Password Baru',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscurePassword
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                            onPressed: () => setModalState(
                              () => obscurePassword = !obscurePassword,
                            ),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                      ),
                      const SizedBox(height: 60),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading
                          ? null
                          : () {
                              _updateProfile(
                                nama: namaCtrl.text,
                                username: usernameCtrl.text,
                                asal: selectedCitizenStatus,
                                status: selectedMarriageStatus,
                                jenisKelamin: selectedGender,
                                tanggalLahir: selectedBirthDate,
                                asalDaerah: asalDaerahCtrl.text,
                                keperluan: selectedKeperluan ?? '',
                                detailKeperluan: detailKeperluanCtrl.text,
                                keterangan: keteranganCtrl.text,
                                noWa: noWaCtrl.text,
                                newPassword: passwordCtrl.text,
                                newImageFile: selectedImageFile,
                              );
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1A5F2D),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              'Simpan Perubahan',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.grey[50],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
          color: Color(0xFF1A5F2D),
        ),
      ),
    );
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konfirmasi Log Out'),
        content: const Text('Apakah anda yakin ingin keluar dari aplikasi?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const LoginPage()),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Keluar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryGreen = Color(0xFF1A5F2D);

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: Stack(
        children: [
          Container(
            height: 260,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1A5F2D), Color(0xFF2E7D32)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(36)),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Text(
                      'Profil Saya',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: primaryGreen.withValues(alpha: 0.2),
                              width: 2,
                            ),
                          ),
                          child: CircleAvatar(
                            radius: 45,
                            backgroundColor: primaryGreen.withValues(
                              alpha: 0.1,
                            ),
                            backgroundImage: _currentUser.fotoProfil != null
                                ? NetworkImage(_currentUser.fotoProfil!)
                                : null,
                            child: _currentUser.fotoProfil == null
                                ? const Icon(
                                    Icons.person,
                                    size: 50,
                                    color: primaryGreen,
                                  )
                                : null,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _currentUser.nama,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                        Text(
                          '@${_currentUser.username}',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildActionButton(
                              icon: Icons.edit,
                              label: 'Edit Lengkap',
                              color: Colors.orange,
                              onTap: _showEditFullProfileDialog,
                            ),
                            _buildActionButton(
                              icon: Icons.shield_outlined,
                              label: _currentUser.adminLevelName,
                              color: Colors.blue,
                              onTap: () {},
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // TAG: DIGITAL CARD / BARCODE SECTION - REMOVED AS REQUESTED
                  // _buildDigitalCardSection(),
                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.feed_outlined, color: primaryGreen),
                            SizedBox(width: 8),
                            Text(
                              'Detail Informasi',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        _buildDetailRow('Asal', _currentUser.asal),
                        _buildDetailRow('Status', _currentUser.status),
                        _buildDetailRow(
                          'Jenis Kelamin',
                          _currentUser.jenisKelamin,
                        ),
                        _buildDetailRow(
                          'Tanggal Lahir',
                          _currentUser.tanggalLahir != null
                              ? "${_currentUser.tanggalLahir!.day}/${_currentUser.tanggalLahir!.month}/${_currentUser.tanggalLahir!.year}"
                              : null,
                        ),
                        if (_currentUser.asal == 'Perantau')
                          _buildDetailRow(
                            'Asal Daerah',
                            _currentUser.asalDaerah,
                          ),
                        _buildDetailRow('No. WA', _currentUser.noWa),
                        if (_currentUser.keperluan != null &&
                            _currentUser.keperluan!.isNotEmpty)
                          _buildDetailRow('Keperluan', _currentUser.keperluan),
                        if (_currentUser.detailKeperluan != null &&
                            _currentUser.detailKeperluan!.isNotEmpty)
                          _buildDetailRow(
                            'Detail',
                            _currentUser.detailKeperluan,
                          ),
                        if (_currentUser.keterangan != null)
                          _buildDetailRow('Catatan', _currentUser.keterangan),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.logout, color: Colors.red),
                      ),
                      title: const Text(
                        'Keluar Aplikasi',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                      onTap: _logout,
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: Color(0xFF374151),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
