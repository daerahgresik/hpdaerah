class TargetKriteria {
  final String id;
  final String orgId;
  final String? orgDaerahId;
  final String? orgDesaId;
  final String? orgKelompokId;
  final String namaTarget;
  final int minUmur;
  final int maxUmur;
  final String jenisKelamin; // 'Semua', 'Pria', 'Wanita'
  final String statusWarga; // 'Semua', 'Warga Asli', 'Perantau'
  final String keperluan; // 'Semua', 'MT', 'Kuliah', 'Bekerja'
  final String statusPernikahan; // 'Semua', 'Kawin', 'Belum Kawin'
  final DateTime? createdAt;
  final String? createdBy;

  TargetKriteria({
    required this.id,
    required this.orgId,
    this.orgDaerahId,
    this.orgDesaId,
    this.orgKelompokId,
    required this.namaTarget,
    this.minUmur = 0,
    this.maxUmur = 100,
    this.jenisKelamin = 'Semua',
    this.statusWarga = 'Semua',
    this.keperluan = 'Semua',
    this.statusPernikahan = 'Semua',
    this.createdAt,
    this.createdBy,
  });

  factory TargetKriteria.fromJson(Map<String, dynamic> json) {
    return TargetKriteria(
      id: json['id'] as String,
      orgId: json['org_id'] as String,
      orgDaerahId: json['org_daerah_id'] as String?,
      orgDesaId: json['org_desa_id'] as String?,
      orgKelompokId: json['org_kelompok_id'] as String?,
      namaTarget: json['nama_target'] as String,
      minUmur: json['min_umur'] as int? ?? 0,
      maxUmur: json['max_umur'] as int? ?? 100,
      jenisKelamin: json['jenis_kelamin'] as String? ?? 'Semua',
      statusWarga: json['status_warga'] as String? ?? 'Semua',
      keperluan: json['keperluan'] as String? ?? 'Semua',
      statusPernikahan: json['status_pernikahan'] as String? ?? 'Semua',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String).toLocal()
          : null,
      createdBy: json['created_by'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    final data = {
      'org_id': orgId,
      'org_daerah_id': orgDaerahId,
      'org_desa_id': orgDesaId,
      'org_kelompok_id': orgKelompokId,
      'nama_target': namaTarget,
      'min_umur': minUmur,
      'max_umur': maxUmur,
      'jenis_kelamin': jenisKelamin,
      'status_warga': statusWarga,
      'keperluan': keperluan,
      'status_pernikahan': statusPernikahan,
      'created_by': createdBy,
    };
    if (id.isNotEmpty) data['id'] = id;
    return data;
  }
}
