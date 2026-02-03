import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:hpdaerah/models/organization_model.dart';
import 'package:hpdaerah/models/kelas_model.dart';
import 'package:hpdaerah/controllers/register_controller.dart'; // Import Controller
import 'package:hpdaerah/services/kelas_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';

// Import User Model
import 'package:hpdaerah/hubungiadmin/contact_admin_widget.dart'; // Import New Widget

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();

  // Controllers untuk semua field sesuai database
  final _namaController = TextEditingController();
  final _usernameController = TextEditingController();
  final _asalController = TextEditingController();

  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  // _selectedFotoProfil removed as it is replaced by _imageFile logic
  String? _selectedStatus; // Status: Warga Asli / Perantau
  String? _selectedDaerah; // Level 0
  String? _selectedDesa; // Level 1
  String? _selectedKelompok; // Level 2
  String? _selectedKelas; // Level 3

  File? _imageFile; // File gambar yang dipilih (Non-Web)
  Uint8List? _webImageBytes; // Bytes gambar untuk Web
  XFile? _selectedXFile; // XFile untuk kedua platform

  String? _selectedKeperluan; // Keperluan Perantau

  final _detailKeperluanController = TextEditingController();
  final _noWaController = TextEditingController();

  String? _selectedJenisKelamin;
  String? _selectedMarriageStatus;
  DateTime? _selectedTanggalLahir;

  final List<String> _genderOptions = ['Pria', 'Wanita'];
  final List<String> _marriageStatusOptions = ['Kawin', 'Belum Kawin'];

  // Daftar status
  final List<String> _statusOptions = ['Warga Asli', 'Perantau'];
  final List<String> _keperluanOptions = ['MT', 'Kuliah', 'Bekerja'];

  final RegisterController _registerController =
      RegisterController(); // Use Controller
  final KelasService _kelasService = KelasService();

  // Dynamic Datasets
  List<Organization> _daerahList = [];
  List<Organization> _desaList = [];
  List<Organization> _kelompokList = [];
  List<Kelas> _kelasList = []; // Changed to Kelas model

  bool _isLoadingHierarchy = false;

  @override
  void initState() {
    super.initState();
    _loadDaerah();
  }

  Future<void> _loadDaerah() async {
    setState(() => _isLoadingHierarchy = true);
    try {
      // Use Controller
      final list = await _registerController.fetchDaerah();
      setState(() {
        _daerahList = list;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal memuat daerah: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoadingHierarchy = false);
    }
  }

  Future<void> _loadChildren(String parentId, int level) async {
    setState(() => _isLoadingHierarchy = true);
    try {
      // Use Controller
      final list = await _registerController.fetchChildren(parentId);
      setState(() {
        if (level == 0) {
          _desaList = list;
        } else if (level == 1) {
          _kelompokList = list;
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal memuat data: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoadingHierarchy = false);
    }
  }

  // Load kelas from the new kelas table
  Future<void> _loadKelas(String kelompokId) async {
    setState(() => _isLoadingHierarchy = true);
    try {
      final list = await _kelasService.fetchKelasByKelompok(kelompokId);
      setState(() {
        _kelasList = list;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal memuat kelas: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoadingHierarchy = false);
    }
  }

  @override
  void dispose() {
    _namaController.dispose();
    _usernameController.dispose();
    _asalController.dispose();
    _detailKeperluanController.dispose();
    _noWaController.dispose(); // Dispose noWa

    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // --- HELPER PICK IMAGE ---
  Future<void> _pickImage() async {
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
              _processImage(ImageSource.camera);
            },
          ),
          ListTile(
            leading: const Icon(Icons.photo_library),
            title: const Text('Pilih dari Galeri'),
            onTap: () async {
              Navigator.pop(ctx);
              _processImage(ImageSource.gallery);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _processImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: source,
      imageQuality: 70,
      maxWidth: 800,
    );

    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      setState(() {
        _selectedXFile = pickedFile;
        _webImageBytes = bytes;
        if (!kIsWeb) {
          _imageFile = File(pickedFile.path);
        }
      });
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedTanggalLahir ?? DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      initialDatePickerMode: DatePickerMode.year,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF1A5F2D),
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedTanggalLahir) {
      setState(() {
        _selectedTanggalLahir = picked;
      });
    }
  }

  void _register() async {
    // 1. Ambil list field yang kosong untuk divalidasi secara cerdas
    List<String> missingFields = [];

    if (_selectedXFile == null) missingFields.add('Foto Profil');
    if (_namaController.text.trim().isEmpty) missingFields.add('Nama Lengkap');
    if (_noWaController.text.trim().isEmpty) missingFields.add('No. WhatsApp');
    if (_usernameController.text.trim().isEmpty) missingFields.add('Username');
    if (_passwordController.text.isEmpty) missingFields.add('Password');
    if (_confirmPasswordController.text.isEmpty) {
      missingFields.add('Konfirmasi Password');
    }
    if (_selectedStatus == null) missingFields.add('Status (Asli/Perantau)');

    if (_selectedStatus == 'Perantau') {
      if (_asalController.text.trim().isEmpty) missingFields.add('Asal Daerah');
      if (_selectedKeperluan == null) missingFields.add('Keperluan');
      if ((_selectedKeperluan == 'Kuliah' || _selectedKeperluan == 'Bekerja') &&
          _detailKeperluanController.text.trim().isEmpty) {
        missingFields.add('Detail Tempat (Kuliah/Kerja)');
      }
    }

    if (_selectedDaerah == null) missingFields.add('Pilihan Daerah');
    if (_selectedDesa == null) missingFields.add('Pilihan Desa');
    if (_selectedKelompok == null) missingFields.add('Pilihan Kelompok');
    if (_selectedKelas == null) missingFields.add('Kelas Pengajian');

    // 2. Jika ada yang kosong, hentikan dan beri tahu user
    if (missingFields.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Mohon lengkapi data berikut:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(missingFields.map((f) => '• $f').join('\n')),
            ],
          ),
          backgroundColor: Colors.orange[800],
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    // 3. Validasi form dasar (seperti panjang password, dll)
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        await _registerController.registerUser(
          nama: _namaController.text.trim(),
          username: _usernameController.text.trim(),
          password: _passwordController.text,
          asal: _selectedStatus,
          status: _selectedMarriageStatus,
          jenisKelamin: _selectedJenisKelamin,
          tanggalLahir: _selectedTanggalLahir,
          asalDaerah: _asalController.text.trim().isEmpty
              ? null
              : _asalController.text.trim(),
          keperluan: _selectedKeperluan,
          detailKeperluan: _detailKeperluanController.text.trim().isEmpty
              ? null
              : _detailKeperluanController.text.trim(),
          selectedDaerah: _selectedDaerah,
          selectedDesa: _selectedDesa,
          selectedKelompok: _selectedKelompok,
          selectedKelas: _selectedKelas,
          fotoProfilFile: _selectedXFile,
          noWa: _noWaController.text.trim(),
        );

        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Registrasi berhasil! Silakan login.'),
              backgroundColor: const Color(0xFF1A5F2D),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Terjadi kesalahan: $e'),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      }
    }
  }

  InputDecoration _inputDecoration(
    String label,
    IconData icon, {
    bool isOptional = false,
  }) {
    return InputDecoration(
      labelText: isOptional ? '$label (Opsional)' : label,
      labelStyle: TextStyle(
        color: Colors.white.withValues(alpha: 0.8),
        fontSize: 14,
      ),
      prefixIcon: Icon(
        icon,
        color: Colors.white.withValues(alpha: 0.7),
        size: 22,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.white, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.redAccent, width: 2),
      ),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.05),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      errorStyle: const TextStyle(fontSize: 11),
    );
  }

  Widget _buildSectionTitle(String emoji, String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 10),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient
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

          // Decorative Circles
          Positioned(
            top: -80,
            left: -80,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.lime.withValues(alpha: 0.1),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -120,
            right: -60,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.teal.withValues(alpha: 0.15),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Main Content
          SafeArea(
            child: Column(
              children: [
                // Fixed Header
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
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
                            size: 18,
                          ),
                        ),
                      ),
                      const Expanded(
                        child: Text(
                          'Daftar Akun Baru',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),

                // Scrollable Form
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        // Register Form Card
                        ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.2),
                                ),
                              ),
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // ===== SECTION: FOTO PROFIL =====
                                    _buildSectionTitle('📷', 'Foto Profil'),
                                    Center(
                                      child: GestureDetector(
                                        onTap: _pickImage,
                                        child: Container(
                                          width: 100,
                                          height: 100,
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(
                                              alpha: 0.1,
                                            ),
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: Colors.white.withValues(
                                                alpha: 0.3,
                                              ),
                                              width: 2,
                                            ),
                                          ),
                                          child:
                                              (_webImageBytes != null ||
                                                  _imageFile != null)
                                              ? ClipOval(
                                                  child: kIsWeb
                                                      ? Image.memory(
                                                          _webImageBytes!,
                                                          fit: BoxFit.cover,
                                                        )
                                                      : Image.file(
                                                          _imageFile!,
                                                          fit: BoxFit.cover,
                                                        ),
                                                )
                                              : Column(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Icon(
                                                      Icons.camera_alt_outlined,
                                                      color: Colors.white
                                                          .withValues(
                                                            alpha: 0.7,
                                                          ),
                                                      size: 32,
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      'Tambah',
                                                      style: TextStyle(
                                                        color: Colors.white
                                                            .withValues(
                                                              alpha: 0.6,
                                                            ),
                                                        fontSize: 11,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),

                                    // ===== SECTION: DATA PRIBADI & AKUN =====
                                    _buildSectionTitle(
                                      '👤',
                                      'Data Pribadi & Akun',
                                    ),

                                    // Nama Lengkap (WAJIB)
                                    TextFormField(
                                      controller: _namaController,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                      ),
                                      textCapitalization:
                                          TextCapitalization.words,
                                      decoration: _inputDecoration(
                                        'Nama Lengkap',
                                        Icons.person_outline,
                                      ),
                                      validator: (value) {
                                        if (value == null ||
                                            value.trim().isEmpty) {
                                          return 'Nama tidak boleh kosong';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 12),

                                    // Nomor WhatsApp (WAJIB)
                                    TextFormField(
                                      controller: _noWaController,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                      ),
                                      keyboardType: TextInputType.phone,
                                      decoration: _inputDecoration(
                                        'No. WhatsApp (Aktif)',
                                        Icons.phone_android,
                                      ),
                                      validator: (value) {
                                        if (value == null ||
                                            value.trim().isEmpty) {
                                          return 'No WA wajib diisi';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 12),

                                    // Username (WAJIB)
                                    TextFormField(
                                      controller: _usernameController,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                      ),
                                      decoration: _inputDecoration(
                                        'Username',
                                        Icons.alternate_email,
                                      ),
                                      validator: (value) {
                                        if (value == null ||
                                            value.trim().isEmpty) {
                                          return 'Username tidak boleh kosong';
                                        }
                                        if (value.contains(' ')) {
                                          return 'Username tidak boleh ada spasi';
                                        }
                                        if (value.length < 3) {
                                          return 'Username minimal 3 karakter';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 12),

                                    // Password (WAJIB)
                                    TextFormField(
                                      controller: _passwordController,
                                      obscureText: _obscurePassword,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                      ),
                                      decoration:
                                          _inputDecoration(
                                            'Password',
                                            Icons.lock_outline,
                                          ).copyWith(
                                            suffixIcon: IconButton(
                                              icon: Icon(
                                                _obscurePassword
                                                    ? Icons.visibility_off
                                                    : Icons.visibility,
                                                color: Colors.white.withValues(
                                                  alpha: 0.7,
                                                ),
                                                size: 22,
                                              ),
                                              onPressed: () => setState(
                                                () => _obscurePassword =
                                                    !_obscurePassword,
                                              ),
                                            ),
                                          ),
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Password tidak boleh kosong';
                                        }
                                        if (value.length < 6) {
                                          return 'Password minimal 6 karakter';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 12),

                                    // Confirm Password (WAJIB)
                                    TextFormField(
                                      controller: _confirmPasswordController,
                                      obscureText: _obscureConfirmPassword,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                      ),
                                      decoration:
                                          _inputDecoration(
                                            'Konfirmasi Password',
                                            Icons.lock_outline,
                                          ).copyWith(
                                            suffixIcon: IconButton(
                                              icon: Icon(
                                                _obscureConfirmPassword
                                                    ? Icons.visibility_off
                                                    : Icons.visibility,
                                                color: Colors.white.withValues(
                                                  alpha: 0.7,
                                                ),
                                                size: 22,
                                              ),
                                              onPressed: () => setState(
                                                () => _obscureConfirmPassword =
                                                    !_obscureConfirmPassword,
                                              ),
                                            ),
                                          ),
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Konfirmasi password tidak boleh kosong';
                                        }
                                        if (value != _passwordController.text) {
                                          return 'Password tidak cocok';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 12),

                                    // Status (WAJIB) - Warga Asli / Perantau
                                    DropdownButtonFormField<String>(
                                      value: _selectedStatus,
                                      dropdownColor: const Color(0xFF1A5F2D),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                      ),
                                      decoration: _inputDecoration(
                                        'Asal',
                                        Icons.how_to_reg_outlined,
                                      ),
                                      items: _statusOptions.map((status) {
                                        return DropdownMenuItem(
                                          value: status,
                                          child: Text(status),
                                        );
                                      }).toList(),
                                      onChanged: (value) {
                                        setState(() => _selectedStatus = value);
                                      },
                                      validator: (value) {
                                        if (value == null) {
                                          return 'Pilih status Anda';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 12),

                                    // Logic Khusus Perantau
                                    if (_selectedStatus == 'Perantau') ...[
                                      // Asal (WAJIB jika Perantau)
                                      TextFormField(
                                        controller: _asalController,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                        ),
                                        decoration: InputDecoration(
                                          labelText:
                                              'Asal (isi jika perantau, contoh: Banda Aceh)',
                                          labelStyle: TextStyle(
                                            color: Colors.white.withValues(
                                              alpha: 0.8,
                                            ),
                                            fontSize: 13,
                                          ),
                                          prefixIcon: Icon(
                                            Icons.flight_land_outlined,
                                            color: Colors.white.withValues(
                                              alpha: 0.7,
                                            ),
                                            size: 22,
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                            borderSide: BorderSide(
                                              color: Colors.white.withValues(
                                                alpha: 0.3,
                                              ),
                                            ),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                            borderSide: const BorderSide(
                                              color: Colors.white,
                                              width: 2,
                                            ),
                                          ),
                                          errorBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                            borderSide: const BorderSide(
                                              color: Colors.redAccent,
                                            ),
                                          ),
                                          focusedErrorBorder:
                                              OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                                borderSide: const BorderSide(
                                                  color: Colors.redAccent,
                                                  width: 2,
                                                ),
                                              ),
                                          filled: true,
                                          fillColor: Colors.white.withValues(
                                            alpha: 0.05,
                                          ),
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 16,
                                                vertical: 14,
                                              ),
                                        ),
                                        validator: (value) {
                                          if (_selectedStatus == 'Perantau' &&
                                              (value == null ||
                                                  value.isEmpty)) {
                                            return 'Asal tidak boleh kosong';
                                          }
                                          return null;
                                        },
                                      ),
                                      const SizedBox(height: 12),

                                      // Keperluan (MT/Kuliah/Bekerja)
                                      DropdownButtonFormField<String>(
                                        value: _selectedKeperluan,
                                        dropdownColor: const Color(0xFF1A5F2D),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                        ),
                                        decoration: _inputDecoration(
                                          'Keperluan',
                                          Icons.work_outline,
                                        ),
                                        items: _keperluanOptions.map((kep) {
                                          return DropdownMenuItem(
                                            value: kep,
                                            child: Text(kep),
                                          );
                                        }).toList(),
                                        onChanged: (value) {
                                          setState(
                                            () => _selectedKeperluan = value,
                                          );
                                        },
                                        validator: (value) {
                                          if (_selectedStatus == 'Perantau' &&
                                              value == null) {
                                            return 'Pilih keperluan';
                                          }
                                          return null;
                                        },
                                      ),
                                      const SizedBox(height: 12),

                                      // Detail Keperluan (Jika Kuliah/Bekerja)
                                      if (_selectedKeperluan == 'Kuliah' ||
                                          _selectedKeperluan == 'Bekerja') ...[
                                        TextFormField(
                                          controller:
                                              _detailKeperluanController,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                          ),
                                          decoration: _inputDecoration(
                                            _selectedKeperluan == 'Kuliah'
                                                ? 'Kuliah di mana?'
                                                : 'Bekerja di mana?',
                                            Icons.location_on_outlined,
                                          ),
                                          validator: (value) {
                                            if ((_selectedKeperluan ==
                                                        'Kuliah' ||
                                                    _selectedKeperluan ==
                                                        'Bekerja') &&
                                                (value == null ||
                                                    value.isEmpty)) {
                                              return 'Harap isi keterangan tempat';
                                            }
                                            return null;
                                          },
                                        ),
                                        const SizedBox(height: 12),
                                      ],
                                    ],

                                    // STATUS (Kawin / Belum Kawin)
                                    DropdownButtonFormField<String>(
                                      value: _selectedMarriageStatus,
                                      dropdownColor: const Color(0xFF1A5F2D),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                      ),
                                      decoration: _inputDecoration(
                                        'Status',
                                        Icons.favorite_border,
                                      ),
                                      items: _marriageStatusOptions.map((
                                        status,
                                      ) {
                                        return DropdownMenuItem(
                                          value: status,
                                          child: Text(status),
                                        );
                                      }).toList(),
                                      onChanged: (value) {
                                        setState(
                                          () => _selectedMarriageStatus = value,
                                        );
                                      },
                                      validator: (value) {
                                        if (value == null) {
                                          return 'Pilih status pernikahan';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 12),

                                    // JENIS KELAMIN
                                    DropdownButtonFormField<String>(
                                      value: _selectedJenisKelamin,
                                      dropdownColor: const Color(0xFF1A5F2D),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                      ),
                                      decoration: _inputDecoration(
                                        'Jenis Kelamin',
                                        Icons.person_outline,
                                      ),
                                      items: _genderOptions.map((gender) {
                                        return DropdownMenuItem(
                                          value: gender,
                                          child: Text(gender),
                                        );
                                      }).toList(),
                                      onChanged: (value) {
                                        setState(
                                          () => _selectedJenisKelamin = value,
                                        );
                                      },
                                      validator: (value) {
                                        if (value == null) {
                                          return 'Pilih jenis kelamin';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 12),

                                    // TANGGAL LAHIR
                                    GestureDetector(
                                      onTap: () => _selectDate(context),
                                      child: AbsorbPointer(
                                        child: TextFormField(
                                          key: ValueKey(_selectedTanggalLahir),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                          ),
                                          decoration: _inputDecoration(
                                            _selectedTanggalLahir == null
                                                ? 'Pilih Tanggal Lahir'
                                                : 'Tanggal Lahir: ${_selectedTanggalLahir!.day}/${_selectedTanggalLahir!.month}/${_selectedTanggalLahir!.year}',
                                            Icons.calendar_today_outlined,
                                          ),
                                          validator: (value) {
                                            if (_selectedTanggalLahir == null) {
                                              return 'Tanggal lahir wajib diisi';
                                            }
                                            return null;
                                          },
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 12),

                                    // 1. Daerah (Level 0)
                                    DropdownButtonFormField<String>(
                                      value: _selectedDaerah,
                                      dropdownColor: const Color(0xFF1A5F2D),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                      ),
                                      decoration: _inputDecoration(
                                        'Daerah',
                                        Icons.map_outlined,
                                      ),
                                      items:
                                          _isLoadingHierarchy &&
                                              _daerahList.isEmpty
                                          ? []
                                          : _daerahList.map((e) {
                                              return DropdownMenuItem(
                                                value: e.id,
                                                child: Text(e.name),
                                              );
                                            }).toList(),
                                      onChanged: (val) {
                                        setState(() {
                                          _selectedDaerah = val;
                                          _selectedDesa = null;
                                          _selectedKelompok = null;
                                          _selectedKelas = null;
                                          _desaList.clear();
                                          _kelompokList.clear();
                                          _kelasList.clear();
                                        });
                                        if (val != null) _loadChildren(val, 0);
                                      },
                                      validator: (val) =>
                                          val == null ? 'Pilih daerah' : null,
                                    ),
                                    const SizedBox(height: 12),

                                    // 2. Desa (Level 1)
                                    DropdownButtonFormField<String>(
                                      value: _selectedDesa,
                                      dropdownColor: const Color(0xFF1A5F2D),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                      ),
                                      decoration: _inputDecoration(
                                        'Desa',
                                        Icons.holiday_village_outlined,
                                      ),
                                      items: _desaList.map((e) {
                                        return DropdownMenuItem(
                                          value: e.id,
                                          child: Text(e.name),
                                        );
                                      }).toList(),
                                      onChanged: _selectedDaerah == null
                                          ? null
                                          : (val) {
                                              setState(() {
                                                _selectedDesa = val;
                                                _selectedKelompok = null;
                                                _selectedKelas = null;
                                                _kelompokList.clear();
                                                _kelasList.clear();
                                              });
                                              if (val != null) {
                                                _loadChildren(val, 1);
                                              }
                                            },
                                      validator: (val) =>
                                          val == null ? 'Pilih desa' : null,
                                    ),
                                    const SizedBox(height: 12),

                                    // Tampilkan Kontak Admin Daerah jika Desk List Kosong (tapi Daerah terpilih)
                                    if (_selectedDaerah != null &&
                                        _desaList.isEmpty &&
                                        !_isLoadingHierarchy)
                                      ContactAdminWidget(
                                        orgId: _selectedDaerah!,
                                        orgLevelName: 'desa',
                                        controller: _registerController,
                                      ),

                                    // 3. Kelompok (Level 2)
                                    DropdownButtonFormField<String>(
                                      value: _selectedKelompok,
                                      dropdownColor: const Color(0xFF1A5F2D),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                      ),
                                      decoration: _inputDecoration(
                                        'Kelompok',
                                        Icons.groups_outlined,
                                      ),
                                      items: _kelompokList.map((e) {
                                        return DropdownMenuItem(
                                          value: e.id,
                                          child: Text(e.name),
                                        );
                                      }).toList(),
                                      onChanged: _selectedDesa == null
                                          ? null
                                          : (val) {
                                              setState(() {
                                                _selectedKelompok = val;
                                                _selectedKelas = null;
                                                _kelasList.clear();
                                              });
                                              if (val != null) {
                                                _loadKelas(
                                                  val,
                                                ); // Load from kelas table
                                              }
                                            },
                                      validator: (val) =>
                                          val == null ? 'Pilih kelompok' : null,
                                    ),
                                    const SizedBox(height: 12),

                                    // Tampilkan Kontak Admin Desa jika Kelompok List Kosong (tapi Desa terpilih)
                                    if (_selectedDesa != null &&
                                        _kelompokList.isEmpty &&
                                        !_isLoadingHierarchy)
                                      ContactAdminWidget(
                                        orgId: _selectedDesa!,
                                        orgLevelName: 'kelompok',
                                        controller: _registerController,
                                      ),

                                    // 4. Kelas / Kategori (Level 3)
                                    DropdownButtonFormField<String>(
                                      value: _selectedKelas,
                                      dropdownColor: const Color(0xFF1A5F2D),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                      ),
                                      decoration: _inputDecoration(
                                        'Kelas Pengajian',
                                        Icons.school_outlined,
                                      ),
                                      items: _kelasList.map((e) {
                                        return DropdownMenuItem(
                                          value: e.id,
                                          child: Text(
                                            e.nama,
                                          ), // Changed from e.name
                                        );
                                      }).toList(),
                                      onChanged: _selectedKelompok == null
                                          ? null
                                          : (val) => setState(() {
                                              _selectedKelas = val;
                                            }),
                                      validator: (val) =>
                                          val == null ? 'Pilih kelas' : null,
                                    ),
                                    const SizedBox(height: 12),

                                    const SizedBox(height: 12),

                                    const SizedBox(height: 12),

                                    const SizedBox(height: 24),

                                    // Register Button
                                    SizedBox(
                                      width: double.infinity,
                                      height: 52,
                                      child: ElevatedButton(
                                        onPressed: _isLoading
                                            ? null
                                            : _register,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.white,
                                          foregroundColor: const Color(
                                            0xFF1A5F2D,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                          ),
                                          elevation: 0,
                                        ),
                                        child: _isLoading
                                            ? const SizedBox(
                                                width: 24,
                                                height: 24,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2.5,
                                                      color: Color(0xFF1A5F2D),
                                                    ),
                                              )
                                            : const Text(
                                                'Daftar Sekarang',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Login Link
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Sudah punya akun? ',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                              ),
                            ),
                            GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: const Text(
                                'Masuk',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
