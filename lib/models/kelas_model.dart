/// Model class untuk Kelas pengajian per Kelompok
class Kelas {
  final String id;
  final String orgKelompokId;
  final String nama;
  final String? deskripsi;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Optional: nama kelompok untuk display
  final String? kelompokName;

  // Optional: jumlah anggota (dari query dengan count)
  final int? jumlahAnggota;

  Kelas({
    required this.id,
    required this.orgKelompokId,
    required this.nama,
    this.deskripsi,
    this.createdAt,
    this.updatedAt,
    this.kelompokName,
    this.jumlahAnggota,
  });

  factory Kelas.fromJson(Map<String, dynamic> json) {
    return Kelas(
      id: json['id'] as String,
      orgKelompokId: json['org_kelompok_id'] as String,
      nama: json['nama'] as String,
      deskripsi: json['deskripsi'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String).toLocal()
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String).toLocal()
          : null,
      kelompokName: json['kelompok_name'] as String?,
      jumlahAnggota: json['jumlah_anggota'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{
      'org_kelompok_id': orgKelompokId,
      'nama': nama,
      'deskripsi': deskripsi,
    };
    if (id.isNotEmpty) data['id'] = id;
    return data;
  }

  Kelas copyWith({
    String? id,
    String? orgKelompokId,
    String? nama,
    String? deskripsi,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? kelompokName,
    int? jumlahAnggota,
  }) {
    return Kelas(
      id: id ?? this.id,
      orgKelompokId: orgKelompokId ?? this.orgKelompokId,
      nama: nama ?? this.nama,
      deskripsi: deskripsi ?? this.deskripsi,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      kelompokName: kelompokName ?? this.kelompokName,
      jumlahAnggota: jumlahAnggota ?? this.jumlahAnggota,
    );
  }

  @override
  String toString() => 'Kelas(id: $id, nama: $nama, kelompok: $orgKelompokId)';
}
