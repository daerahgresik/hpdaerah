import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart'; // Untuk kIsWeb

/// Single Valid Google Auth Button for All Platforms
class GoogleAuthButton extends StatefulWidget {
  final Function(GoogleSignInAccount?) onSignInSuccess;
  final bool isLoading;

  const GoogleAuthButton({
    super.key,
    required this.onSignInSuccess,
    this.isLoading = false,
  });

  @override
  State<GoogleAuthButton> createState() => _GoogleAuthButtonState();
}

class _GoogleAuthButtonState extends State<GoogleAuthButton> {
  bool _localLoading = false;

  @override
  Widget build(BuildContext context) {
    final bool isBusy = widget.isLoading || _localLoading;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: isBusy ? null : _handleSignIn,
        icon: isBusy
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.login, color: Colors.deepOrange),
        label: Text(
          isBusy ? 'Memproses...' : 'Lanjutkan dengan Google',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
            side: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
          ),
          elevation: 2,
        ),
      ),
    );
  }

  Future<void> _handleSignIn() async {
    setState(() => _localLoading = true);

    try {
      // Use singleton instance as standard in v7
      final GoogleSignIn googleSignIn = GoogleSignIn.instance;

      GoogleSignInAccount? account;

      // --- LOGIC UTAMA ---

      // Cek apakah platform mendukung authenticate() (Mobile usually true, Web false/limited)
      final bool canAuth = await googleSignIn.supportsAuthenticate();

      if (canAuth) {
        // [MOBILE / SUPPORTED]
        account = await googleSignIn.authenticate();
      } else {
        // [WEB / FALLBACK]
        // Coba login ringan (cookies lama)
        account = await googleSignIn.attemptLightweightAuthentication();

        if (account == null) {
          // Jika gagal, user harusnya pakai renderButton.
          // Tapi karena kita dipaksa 1 file, kita tidak bisa pakai renderButton (package khusus).
          // Jadi kita fallback ke pesan error informatif.
          throw 'Fitur Login Otomatis Google Web belum tersedia di mode ini. Silakan isi form manual.';
        }
      }

      if (account != null && mounted) {
        widget.onSignInSuccess(account);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _localLoading = false);
      }
    }
  }
}
