class Pengajian {
  final String id;
  final String orgId;
  final String title;
  final String? description;
  final String? location;
  final String? targetAudience;
  final String? roomCode; // New Field
  final DateTime startedAt;
  final DateTime? endedAt;
  final String? createdBy;
  final bool isTemplate;
  final String? templateName;
  final int? level; // 0=Daerah, 1=Desa, 2=Kelompok
  final String? orgDaerahId;
  final String? orgDesaId;
  final String? orgKelompokId;
  final List<String>? materiGuru;
  final String? materiIsi;
  final String? targetKriteriaId;
  final List<String>? targetKelasIds; // NEW: Target kelas spesifik
  final String? targetMode; // NEW: 'all' | 'kelas' | 'kriteria'

  Pengajian({
    required this.id,
    required this.orgId,
    required this.title,
    this.description,
    this.location,
    this.targetAudience,
    this.roomCode,
    required this.startedAt,
    this.endedAt,
    this.createdBy,
    this.isTemplate = false,
    this.templateName,
    this.level,
    this.orgDaerahId,
    this.orgDesaId,
    this.orgKelompokId,
    this.materiGuru,
    this.materiIsi,
    this.targetKriteriaId,
    this.targetKelasIds,
    this.targetMode,
  });

  factory Pengajian.fromJson(Map<String, dynamic> json) {
    return Pengajian(
      id: json['id'] as String,
      orgId: json['org_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      location: json['location'] as String?,
      targetAudience: json['target_audience'] as String?,
      roomCode: json['room_code'] as String?,
      startedAt: DateTime.parse(json['started_at'] as String).toLocal(),
      endedAt: json['ended_at'] != null
          ? DateTime.parse(json['ended_at'] as String).toLocal()
          : null,
      createdBy: json['created_by'] as String?,
      isTemplate: json['is_template'] as bool? ?? false,
      templateName: json['template_name'] as String?,
      level: json['level'] as int?,
      orgDaerahId: json['org_daerah_id'] as String?,
      orgDesaId: json['org_desa_id'] as String?,
      orgKelompokId: json['org_kelompok_id'] as String?,
      materiGuru: (json['materi_guru'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      materiIsi: json['materi_isi'] as String?,
      targetKriteriaId: json['target_kriteria_id'] as String?,
      targetKelasIds: (json['target_kelas_ids'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      targetMode: json['target_mode'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'org_id': orgId,
      'title': title,
      'description': description,
      'location': location,
      'target_audience': targetAudience,
      'room_code': roomCode,
      'started_at': startedAt.toUtc().toIso8601String(),
      'ended_at': endedAt?.toUtc().toIso8601String(),
      'created_by': createdBy,
      'is_template': isTemplate,
      'template_name': templateName,
      'level': level,
      'org_daerah_id': orgDaerahId,
      'org_desa_id': orgDesaId,
      'org_kelompok_id': orgKelompokId,
      'materi_guru': materiGuru,
      'materi_isi': materiIsi,
      'target_kriteria_id': targetKriteriaId,
      'target_kelas_ids': targetKelasIds,
      'target_mode': targetMode,
    };
  }
}
