import 'package:flutter/material.dart';
import 'package:hpdaerah/models/pengajian_model.dart';
import 'package:hpdaerah/models/user_model.dart';
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
          .gte('started_at', startOfMonth.toIso8601String())
          .lte('started_at', endOfMonth.toIso8601String())
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
    return Container(
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
                    Icon(Icons.access_time, size: 12, color: Colors.grey[600]),
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
    );
  }

  String _formatFullDate(DateTime dt) {
    try {
      return DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(dt);
    } catch (_) {
      return "${dt.day}/${dt.month}/${dt.year}";
    }
  }

  String _formatTime(DateTime dt) {
    return "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
  }
}
