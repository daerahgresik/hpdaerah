/// Model untuk QR Code Pengajian
/// QR Code bersifat unik per user per pengajian dan sekali pakai
class PengajianQr {
  final String id;
  final String pengajianId;
  final String userId;
  final String qrCode;
  final bool isUsed;
  final DateTime? usedAt;
  final DateTime? createdAt;

  // Relasi opsional (untuk display)
  final String? pengajianTitle;
  final String? pengajianLocation;
  final DateTime? pengajianStartedAt;
  final DateTime? pengajianEndedAt;
  final String? pengajianDescription;
  final String? targetAudience;
  final String? presensiStatus; // hadir, izin, dll.

  PengajianQr({
    required this.id,
    required this.pengajianId,
    required this.userId,
    required this.qrCode,
    this.isUsed = false,
    this.usedAt,
    this.createdAt,
    this.pengajianTitle,
    this.pengajianLocation,
    this.pengajianStartedAt,
    this.pengajianEndedAt,
    this.pengajianDescription,
    this.targetAudience,
    this.presensiStatus,
  });

  factory PengajianQr.fromJson(Map<String, dynamic> json) {
    // Handle nested pengajian data if joined
    final pengajian = json['pengajian'] as Map<String, dynamic>?;

    return PengajianQr(
      id: json['id'] as String,
      pengajianId: json['pengajian_id'] as String,
      userId: json['user_id'] as String,
      qrCode: json['qr_code'] as String,
      isUsed: json['is_used'] as bool? ?? false,
      usedAt: json['used_at'] != null
          ? DateTime.parse(json['used_at'] as String).toLocal()
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String).toLocal()
          : null,
      // From joined pengajian table
      pengajianTitle:
          pengajian?['title'] as String? ?? json['pengajian_title'] as String?,
      pengajianLocation:
          pengajian?['location'] as String? ??
          json['pengajian_location'] as String?,
      pengajianStartedAt:
          (pengajian?['started_at'] ?? json['pengajian_started_at']) != null
          ? DateTime.parse(
              (pengajian?['started_at'] ?? json['pengajian_started_at'])
                  as String,
            ).toLocal()
          : null,
      pengajianEndedAt:
          (pengajian?['ended_at'] ?? json['pengajian_ended_at']) != null
          ? DateTime.parse(
              (pengajian?['ended_at'] ?? json['pengajian_ended_at']) as String,
            ).toLocal()
          : null,
      pengajianDescription:
          pengajian?['description'] as String? ??
          json['pengajian_description'] as String?,
      targetAudience:
          pengajian?['target_audience'] as String? ??
          json['target_audience'] as String?,
      presensiStatus: json['presensi_status'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'pengajian_id': pengajianId,
      'user_id': userId,
      'qr_code': qrCode,
      'is_used': isUsed,
      'used_at': usedAt?.toIso8601String(),
    };
  }

  /// Check if QR is still valid (not used and pengajian hasn't ended)
  bool get isValid => !isUsed;

  /// Copy with untuk update state
  PengajianQr copyWith({
    String? id,
    String? pengajianId,
    String? userId,
    String? qrCode,
    bool? isUsed,
    DateTime? usedAt,
    DateTime? createdAt,
    String? pengajianTitle,
    String? pengajianLocation,
    DateTime? pengajianStartedAt,
    DateTime? pengajianEndedAt,
    String? pengajianDescription,
    String? targetAudience,
    String? presensiStatus,
  }) {
    return PengajianQr(
      id: id ?? this.id,
      pengajianId: pengajianId ?? this.pengajianId,
      userId: userId ?? this.userId,
      qrCode: qrCode ?? this.qrCode,
      isUsed: isUsed ?? this.isUsed,
      usedAt: usedAt ?? this.usedAt,
      createdAt: createdAt ?? this.createdAt,
      pengajianTitle: pengajianTitle ?? this.pengajianTitle,
      pengajianLocation: pengajianLocation ?? this.pengajianLocation,
      pengajianStartedAt: pengajianStartedAt ?? this.pengajianStartedAt,
      pengajianEndedAt: pengajianEndedAt ?? this.pengajianEndedAt,
      pengajianDescription: pengajianDescription ?? this.pengajianDescription,
      targetAudience: targetAudience ?? this.targetAudience,
      presensiStatus: presensiStatus ?? this.presensiStatus,
    );
  }
}
