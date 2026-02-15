import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart'; // Untuk kIsWeb

/// Official Google Logo Widget using local asset
class GoogleLogo extends StatelessWidget {
  final double size;

  const GoogleLogo({super.key, this.size = 24});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/google_logo.png',
      width: size,
      height: size,
      errorBuilder: (context, error, stackTrace) {
        // Fallback: colored G text if asset fails to load
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFF4285F4), width: 2),
          ),
          child: Center(
            child: Text(
              'G',
              style: TextStyle(
                color: const Color(0xFF4285F4),
                fontSize: size * 0.55,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      },
    );
  }
}

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
      child: ElevatedButton(
        onPressed: isBusy ? null : _handleSignIn,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black87,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
            side: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
          ),
          elevation: 2,
        ),
        child: isBusy
            ? const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Memproses...',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Lanjutkan dengan ',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Image.asset('assets/images/google_text_logo.png', height: 18),
                ],
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
