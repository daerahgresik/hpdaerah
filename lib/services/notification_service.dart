import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hpdaerah/models/pengajian_model.dart';
import 'package:hpdaerah/models/user_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  
  final SupabaseClient _supabase = Supabase.instance.client;
  
  bool _isInitialized = false;

  // Initialize
  Future<void> init() async {
    if (_isInitialized) return;

    // Android Settings
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS Settings
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const settings =
        InitializationSettings(android: androidSettings, iOS: iosSettings);

    await _notifications.initialize(settings);
    _isInitialized = true;
  }

  // Show Notification
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'pengajian_channel', // ID channel
      'Notifikasi Pengajian', // Nama channel
      channelDescription: 'Pemberitahuan jadwal pengajian',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails();

    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _notifications.show(id, title, body, details);
  }

  // Monitor Active Pengajian
  void startMonitoring(UserModel user) {
    debugPrint("Start monitoring notifications for: ${user.nama} (${user.statusWarga})");
    
    // Listen to changes in 'pengajian' table
    _supabase
        .from('pengajian')
        .stream(primaryKey: ['id'])
        .eq('is_template', false) // Only real events
        .listen((List<Map<String, dynamic>> data) {
          _handlePengajianUpdate(data, user);
        });
  }

  void _handlePengajianUpdate(List<Map<String, dynamic>> data, UserModel user) {
    final now = DateTime.now();

    for (var item in data) {
      try {
        final p = Pengajian.fromJson(item);
        
        // 1. Check if ACTIVE (started recently, not ended)
        // Let's say active if started within last 6 hours and not ended
        // Or started in future (upcoming) within 1 hour
        final isRecent = p.startedAt.isAfter(now.subtract(const Duration(hours: 6)));
        final isUpcoming = p.startedAt.isAfter(now) && p.startedAt.isBefore(now.add(const Duration(hours: 1)));
        final isOngoing = p.startedAt.isBefore(now) && p.endedAt == null;

        if ((isRecent || isUpcoming) && (isOngoing || isUpcoming)) {
          // 2. Check TARGET MATCH
          if (_isTargetMatch(p.targetAudience, user)) {
            // 3. Trigger Notification
            // Use unique ID based on hashCode of pengajian ID to avoid duplicates
            _showNotificationForEvent(p);
          }
        }
      } catch (e) {
        debugPrint("Error parsing pengajian for notif: $e");
      }
    }
  }

  bool _isTargetMatch(String? target, UserModel user) {
    if (target == null || target.isEmpty || target.toLowerCase() == 'semua') {
      return true;
    }
    
    // Normalize logic
    // target examples: 'Muda-mudi', 'Praremaja', 'Caberawit'
    // user status examples: 'Muda-mudi', 'Praremaja', etc.
    // Need flexible matching
    final t = target.toLowerCase().replaceAll('-', '');
    final u = (user.statusWarga ?? '').toLowerCase().replaceAll('-', '');
    final k = (user.keterangan ?? '').toLowerCase();

    if (u.contains(t)) return true;
    if (k.contains(t)) return true; // check keterangan too

    return false;
  }

  Future<void> _showNotificationForEvent(Pengajian p) async {
    // Avoid spamming? local_notifications handles ID replacement.
    // We only want to notify once per event ideally.
    // Ideally we store 'notified_events' in shared_prefs.
    // For simplicity now, just show. The OS will debounce if ID is same.
    
    final id = p.id.hashCode;
    final timeStr = "${p.startedAt.hour}:${p.startedAt.minute.toString().padLeft(2, '0')}";
    
    await showNotification(
      id: id,
      title: "Pengajian Aktif: ${p.title}",
      body: "Dimulai pukul $timeStr di ${p.location ?? 'Lokasi tidak ada'}. Klik untuk hadir.",
    );
  }
}
