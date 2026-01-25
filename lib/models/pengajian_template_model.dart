class PengajianTemplate {
  final String id;
  final String orgId;
  final String level; // daerah, desa, kelompok
  final String name; // Nama tombol
  final String defaultTitle;
  final String? defaultDescription;
  final String? defaultLocation;

  PengajianTemplate({
    required this.id,
    required this.orgId,
    required this.level,
    required this.name,
    required this.defaultTitle,
    this.defaultDescription,
    this.defaultLocation,
  });

  factory PengajianTemplate.fromJson(Map<String, dynamic> json) {
    return PengajianTemplate(
      id: json['id'] as String,
      orgId: json['org_id'] as String,
      level: _parseLevel(json['level']),
      name: json['name'] as String,
      defaultTitle: json['default_title'] as String,
      defaultDescription: json['default_description'] as String?,
      defaultLocation: json['default_location'] as String?,
    );
  }

  static String _parseLevel(dynamic level) {
    if (level is int) {
      switch (level) {
        case 0:
          return 'Daerah';
        case 1:
          return 'Desa';
        case 2:
          return 'Kelompok';
      }
    }
    return level.toString();
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'org_id': orgId,
      'level': level,
      'name': name,
      'default_title': defaultTitle,
      'default_description': defaultDescription,
      'default_location': defaultLocation,
    };
  }
}
