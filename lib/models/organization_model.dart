class Organization {
  final String id;
  final String name;
  final String? type;
  final String? parentId;
  final int? level;
  final String? ageCategory;

  Organization({
    required this.id,
    required this.name,
    this.type,
    this.parentId,
    this.level,
    this.ageCategory,
  });

  factory Organization.fromJson(Map<String, dynamic> json) {
    return Organization(
      id: json['id'] as String,
      name: json['name'] as String,
      type: json['type'] as String?,
      parentId: json['parent_id'] as String?,
      level: json['level'] as int?,
      ageCategory: json['age_category'] as String?,
    );
  }
}
