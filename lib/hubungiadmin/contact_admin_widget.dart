import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:hpdaerah/models/user_model.dart';
import 'package:hpdaerah/controllers/register_controller.dart';

class ContactAdminWidget extends StatelessWidget {
  final String orgId;
  final String orgLevelName;
  final RegisterController controller;

  const ContactAdminWidget({
    super.key,
    required this.orgId,
    required this.orgLevelName,
    required this.controller,
  });

  // Helper to launch WhatsApp
  Future<void> _launchWhatsApp(
    BuildContext context,
    String phone,
    String name,
    String issue,
  ) async {
    // Format nomor: 08xx -> 628xx
    String formattedPhone = phone.replaceAll(RegExp(r'\D'), '');
    if (formattedPhone.startsWith('0')) {
      formattedPhone = '62${formattedPhone.substring(1)}';
    }

    final message =
        "Assalamu'alaikum, saya ingin mendaftar di aplikasi HP Daerah namun terkendala data $issue tidak ditemukan. Mohon bantuannya. Terima kasih.";
    final url = Uri.parse(
      "https://wa.me/$formattedPhone?text=${Uri.encodeComponent(message)}",
    );

    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw 'Could not launch $url';
      }
    } catch (e) {
      if (context.mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tidak dapat membuka WhatsApp')),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<UserModel>>(
      future: controller.fetchAdminsByOrgId(orgId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(8.0),
            child: SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }

        final admins = snapshot.data ?? [];
        if (admins.isEmpty) return const SizedBox.shrink();

        return Container(
          margin: const EdgeInsets.only(top: 8, bottom: 16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.amber[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.amber[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.amber, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Data $orgLevelName kosong? Hubungi admin dibawah:",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.amber[900],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...admins
                  .map(
                    (admin) => InkWell(
                      onTap: () {
                        if (admin.noWa != null && admin.noWa!.isNotEmpty) {
                          _launchWhatsApp(
                            context,
                            admin.noWa!,
                            admin.nama,
                            orgLevelName,
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Admin ini belum mencantumkan No WA',
                              ),
                            ),
                          );
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.person,
                              size: 16,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              admin.nama,
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 13,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF25D366),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                "Chat WA",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ],
          ),
        );
      },
    );
  }
}
