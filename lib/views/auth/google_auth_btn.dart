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

    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.linux ||
            defaultTargetPlatform == TargetPlatform.macOS)) {
      if (mounted) {
        setState(() => _localLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Google Sign-In belum tersedia di Desktop.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    try {
      // v6.x uses standard constructor
      final GoogleSignIn googleSignIn = GoogleSignIn();

      // Standard Sign In flow works for both Mobile and Web (Popup) in v6.x
      // This allows us to use our Custom Button!
      final GoogleSignInAccount? account = await googleSignIn.signIn();

      if (account == null) {
        return; // User cancelled
      }

      if (mounted) {
        widget.onSignInSuccess(account);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal login Google: $e'),
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
