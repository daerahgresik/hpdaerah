import 'package:hpdaerah/models/kelas_model.dart';

/// Model untuk breakdown kelas per kelompok
class KelasBreakdown {
  final String kelasId;
  final String kelasName;
  final String kelompokId;
  final String kelompokName;
  final String? desaId;
  final String? desaName;
  final int memberCount;

  KelasBreakdown({
    required this.kelasId,
    required this.kelasName,
    required this.kelompokId,
    required this.kelompokName,
    this.desaId,
    this.desaName,
    required this.memberCount,
  });

  factory KelasBreakdown.fromJson(Map<String, dynamic> json) {
    return KelasBreakdown(
      kelasId: json['kelas_id'] as String,
      kelasName: json['kelas_name'] as String,
      kelompokId: json['kelompok_id'] as String,
      kelompokName: json['kelompok_name'] as String,
      desaId: json['desa_id'] as String?,
      desaName: json['desa_name'] as String?,
      memberCount: json['member_count'] as int? ?? 0,
    );
  }

  /// Create from Kelas model with additional info
  factory KelasBreakdown.fromKelas(
    Kelas kelas, {
    required String kelompokName,
    String? desaId,
    String? desaName,
    required int memberCount,
  }) {
    return KelasBreakdown(
      kelasId: kelas.id,
      kelasName: kelas.nama,
      kelompokId: kelas.orgKelompokId,
      kelompokName: kelompokName,
      desaId: desaId,
      desaName: desaName,
      memberCount: memberCount,
    );
  }
}

/// Model untuk kelas yang diagregasi dari berbagai kelompok
class AggregatedKelas {
  final String normalizedName;
  final String displayName;
  final int totalMembers;
  final List<KelasBreakdown> breakdown;
  final bool hasSubClasses;
  final List<AggregatedKelas>? subClasses;

  AggregatedKelas({
    required this.normalizedName,
    required this.displayName,
    required this.totalMembers,
    required this.breakdown,
    this.hasSubClasses = false,
    this.subClasses,
  });

  /// Jumlah kelompok yang memiliki kelas dengan nama ini
  int get kelompokCount => breakdown.length;

  /// Cek apakah ini adalah agregasi dari multiple kelompok
  bool get isAggregated => breakdown.length > 1;

  /// Get unique desa names from breakdown
  List<String> get uniqueDesaNames {
    final names = breakdown
        .where((b) => b.desaName != null)
        .map((b) => b.desaName!)
        .toSet()
        .toList();
    names.sort();
    return names;
  }

  /// Get breakdown grouped by desa
  Map<String, List<KelasBreakdown>> get breakdownByDesa {
    final map = <String, List<KelasBreakdown>>{};
    for (final b in breakdown) {
      final key = b.desaName ?? 'Tanpa Desa';
      map.putIfAbsent(key, () => []).add(b);
    }
    return map;
  }
}

/// Helper class untuk normalisasi nama kelas
class ClassNameHelper {
  /// Normalisasi nama kelas untuk perbandingan toleran
  /// "Muda-Mudi", "muda mudi", "MUDA_MUDI" -> "muda mudi"
  static String normalize(String name) {
    return name
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[-_]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  /// Cek apakah dua nama kelas mirip
  static bool isSimilar(String name1, String name2) {
    return normalize(name1) == normalize(name2);
  }

  /// Hitung similarity score (0.0 - 1.0)
  static double similarityScore(String name1, String name2) {
    final n1 = normalize(name1);
    final n2 = normalize(name2);

    if (n1 == n2) return 1.0;
    if (n1.isEmpty || n2.isEmpty) return 0.0;

    // Simple contains check
    if (n1.contains(n2) || n2.contains(n1)) {
      final shorter = n1.length < n2.length ? n1 : n2;
      final longer = n1.length < n2.length ? n2 : n1;
      return shorter.length / longer.length;
    }

    return 0.0;
  }

  /// Cek apakah name2 adalah sub-kelas dari name1
  /// Contoh: "Muda-Mudi Putra" adalah sub-kelas dari "Muda-Mudi"
  static bool isSubClass(String parentName, String childName) {
    final p = normalize(parentName);
    final c = normalize(childName);

    if (c.length <= p.length) return false;
    return c.startsWith(p);
  }

  /// Get display name dari list nama (ambil yang paling umum)
  static String getDisplayName(List<String> names) {
    if (names.isEmpty) return '';
    if (names.length == 1) return names.first;

    // Hitung frequency
    final freq = <String, int>{};
    for (final name in names) {
      freq[name] = (freq[name] ?? 0) + 1;
    }

    // Return yang paling sering muncul
    final sorted = freq.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.first.key;
  }

  /// Natural sort compare - untuk urutan yang benar
  /// "Desa 1", "Desa 2", "Desa 10" (bukan "Desa 1", "Desa 10", "Desa 2")
  static int naturalCompare(String a, String b) {
    final regExp = RegExp(r'(\d+)|(\D+)');
    final partsA = regExp.allMatches(a).map((m) => m.group(0)!).toList();
    final partsB = regExp.allMatches(b).map((m) => m.group(0)!).toList();

    for (int i = 0; i < partsA.length && i < partsB.length; i++) {
      final partA = partsA[i];
      final partB = partsB[i];

      final numA = int.tryParse(partA);
      final numB = int.tryParse(partB);

      int result;
      if (numA != null && numB != null) {
        // Both are numbers - compare numerically
        result = numA.compareTo(numB);
      } else {
        // At least one is text - compare alphabetically (case insensitive)
        result = partA.toLowerCase().compareTo(partB.toLowerCase());
      }

      if (result != 0) return result;
    }

    return partsA.length.compareTo(partsB.length);
  }

  /// Sort list of maps by 'name' field using natural sort
  static List<Map<String, dynamic>> sortByNameNatural(
    List<Map<String, dynamic>> items,
  ) {
    final sorted = List<Map<String, dynamic>>.from(items);
    sorted.sort(
      (a, b) => naturalCompare(
        a['name'] as String? ?? '',
        b['name'] as String? ?? '',
      ),
    );
    return sorted;
  }
}

/// Model untuk statistik hierarki
class HierarchyStats {
  final int desaCount;
  final int kelompokCount;
  final int uniqueClassCount;
  final int totalMembers;
  final int unassignedCount;

  HierarchyStats({
    required this.desaCount,
    required this.kelompokCount,
    required this.uniqueClassCount,
    required this.totalMembers,
    required this.unassignedCount,
  });

  factory HierarchyStats.empty() {
    return HierarchyStats(
      desaCount: 0,
      kelompokCount: 0,
      uniqueClassCount: 0,
      totalMembers: 0,
      unassignedCount: 0,
    );
  }
}
