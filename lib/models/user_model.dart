/// Model class untuk User sesuai database schema (01_users.sql)
class UserModel {
  final String? id;
  final String username;
  final String nama;
  final String? password; // Only used during registration
  final String? asal;
  final String status;
  final String? jabatan;
  final String? keterangan;
  final String? fotoProfil;
  final String? fotoSampul;
  final bool isAdmin;
  final int? adminLevel; // 0=Super, 1=Daerah, 2=Desa, 3=Kelompok, 4=Kategori
  final String? adminOrgId; // ID organisasi yang dikelola admin ini
  final String? currentOrgId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // New Fields
  final String? statusWarga;
  final String? keperluan;
  final String? detailKeperluan;
  final String? noWa; // Nomor WhatsApp

  UserModel({
    this.id,
    required this.username,
    required this.nama,
    this.password,
    this.asal,
    this.status = 'active',
    this.jabatan,
    this.keterangan,
    this.fotoProfil,
    this.fotoSampul,
    this.isAdmin = false,
    this.adminLevel,
    this.adminOrgId,
    this.currentOrgId,
    this.createdAt,
    this.updatedAt,
    this.statusWarga,
    this.keperluan,
    this.detailKeperluan,
    this.noWa,
  });

  /// Check if user is Super Admin (can manage everything)
  bool get isSuperAdmin => isAdmin && adminLevel == 0;

  /// Get admin level name
  String get adminLevelName {
    if (!isAdmin || adminLevel == null) return 'User';
    switch (adminLevel) {
      case 0:
        return 'Super Admin';
      case 1:
        return 'Admin Daerah';
      case 2:
        return 'Admin Desa';
      case 3:
        return 'Admin Kelompok';
      case 4:
        return 'Admin Kategori';
      default:
        return 'User';
    }
  }

  /// Check if this user can assign a specific admin level
  bool canAssignLevel(int level) {
    if (!isAdmin || adminLevel == null) return false;
    // Super admin can assign any level
    if (adminLevel == 0) return level > 0;
    // Others can only assign levels below current level
    return level > adminLevel!;
  }

  /// Get list of admin levels this user can assign
  List<int> get assignableLevels {
    if (!isAdmin || adminLevel == null) return [];
    List<int> levels = [];
    int startLevel = adminLevel == 0 ? 1 : (adminLevel! + 1);
    for (int i = startLevel; i <= 4; i++) {
      levels.add(i);
    }
    return levels;
  }

  /// Create UserModel from JSON (database response)
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      username: json['username'] ?? '',
      nama: json['nama'] ?? '',
      asal: json['asal'],
      status: json['status'] ?? 'active',
      jabatan: json['jabatan'],
      keterangan: json['keterangan'],
      fotoProfil: json['foto_profil'],
      fotoSampul: json['foto_sampul'],
      isAdmin: json['is_admin'] ?? false,
      adminLevel: json['admin_level'],
      adminOrgId: json['admin_org_id'],
      currentOrgId: json['current_org_id'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
      statusWarga: json['status_warga'],
      keperluan: json['keperluan'],
      detailKeperluan: json['detail_keperluan'],
      noWa: json['no_wa'],
    );
  }

  /// Convert UserModel to JSON for database insert/update
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'username': username,
      'nama': nama,
      if (password != null) 'password': password,
      'asal': asal,
      'status': status,
      'jabatan': jabatan,
      'keterangan': keterangan,
      'foto_profil': fotoProfil,
      'foto_sampul': fotoSampul,
      'is_admin': isAdmin,
      'admin_level': adminLevel,
      'admin_org_id': adminOrgId,
      'current_org_id': currentOrgId,
      'status_warga': statusWarga,
      'keperluan': keperluan,
      'detail_keperluan': detailKeperluan,
      'no_wa': noWa,
    };
  }

  /// Create a copy with some fields changed
  UserModel copyWith({
    String? id,
    String? username,
    String? nama,
    String? password,
    String? asal,
    String? status,
    String? jabatan,
    String? keterangan,
    String? fotoProfil,
    String? fotoSampul,
    bool? isAdmin,
    int? adminLevel,
    String? adminOrgId,
    String? currentOrgId,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? statusWarga,
    String? keperluan,
    String? detailKeperluan,
    String? noWa,
  }) {
    return UserModel(
      id: id ?? this.id,
      username: username ?? this.username,
      nama: nama ?? this.nama,
      password: password ?? this.password,
      asal: asal ?? this.asal,
      status: status ?? this.status,
      jabatan: jabatan ?? this.jabatan,
      keterangan: keterangan ?? this.keterangan,
      fotoProfil: fotoProfil ?? this.fotoProfil,
      fotoSampul: fotoSampul ?? this.fotoSampul,
      isAdmin: isAdmin ?? this.isAdmin,
      adminLevel: adminLevel ?? this.adminLevel,
      adminOrgId: adminOrgId ?? this.adminOrgId,
      currentOrgId: currentOrgId ?? this.currentOrgId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      statusWarga: statusWarga ?? this.statusWarga,
      keperluan: keperluan ?? this.keperluan,
      detailKeperluan: detailKeperluan ?? this.detailKeperluan,
      noWa: noWa ?? this.noWa,
    );
  }

  @override
  String toString() {
    return 'UserModel(id: $id, username: $username, nama: $nama, isAdmin: $isAdmin, adminLevel: $adminLevel, adminOrgId: $adminOrgId)';
  }
}

/// Helper class for admin level names
class AdminLevelHelper {
  static const Map<int, String> levelNames = {
    0: 'Super Admin',
    1: 'Admin Daerah',
    2: 'Admin Desa',
    3: 'Admin Kelompok',
    4: 'Admin Kategori',
  };

  static String getName(int? level) {
    if (level == null) return 'User';
    return levelNames[level] ?? 'User';
  }

  /// Get corresponding org level for admin level
  /// Admin Level 1 (Daerah) manages Org Level 0 (Daerah)
  static int? getOrgLevelForAdmin(int adminLevel) {
    if (adminLevel == 0) return null; // Super admin manages all
    return adminLevel - 1; // Admin Daerah (1) manages level 0, etc.
  }
}
