import 'package:flutter/material.dart';
import 'package:hpdaerah/models/pengajian_model.dart';
import 'package:hpdaerah/models/user_model.dart';
import 'package:hpdaerah/services/pengajian_service.dart';
import 'package:hpdaerah/views/auth/dashboard/admin/pengajian/buatroom/pengajian_form_page.dart';
import 'package:hpdaerah/views/auth/dashboard/admin/pengajian/riwayat/rekap_pengajian_page.dart'; // Import ini
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

class RiwayatPengajian extends StatefulWidget {
  final UserModel user;
  final String orgId;

  const RiwayatPengajian({super.key, required this.user, required this.orgId});

  @override
  State<RiwayatPengajian> createState() => _RiwayatPengajianState();
}

class _RiwayatPengajianState extends State<RiwayatPengajian> {
  late DateTime _focusedDay;
  late DateTime _selectedDay;
  Map<DateTime, List<Pengajian>> _events = {};
  bool _isLoading = true;
  final _pengajianService = PengajianService();

  @override
  void initState() {
    super.initState();
    _focusedDay = DateTime.now();
    _selectedDay = DateTime.now();

    // Initialize locale for date formatting
    initializeDateFormatting('id_ID', null).then((_) {
      if (mounted) setState(() {});
    });

    // Fetch initial data
    _fetchMonthlyEvents(_focusedDay);
  }

  /// Fetch events for the month (and slightly more to cover padding days)
  Future<void> _fetchMonthlyEvents(DateTime month) async {
    setState(() => _isLoading = true);

    try {
      // Calculate start and end of month
      final startOfMonth = DateTime(
        month.year,
        month.month,
        1,
      ).subtract(const Duration(days: 7)); // Buffer
      final endOfMonth = DateTime(
        month.year,
        month.month + 1,
        0,
      ).add(const Duration(days: 7)); // Buffer

      final client = Supabase.instance.client;

      // Query: Finished rooms within date range
      // Using 'started_at' as the filter date
      final response = await client
          .from('pengajian')
          .select()
          .gte('started_at', startOfMonth.toUtc().toIso8601String())
          .lte('started_at', endOfMonth.toUtc().toIso8601String())
          .eq('is_template', false)
          .not('ended_at', 'is', null); // Must be finished

      final List<dynamic> data = response as List<dynamic>;
      final List<Pengajian> allRooms = data
          .map((json) => Pengajian.fromJson(json))
          .toList();

      // Filter based on user hierarchy/permissions
      final filteredRooms = allRooms.where((p) {
        final admin = widget.user;
        final myOrgId = admin.adminOrgId ?? widget.orgId;

        // Super admin sees all (if handled correctly upstream),
        // but strictly:
        if (admin.adminLevel == 0) return true;
        if (p.createdBy == admin.id) return true;

        if (myOrgId.isNotEmpty) {
          if (p.orgId == myOrgId ||
              p.orgDaerahId == myOrgId ||
              p.orgDesaId == myOrgId ||
              p.orgKelompokId == myOrgId) {
            return true;
          }
        }
        return false;
      }).toList();

      // Group by Date for Calendar
      final newEvents = <DateTime, List<Pengajian>>{};
      for (var room in filteredRooms) {
        // Normalize date to remove time part
        final date = DateTime(
          room.startedAt.year,
          room.startedAt.month,
          room.startedAt.day,
        );

        if (newEvents[date] == null) {
          newEvents[date] = [];
        }
        newEvents[date]!.add(room);
      }

      if (mounted) {
        setState(() {
          _events = newEvents;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching calendar events: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Pengajian> _getEventsForDay(DateTime day) {
    // Normalisasi day dari TableCalendar
    final date = DateTime(day.year, day.month, day.day);
    return _events[date] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    // Get events specifically for the selected day
    // We normalize _selectedDay just in case
    final normalizedSelected = DateTime(
      _selectedDay.year,
      _selectedDay.month,
      _selectedDay.day,
    );
    final selectedEvents = _events[normalizedSelected] ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. CALENDAR CARD
        Container(
          margin: const EdgeInsets.only(bottom: 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: TableCalendar<Pengajian>(
            locale: 'id_ID',
            firstDay: DateTime.utc(2023, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            calendarFormat: CalendarFormat.month,
            startingDayOfWeek: StartingDayOfWeek.monday,

            // Event Loader
            eventLoader: _getEventsForDay,

            // Styles
            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
              titleTextStyle: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            calendarStyle: CalendarStyle(
              // Marker (Dot) Style
              markerDecoration: const BoxDecoration(
                color: Color(0xFF1A5F2D), // Green theme
                shape: BoxShape.circle,
              ),
              markersMaxCount: 1, // Only show 1 dot per day if event exists
              // Selected Day
              selectedDecoration: const BoxDecoration(
                color: Color(0xFF1A5F2D),
                shape: BoxShape.circle,
              ),
              selectedTextStyle: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),

              // Today
              todayDecoration: BoxDecoration(
                color: const Color(0xFF1A5F2D).withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              todayTextStyle: const TextStyle(
                color: Color(0xFF1A5F2D),
                fontWeight: FontWeight.bold,
              ),
            ),

            onDaySelected: (selectedDay, focusedDay) {
              if (!isSameDay(_selectedDay, selectedDay)) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
              }
            },
            onPageChanged: (focusedDay) {
              _focusedDay = focusedDay;
              _fetchMonthlyEvents(focusedDay); // Fetch data for new month
            },
          ),
        ),

        // 2. SELECTED DAY HEADER
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatFullDate(_selectedDay),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  selectedEvents.isEmpty
                      ? "Tidak ada kegiatan"
                      : "${selectedEvents.length} Kegiatan Selesai",
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
              ],
            ),
            if (_isLoading)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),

        const SizedBox(height: 16),

        // 3. EVENT LIST
        if (selectedEvents.isEmpty)
          _buildEmptyState()
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: selectedEvents.length,
            separatorBuilder: (c, i) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final item = selectedEvents[index];
              return _buildEventCard(item);
            },
          ),

        const SizedBox(height: 48),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(Icons.event_note_rounded, size: 48, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text(
            "Tidak ada riwayat pengajian pada tanggal ini",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildEventCard(Pengajian item) {
    return InkWell(
      onTap: () => _showDetailSheet(item),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icon Box
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1A5F2D).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.check_circle_outline,
                color: Color(0xFF1A5F2D),
              ),
            ),
            const SizedBox(width: 16),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 12,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        "${_formatTime(item.startedAt)} - ${item.endedAt != null ? _formatTime(item.endedAt!) : '?'}",
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  if (item.location != null) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 12,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            item.location!,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatFullDate(DateTime dt) {
    try {
      return DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(dt);
    } catch (_) {
      return "${dt.day}/${dt.month}/${dt.year}";
    }
  }

  String _formatDateShort(DateTime dt) {
    try {
      return DateFormat('d MMMM yyyy', 'id_ID').format(dt);
    } catch (_) {
      return "${dt.day}/${dt.month}/${dt.year}";
    }
  }

  String _formatTime(DateTime dt) {
    return "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
  }

  void _showDetailSheet(Pengajian item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _buildDetailSheet(item),
    );
  }

  Widget _buildDetailSheet(Pengajian item) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A5F2D).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.mosque, color: Color(0xFF1A5F2D)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      "Informasi Lengkap Room",
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                  ],
                ),
              ),
              if (item.roomCode != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    item.roomCode!,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),

          // Scrollable Info Area
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildDetailRow(
                    Icons.calendar_today,
                    "Tanggal",
                    _formatDateShort(item.startedAt),
                  ),
                  _buildDetailRow(
                    Icons.access_time,
                    "Waktu",
                    "${_formatTime(item.startedAt)} - ${item.endedAt != null ? _formatTime(item.endedAt!) : 'Selesai'}",
                  ),
                  _buildDetailRow(
                    Icons.location_on,
                    "Lokasi",
                    item.location ?? "-",
                  ),
                  _buildDetailRow(
                    Icons.people,
                    "Target",
                    item.targetAudience ?? "Semua",
                  ),
                  if (item.description != null && item.description!.isNotEmpty)
                    _buildDetailRow(
                      Icons.description,
                      "Keterangan",
                      item.description!,
                    ),

                  // Materi Section
                  if ((item.materiGuru?.isNotEmpty ?? false) ||
                      (item.materiIsi?.isNotEmpty ?? false)) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.orange.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.menu_book,
                                size: 16,
                                color: Colors.orange,
                              ),
                              SizedBox(width: 8),
                              Text(
                                "Ringkasan Materi",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Colors.orange,
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 20),
                          if (item.materiGuru?.isNotEmpty ?? false) ...[
                            Text(
                              "Guru: ${item.materiGuru!.join(', ')}",
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 4),
                          ],
                          if (item.materiIsi?.isNotEmpty ?? false)
                            Text(
                              item.materiIsi!,
                              style: TextStyle(
                                color: Colors.grey[800],
                                fontSize: 13,
                                height: 1.4,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Actions
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => RekapPengajianPage(pengajian: item),
                  ),
                );
              },
              icon: const Icon(Icons.analytics),
              label: const Text("LIHAT REKAP KEHADIRAN"),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A5F2D),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    Navigator.pop(context);
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PengajianFormPage(
                          user: widget.user,
                          orgId: widget.orgId,
                          existing: item,
                        ),
                      ),
                    );
                    if (result == true) {
                      _fetchMonthlyEvents(_focusedDay); // Refresh
                    }
                  },
                  icon: const Icon(Icons.edit),
                  label: const Text("EDIT DETAIL"),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _confirmDelete(item),
                  icon: const Icon(Icons.delete_forever, color: Colors.red),
                  label: const Text(
                    "HAPUS",
                    style: TextStyle(color: Colors.red),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: Colors.red),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey[400]),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(color: Colors.grey[500], fontSize: 11),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(Pengajian item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 12),
            Text("Hapus Riwayat?"),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Apakah Anda sangat yakin ingin menghapus riwayat pengajian ini?",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              "Tindakan ini PERMANEN. Seluruh data rekap kehadiran, statistik, dan ringkasan materi untuk room '${item.title}' akan hilang selamanya.",
              style: TextStyle(color: Colors.red[700], fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("BATAL"),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx); // Close dialog
              Navigator.pop(context); // Close sheet
              _doDelete(item.id);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text("YA, HAPUS PERMANEN"),
          ),
        ],
      ),
    );
  }

  Future<void> _doDelete(String id) async {
    setState(() => _isLoading = true);
    try {
      await _pengajianService.deletePengajian(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Riwayat berhasil dihapus"),
            backgroundColor: Colors.green,
          ),
        );
        _fetchMonthlyEvents(_focusedDay);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Gagal menghapus: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
