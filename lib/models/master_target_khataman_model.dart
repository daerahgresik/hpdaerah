/// Model untuk Master Target Khataman
/// Menyimpan daftar target bacaan seperti Al-Quran, Hadis, dll
class MasterTargetKhataman {
  final String id;
  final String orgId;
  final String nama;
  final int jumlahHalaman;
  final String? keterangan;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? createdBy;

  MasterTargetKhataman({
    required this.id,
    required this.orgId,
    required this.nama,
    required this.jumlahHalaman,
    this.keterangan,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
    this.createdBy,
  });

  factory MasterTargetKhataman.fromJson(Map<String, dynamic> json) {
    return MasterTargetKhataman(
      id: json['id'] as String,
      orgId: json['org_id'] as String,
      nama: json['nama'] as String,
      jumlahHalaman: json['jumlah_halaman'] as int? ?? 0,
      keterangan: json['keterangan'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String).toLocal()
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String).toLocal()
          : null,
      createdBy: json['created_by'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{
      'org_id': orgId,
      'nama': nama,
      'jumlah_halaman': jumlahHalaman,
      'keterangan': keterangan,
      'is_active': isActive,
      'created_by': createdBy,
    };
    if (id.isNotEmpty) data['id'] = id;
    return data;
  }

  MasterTargetKhataman copyWith({
    String? id,
    String? orgId,
    String? nama,
    int? jumlahHalaman,
    String? keterangan,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
  }) {
    return MasterTargetKhataman(
      id: id ?? this.id,
      orgId: orgId ?? this.orgId,
      nama: nama ?? this.nama,
      jumlahHalaman: jumlahHalaman ?? this.jumlahHalaman,
      keterangan: keterangan ?? this.keterangan,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }

  @override
  String toString() =>
      'MasterTargetKhataman(id: $id, nama: $nama, halaman: $jumlahHalaman)';
}
