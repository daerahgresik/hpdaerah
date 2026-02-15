/// Model class untuk Kelas pengajian
/// Bisa terikat ke Kelompok (level 3), Desa (level 2), atau Daerah (level 1)
class Kelas {
  final String id;
  final String?
  orgKelompokId; // Nullable: kelas daerah/desa tidak punya kelompok
  final String nama;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Kolom baru: organisasi pemilik yang fleksibel
  final String? orgId; // ID organisasi pemilik (Daerah/Desa/Kelompok)
  final int orgLevel; // 1=Daerah, 2=Desa, 3=Kelompok

  // Kolom baru: relasi parent-child (sub-kelas)
  final String? parentKelasId; // Null jika bukan sub-kelas
  final String? parentKelasName; // Nama kelas induk (untuk display)

  // Optional: nama kelompok untuk display
  final String? kelompokName;

  // Optional: jumlah anggota (dari query dengan count)
  final int? jumlahAnggota;

  // Optional: apakah punya sub-kelas
  final bool hasChildren;

  Kelas({
    required this.id,
    this.orgKelompokId,
    required this.nama,
    this.createdAt,
    this.updatedAt,
    this.orgId,
    this.orgLevel = 3,
    this.parentKelasId,
    this.parentKelasName,
    this.kelompokName,
    this.jumlahAnggota,
    this.hasChildren = false,
  });

  factory Kelas.fromJson(Map<String, dynamic> json) {
    return Kelas(
      id: json['id'] as String,
      orgKelompokId: json['org_kelompok_id'] as String?,
      nama: json['nama'] as String,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String).toLocal()
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String).toLocal()
          : null,
      orgId: json['org_id'] as String?,
      orgLevel: json['org_level'] as int? ?? 3,
      parentKelasId: json['parent_kelas_id'] as String?,
      parentKelasName: json['parent_kelas_name'] as String?,
      kelompokName: json['kelompok_name'] as String?,
      jumlahAnggota: json['jumlah_anggota'] as int?,
      hasChildren: json['has_children'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{'nama': nama, 'org_level': orgLevel};
    if (id.isNotEmpty) data['id'] = id;
    if (orgKelompokId != null) data['org_kelompok_id'] = orgKelompokId;
    if (orgId != null) data['org_id'] = orgId;
    if (parentKelasId != null) data['parent_kelas_id'] = parentKelasId;
    return data;
  }

  /// Label tingkat organisasi
  String get orgLevelLabel {
    switch (orgLevel) {
      case 1:
        return 'Daerah';
      case 2:
        return 'Desa';
      case 3:
        return 'Kelompok';
      default:
        return 'Kelompok';
    }
  }

  /// Apakah ini kelas khusus (tingkat Daerah atau Desa)
  bool get isKelasKhusus => orgLevel < 3;

  /// Apakah ini sub-kelas
  bool get isSubKelas => parentKelasId != null;

  Kelas copyWith({
    String? id,
    String? orgKelompokId,
    String? nama,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? orgId,
    int? orgLevel,
    String? parentKelasId,
    String? parentKelasName,
    String? kelompokName,
    int? jumlahAnggota,
    bool? hasChildren,
  }) {
    return Kelas(
      id: id ?? this.id,
      orgKelompokId: orgKelompokId ?? this.orgKelompokId,
      nama: nama ?? this.nama,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      orgId: orgId ?? this.orgId,
      orgLevel: orgLevel ?? this.orgLevel,
      parentKelasId: parentKelasId ?? this.parentKelasId,
      parentKelasName: parentKelasName ?? this.parentKelasName,
      kelompokName: kelompokName ?? this.kelompokName,
      jumlahAnggota: jumlahAnggota ?? this.jumlahAnggota,
      hasChildren: hasChildren ?? this.hasChildren,
    );
  }

  @override
  String toString() =>
      'Kelas(id: $id, nama: $nama, orgLevel: $orgLevel, kelompok: $orgKelompokId, parent: $parentKelasId)';
}
