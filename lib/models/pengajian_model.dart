class Pengajian {
  final String id;
  final String orgId;
  final String title;
  final String? description;
  final String? location;
  final String? targetAudience;
  final DateTime startedAt;
  final DateTime? endedAt;
  final String? createdBy;
  final bool isTemplate;
  final String? templateName;
  final int? level; // 0=Daerah, 1=Desa, 2=Kelompok

  Pengajian({
    required this.id,
    required this.orgId,
    required this.title,
    this.description,
    this.location,
    this.targetAudience,
    required this.startedAt,
    this.endedAt,
    this.createdBy,
    this.isTemplate = false,
    this.templateName,
    this.level,
  });

  factory Pengajian.fromJson(Map<String, dynamic> json) {
    return Pengajian(
      id: json['id'] as String,
      orgId: json['org_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      location: json['location'] as String?,
      targetAudience: json['target_audience'] as String?,
      startedAt: DateTime.parse(json['started_at'] as String).toLocal(),
      endedAt: json['ended_at'] != null
          ? DateTime.parse(json['ended_at'] as String).toLocal()
          : null,
      createdBy: json['created_by'] as String?,
      isTemplate: json['is_template'] as bool? ?? false,
      templateName: json['template_name'] as String?,
      level: json['level'] as int?,
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
      'started_at': startedAt.toIso8601String(),
      'ended_at': endedAt?.toIso8601String(),
      'created_by': createdBy,
      'is_template': isTemplate,
      'template_name': templateName,
      'level': level,
    };
  }
}
