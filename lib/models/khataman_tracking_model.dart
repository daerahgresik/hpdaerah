/// Model untuk Khataman Assignment
/// Menyimpan target yang di-assign ke kelas atau user
class KhatamanAssignment {
  final String id;
  final String orgId;
  final String masterTargetId;
  final String? kelasId;
  final String? userId;
  final String targetType; // 'kelas' atau 'user'
  final DateTime? deadline;
  final bool isActive;
  final DateTime? createdAt;
  final String? createdBy;

  // Joined data
  final String? targetNama;
  final int? targetHalaman;
  final String? kelasNama;
  final String? userName;

  KhatamanAssignment({
    required this.id,
    required this.orgId,
    required this.masterTargetId,
    this.kelasId,
    this.userId,
    required this.targetType,
    this.deadline,
    this.isActive = true,
    this.createdAt,
    this.createdBy,
    this.targetNama,
    this.targetHalaman,
    this.kelasNama,
    this.userName,
  });

  factory KhatamanAssignment.fromJson(Map<String, dynamic> json) {
    return KhatamanAssignment(
      id: json['id'] as String,
      orgId: json['org_id'] as String,
      masterTargetId: json['master_target_id'] as String,
      kelasId: json['kelas_id'] as String?,
      userId: json['user_id'] as String?,
      targetType: json['target_type'] as String,
      deadline: json['deadline'] != null
          ? DateTime.parse(json['deadline'] as String)
          : null,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String).toLocal()
          : null,
      createdBy: json['created_by'] as String?,
      targetNama: json['target_nama'] as String?,
      targetHalaman: json['target_halaman'] as int?,
      kelasNama: json['kelas_nama'] as String?,
      userName: json['user_name'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'org_id': orgId,
      'master_target_id': masterTargetId,
      'kelas_id': kelasId,
      'user_id': userId,
      'target_type': targetType,
      'deadline': deadline?.toIso8601String().split('T').first,
      'is_active': isActive,
      'created_by': createdBy,
    };
  }
}

/// Model untuk Khataman Progress
/// Menyimpan progress baca per user
class KhatamanProgress {
  final String id;
  final String assignmentId;
  final String userId;
  final int halamanSelesai;
  final String? catatan;
  final DateTime? updatedAt;

  // Joined data
  final String? userName;
  final int? totalHalaman;

  KhatamanProgress({
    required this.id,
    required this.assignmentId,
    required this.userId,
    required this.halamanSelesai,
    this.catatan,
    this.updatedAt,
    this.userName,
    this.totalHalaman,
  });

  double get progressPercent {
    if (totalHalaman == null || totalHalaman == 0) return 0;
    return (halamanSelesai / totalHalaman!).clamp(0.0, 1.0);
  }

  bool get isKhatam => totalHalaman != null && halamanSelesai >= totalHalaman!;

  factory KhatamanProgress.fromJson(Map<String, dynamic> json) {
    return KhatamanProgress(
      id: json['id'] as String,
      assignmentId: json['assignment_id'] as String,
      userId: json['user_id'] as String,
      halamanSelesai: json['halaman_selesai'] as int? ?? 0,
      catatan: json['catatan'] as String?,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String).toLocal()
          : null,
      userName: json['user_name'] as String?,
      totalHalaman: json['total_halaman'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'assignment_id': assignmentId,
      'user_id': userId,
      'halaman_selesai': halamanSelesai,
      'catatan': catatan,
    };
  }
}
