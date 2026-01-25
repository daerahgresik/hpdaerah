class Presensi {
  final String? id;
  final String pengajianId;
  final String userId;
  final String status; // hadir, izin, tidak_hadir
  final String? method; // qr, manual, izin, auto
  final String? approvedBy;
  final String? fotoIzin;
  final String? keterangan;
  final DateTime? createdAt;

  Presensi({
    this.id,
    required this.pengajianId,
    required this.userId,
    required this.status,
    this.method,
    this.approvedBy,
    this.fotoIzin,
    this.keterangan,
    this.createdAt,
  });

  factory Presensi.fromJson(Map<String, dynamic> json) {
    return Presensi(
      id: json['id'],
      pengajianId: json['pengajian_id'],
      userId: json['user_id'],
      status: json['status'],
      method: json['method'],
      approvedBy: json['approved_by'],
      fotoIzin: json['foto_izin'],
      keterangan: json['keterangan'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'pengajian_id': pengajianId,
      'user_id': userId,
      'status': status,
      'method': method,
      'approved_by': approvedBy,
      'foto_izin': fotoIzin,
      'keterangan': keterangan,
    };
  }
}
