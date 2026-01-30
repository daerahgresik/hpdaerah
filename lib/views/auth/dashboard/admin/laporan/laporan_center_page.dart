import 'package:flutter/material.dart';
import 'package:hpdaerah/models/user_model.dart';
import 'package:hpdaerah/views/auth/dashboard/admin/laporan/incaruserbaru.dart';

class LaporanCenterPage extends StatelessWidget {
  final UserModel user;
  const LaporanCenterPage({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return IncarUserBaruPage(user: user);
  }
}
