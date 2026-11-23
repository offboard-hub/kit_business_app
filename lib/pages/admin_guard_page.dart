import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../services/api.dart';
import '../widgets/app_header.dart';
import '../widgets/site_assistant_chat.dart';
import 'admin_videos_page.dart';

/// ============================================================================
///  GARDE ADMIN — /admin-videos reste strictement invisible et inaccessible
///  pour tout utilisateur qui n'est pas is_admin = true / ADMIN_EMAILS.
///  En cas de refus, on affiche une page « introuvable » neutre : aucune
///  indication qu'une administration existe.
/// ============================================================================
class AdminGuardPage extends StatefulWidget {
  const AdminGuardPage({super.key});

  @override
  State<AdminGuardPage> createState() => _AdminGuardPageState();
}

class _AdminGuardPageState extends State<AdminGuardPage> {
  bool _verification = true;
  bool _admin = false;

  @override
  void initState() {
    super.initState();
    _verifier();
  }

  Future<void> _verifier() async {
    final admin = await ApiService.estAdmin();
    if (!mounted) return;
    setState(() {
      _admin = admin;
      _verification = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_verification) {
      return const Scaffold(
        backgroundColor: K.bg,
        body: Center(child: CircularProgressIndicator(color: K.or)),
      );
    }
    if (!_admin) return const _PageIntrouvable();
    return const AdminVideosPage();
  }
}

class _PageIntrouvable extends StatelessWidget {
  const _PageIntrouvable();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PatternBackground(
        child: SafeArea(
          child: Column(
            children: <Widget>[
              const AppHeader(),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const Text(
                          '404',
                          style: TextStyle(
                            color: K.borderLight,
                            fontSize: 84,
                            fontWeight: FontWeight.w900,
                            height: 1,
                            letterSpacing: -4,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Cette page n\'existe pas.',
                          style: TextStyle(
                            color: K.text,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Retournez à l\'accueil pour retrouver La Boutique et le Studio Live.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: K.muted, fontSize: 12.5, height: 1.5),
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          width: 220,
                          child: OrButton(
                            label: 'Retour à l\'accueil',
                            icone: Icons.arrow_back_rounded,
                            onPressed: () => Navigator.pushNamedAndRemoveUntil(
                              context,
                              '/',
                              (route) => false,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: const SiteAssistantChat(),
    );
  }
}
