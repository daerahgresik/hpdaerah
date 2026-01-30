import 'package:flutter/material.dart';
import 'package:hpdaerah/models/user_model.dart';
// import 'package:hpdaerah/views/admin/dashboard_admin.dart'; // Placeholder
// import 'package:hpdaerah/views/admin/organisasi/organisasi_list_page.dart'; // Future
// import 'package:hpdaerah/views/admin/pengajian/pengajian_form_page.dart'; // Future

class MenuItem {
  final String title;
  final IconData icon;
  final String route;
  final Color color;

  MenuItem({
    required this.title,
    required this.icon,
    required this.route,
    required this.color,
  });
}

class MenuHelper {
  static List<MenuItem> getMenus(UserModel user) {
    List<MenuItem> menus = [];

    // 1. MENU UMUM (Untuk Semua User)
    menus.addAll([
      MenuItem(
        title: 'Lihat QR',
        icon: Icons.qr_code,
        route: '/qr-view',
        color: Colors.blueAccent,
      ),
      MenuItem(
        title: 'Riwayat',
        icon: Icons.history,
        route: '/riwayat',
        color: Colors.orangeAccent,
      ),
      MenuItem(
        title: 'Izin',
        icon: Icons.assignment_late_outlined,
        route: '/izin',
        color: Colors.purpleAccent,
      ),
      MenuItem(
        title: 'Khataman',
        icon: Icons.menu_book,
        route: '/khataman',
        color: Colors.pinkAccent,
      ),
      MenuItem(
        title: 'Sodakoh',
        icon: Icons.volunteer_activism,
        route: '/sodakoh',
        color: Colors.tealAccent,
      ),
      MenuItem(
        title: 'Pengumuman',
        icon: Icons.campaign,
        route: '/pengumuman',
        color: Colors.orange,
      ),
      MenuItem(
        title: 'Materi',
        icon: Icons.library_books,
        route: '/materi',
        color: Colors.brown,
      ),
      MenuItem(
        title: 'Kalender',
        icon: Icons.calendar_month,
        route: '/kalender',
        color: Colors.redAccent,
      ),
      MenuItem(
        title: 'Galeri',
        icon: Icons.collections,
        route: '/galeri',
        color: Colors.cyan,
      ),
    ]);

    // 2. MENU ADMIN (Hanya jika is_admin == true)
    if (user.isAdmin) {
      menus.addAll([
        MenuItem(
          title: 'Organisasi',
          icon: Icons.apartment,
          route: '/admin/organisasi',
          color: Colors.teal,
        ),
        MenuItem(
          title: 'Pengajian',
          icon: Icons.event_note,
          route: '/admin/pengajian/buat',
          color: Colors.green,
        ),
        MenuItem(
          title: 'Laporan',
          icon: Icons.fact_check,
          route: '/admin/laporan-center',
          color: Colors.indigo,
        ),
        MenuItem(
          title: 'Pengguna',
          icon: Icons.people_outline,
          route: '/admin/pengguna',
          color: Colors.blueGrey,
        ),
      ]);
    }

    return menus;
  }
}
