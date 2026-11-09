import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  
  await Supabase.initialize(
    url: 'https://ynephuutnazdnjhsdlsy.supabase.co',
    publishableKey: 'sb_publishable_abG7DSxcPMPolOnLKPNcJw_Rod7G7S8', 
  );

  runApp(const KitBusinessApp());
}

// ==========================================
// PALETTE : indigo du Mali, or du Sahel, sable
// ==========================================
class K {
  static const night = Color(0xFF14123A); 
  static const deep = Color(0xFF1F1B55);
  static const gold = Color(0xFFE8B04B); 
  static const goldSoft = Color(0xFFF3D38F);
  static const sand = Color(0xFFF6EBD4); 
  static const clay = Color(0xFFB8643C); 
  static const mist = Color(0xFFB9B4D6); 
}

class KitBusinessApp extends StatelessWidget {
  const KitBusinessApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Kit Business',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: K.night,
        primaryColor: K.gold,
        useMaterial3: true,
        colorScheme: const ColorScheme.dark(primary: K.gold, surface: K.night),
      ),
      home: const LandingPage(),
    );
  }
}

// ==========================================
// MOTIF BOGOLAN
// ==========================================
class BogolanPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = K.gold.withOpacity(0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    const step = 56.0;
    for (double y = 0; y < size.height + step; y += step) {
      for (double x = 0; x < size.width + step; x += step) {
        final c = Offset(x, y);
        final path = Path()
          ..moveTo(c.dx, c.dy - 14)
          ..lineTo(c.dx + 14, c.dy)
          ..lineTo(c.dx, c.dy + 14)
          ..lineTo(c.dx - 14, c.dy)
          ..close();
        canvas.drawPath(path, p);
        canvas.drawCircle(c.translate(step / 2, step / 2), 1.6, p);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class PatternBackground extends StatelessWidget {
  final Widget child;
  const PatternBackground({super.key, required this.child});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [K.deep, K.night],
        ),
      ),
      child: CustomPaint(painter: BogolanPainter(), child: child),
    );
  }
}

// ==========================================
// 1. PAGE D'ACCUEIL (LANDING PAGE)
// ==========================================
class LandingPage extends StatefulWidget {
  const LandingPage({super.key});
  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  late final PageController _pageController;
  int _currentPage = 0;
  Timer? _timer;

  final List<String> images = [
    'https://images.unsplash.com/photo-1553729459-efe14ef6055d?q=80&w=600&auto=format&fit=crop',
    'https://images.unsplash.com/photo-1551288049-bebda4e38f71?q=80&w=600&auto=format&fit=crop',
    'https://images.unsplash.com/photo-1677442136019-21780ecad995?q=80&w=600&auto=format&fit=crop',
    'https://images.unsplash.com/photo-1542744173-8e7e53415bb0?q=80&w=600&auto=format&fit=crop',
    'https://images.unsplash.com/photo-1486406146926-c627a92ad1ab?q=80&w=600&auto=format&fit=crop',
  ];

  final List<String> captions = [
    'Une stratégie\nclaire',
    'Des idées\nqui vendent',
    'Une croissance\nqui dure',
    'Votre marché,\nvos clients',
    'Prêt à\nvous lancer',
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.72);
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (_pageController.hasClients) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _enter() {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const AuthGate(),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 700),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PatternBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    const Icon(Icons.wb_twilight_rounded, color: K.gold, size: 34),
                    const SizedBox(height: 16),
                    const Text(
                      'Votre business mérite\nun vrai plan.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 38,
                        fontWeight: FontWeight.w800,
                        height: 1.12,
                        color: K.sand,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Un livre stratégique et des prompts IA écrits pour votre activité, prêts en quelques minutes.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, height: 1.5, color: K.mist),
                    ),
                    const SizedBox(height: 36),
                    SizedBox(
                      height: 300,
                      child: PageView.builder(
                        controller: _pageController,
                        onPageChanged: (i) => setState(() => _currentPage = i),
                        itemBuilder: (context, index) {
                          final i = index % images.length;
                          final active = index == _currentPage;
                          return AnimatedScale(
                            scale: active ? 1.0 : 0.88,
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.easeOut,
                            child: AnimatedOpacity(
                              opacity: active ? 1 : 0.65,
                              duration: const Duration(milliseconds: 400),
                              child: Container(
                                margin: const EdgeInsets.symmetric(horizontal: 8),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(28),
                                  border: Border.all(color: K.gold.withOpacity(active ? 0.7 : 0.15), width: 1.5),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.45),
                                      blurRadius: 24,
                                      offset: const Offset(0, 12),
                                    ),
                                  ],
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Image.network(
                                      images[i],
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(color: K.deep),
                                      loadingBuilder: (c, child, p) =>
                                          p == null ? child : Container(color: K.deep),
                                    ),
                                    Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [Colors.transparent, K.night.withOpacity(0.92)],
                                          stops: const [0.4, 1],
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      left: 20,
                                      bottom: 20,
                                      child: Text(
                                        captions[i],
                                        style: const TextStyle(
                                          color: K.sand,
                                          fontSize: 24,
                                          fontWeight: FontWeight.w700,
                                          height: 1.15,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 40),
                    ElevatedButton(
                      onPressed: _enter,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: K.gold,
                        foregroundColor: K.night,
                        padding: const EdgeInsets.symmetric(horizontal: 44, vertical: 20),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 8,
                        shadowColor: K.gold.withOpacity(0.45),
                      ),
                      child: const Text(
                        'Créer mon kit',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Connexion par email, sans mot de passe.',
                      style: TextStyle(color: K.mist, fontSize: 13),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ==========================================
// 2. AUTHENTIFICATION (MAGIC LINK)
// ==========================================
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: K.night,
            body: Center(child: CircularProgressIndicator(color: K.gold)),
          );
        }
        final session = Supabase.instance.client.auth.currentSession;
        if (session != null) return const DashboardPage();
        return const LoginPage();
      },
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  void _toast(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color, behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _sendMagicLink() async {
    final email = _email.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _toast('Entrez une adresse email valide.', K.clay);
      return;
    }
    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.auth.signInWithOtp(email: email);
      if (!mounted) return;
      _toast('Lien envoyé. Ouvrez votre boîte mail pour vous connecter.', const Color(0xFF2E7D5B));
    } catch (e) {
      if (!mounted) return;
      _toast('Envoi impossible. Vérifiez l\'adresse et réessayez.', Colors.red.shade700);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PatternBackground(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Container(
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                  color: K.night.withOpacity(0.75),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: K.gold.withOpacity(0.25)),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 30)],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.mail_outline_rounded, size: 46, color: K.gold),
                    const SizedBox(height: 18),
                    const Text(
                      'Recevoir mon lien de connexion',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: K.sand, height: 1.2),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Entrez votre email. Nous vous envoyons un lien, un clic et vous êtes dedans.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: K.mist, fontSize: 14, height: 1.5),
                    ),
                    const SizedBox(height: 26),
                    TextField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(color: K.sand),
                      onSubmitted: (_) => _sendMagicLink(),
                      decoration: InputDecoration(
                        labelText: 'Votre email',
                        labelStyle: const TextStyle(color: K.mist),
                        filled: true,
                        fillColor: K.deep.withOpacity(0.6),
                        prefixIcon: const Icon(Icons.alternate_email, color: K.mist),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: K.gold, width: 1.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _sendMagicLink,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: K.gold,
                          foregroundColor: K.night,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(color: K.night, strokeWidth: 2.5),
                              )
                            : const Text('Envoyer le lien', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ==========================================
// 3. DASHBOARD
// ==========================================
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _credits = 0;
  final _secteurCtrl = TextEditingController();
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    _fetchCredits();
  }

  @override
  void dispose() {
    _secteurCtrl.dispose();
    super.dispose();
  }

  void _toast(String msg, Color color, {SnackBarAction? action}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color, behavior: SnackBarBehavior.floating, action: action));
  }

  Future<void> _fetchCredits() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      final res = await Supabase.instance.client.from('profiles').select('credits').eq('id', user.id).maybeSingle();
      if (mounted) setState(() => _credits = (res?['credits'] ?? 0) as int);
    } catch (_) {}
  }

  Future<void> _buyProduct(String productId, double price) async {
    _toast('Paiement en cours…', K.deep);
    try {
      final res = await Supabase.instance.client.functions.invoke('verify-payment', body: {
        'productId': productId, 'transactionId': 'TEST_TX_${DateTime.now().millisecondsSinceEpoch}', 'provider': 'test_mode', 'amountPaid': price,
      });
      if (res.status == 200) {
        await _fetchCredits();
        if (!mounted) return;
        _toast('Paiement validé. Vos crédits sont ajoutés.', const Color(0xFF2E7D5B));
      }
    } catch (e) {
      if (!mounted) return;
      _toast('Paiement impossible. Réessayez dans un instant.', Colors.red.shade700);
    }
  }

  Future<void> _generate() async {
    if (_secteurCtrl.text.trim().length < 3) { _toast('Décrivez votre activité en quelques mots.', K.clay); return; }
    if (_credits < 1) { _toast('Il vous faut au moins 1 crédit. Choisissez un kit ci-dessous.', K.clay); return; }
    
    setState(() => _isGenerating = true);
    try {
      final res = await Supabase.instance.client.functions.invoke('generate-kit', body: {
        'secteurClient': _secteurCtrl.text.trim(), 'emailClient': Supabase.instance.client.auth.currentUser!.email,
      });
      if (res.status == 200) {
        await _fetchCredits();
        if (!mounted) return;
        _secteurCtrl.clear();
        _toast('Votre kit est prêt. Regardez dans votre boîte mail.', const Color(0xFF2E7D5B), action: SnackBarAction(label: 'Ouvrir mes mails', textColor: Colors.white, onPressed: () => launchUrl(Uri.parse('https://mail.google.com'), mode: LaunchMode.externalApplication)));
      } else {
        throw Exception(res.data['error']);
      }
    } catch (e) {
      if (!mounted) return;
      _toast('Génération impossible. Vos crédits n\'ont pas été touchés.', Colors.red.shade700);
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PatternBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(child: Text('Mon espace', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: K.sand))),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(color: K.gold, borderRadius: BorderRadius.circular(20)),
                          child: Text('$_credits crédit${_credits > 1 ? 's' : ''}', style: const TextStyle(fontWeight: FontWeight.w800, color: K.night)),
                        ),
                        IconButton(tooltip: 'Se déconnecter', icon: const Icon(Icons.logout_rounded, color: K.mist), onPressed: () => Supabase.instance.client.auth.signOut()),
                      ],
                    ),
                    const SizedBox(height: 28),
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(color: K.night.withOpacity(0.7), borderRadius: BorderRadius.circular(24), border: Border.all(color: K.gold.withOpacity(0.35))),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Générez votre kit', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: K.sand)),
                          const SizedBox(height: 8),
                          const Text('Décrivez votre activité. Votre livre stratégique, vos prompts et votre sheet automatisé arrivent par email.', style: TextStyle(color: K.mist, height: 1.5)),
                          const SizedBox(height: 20),
                          LayoutBuilder(builder: (context, c) {
                            final narrow = c.maxWidth < 520;
                            final field = TextField(
                              controller: _secteurCtrl,
                              style: const TextStyle(color: K.sand),
                              decoration: InputDecoration(
                                hintText: 'Ex : boulangerie à Bamako',
                                hintStyle: TextStyle(color: K.mist.withOpacity(0.6)),
                                filled: true, fillColor: K.deep.withOpacity(0.6),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: K.gold, width: 1.5)),
                              ),
                            );
                            final button = SizedBox(
                              height: 54, width: narrow ? double.infinity : null,
                              child: ElevatedButton(
                                onPressed: _isGenerating ? null : _generate,
                                style: ElevatedButton.styleFrom(backgroundColor: K.gold, foregroundColor: K.night, padding: const EdgeInsets.symmetric(horizontal: 26), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                                child: _isGenerating ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: K.night, strokeWidth: 2.5)) : const Text('Générer (1 crédit)', style: TextStyle(fontWeight: FontWeight.w800)),
                              ),
                            );
                            if (narrow) return Column(children: [field, const SizedBox(height: 14), button]);
                            return Row(children: [Expanded(child: field), const SizedBox(width: 16), button]);
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                    const Text('Choisissez votre kit', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: K.sand)),
                    const SizedBox(height: 6),
                    const Text('Chaque crédit génère un kit complet pour une activité.', style: TextStyle(color: K.mist)),
                    const SizedBox(height: 20),
                    LayoutBuilder(builder: (context, c) {
                      final w = c.maxWidth < 640 ? c.maxWidth : (c.maxWidth - 20) / 2;
                      return Wrap(
                        spacing: 20, runSpacing: 20,
                        children: [
                          
                          _buildProductCard(w, 'Le Livre Stratégique', 'Votre plan d\'action complet, rédigé pour votre secteur.', '1 crédit', '79 DH', 'f8a7dd07-d155-4b83-8289-286f2e44ee6b', 79),
                          _buildProductCard(w, 'Les Prompts IA', 'Des prompts prêts à copier pour vos ventes et votre contenu.', '1 crédit', '49 DH', '8cbddad5-7747-424e-8ed1-a1829ae46914', 49),
                          _buildProductCard(w, 'Le Sheet Automatisé', 'Un Google Sheet qui calcule vos ventes, stocks et marges à votre place.', '1 crédit', '59 DH', 'd4b7a69e-1720-4038-8da8-cf782fed24e9', 59),
                          _buildProductCard(w, 'Le Pack Complet', 'Le livre, les prompts et le sheet automatisé : tout votre kit en une fois.', '3 crédits', '149 DH', '54e2150a-1648-4119-a4df-208bcb121c27', 149, featured: true),
                        ],
                      );
                    }),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProductCard(double width, String title, String description, String credits, String price, String id, double rawPrice, {bool featured = false}) {
    return Container(
      width: width, padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: featured ? K.deep : K.night.withOpacity(0.7),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: featured ? K.gold : K.gold.withOpacity(0.2), width: featured ? 2 : 1),
        boxShadow: featured ? [BoxShadow(color: K.gold.withOpacity(0.18), blurRadius: 28, offset: const Offset(0, 8))] : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (featured) Container(margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: K.gold, borderRadius: BorderRadius.circular(10)), child: const Text('Le plus choisi', style: TextStyle(color: K.night, fontWeight: FontWeight.w800, fontSize: 12))),
          Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: K.sand)),
          const SizedBox(height: 8),
          Text(description, style: const TextStyle(color: K.mist, height: 1.45, fontSize: 14)),
          const SizedBox(height: 18),
          Text(price, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: K.goldSoft)),
          Text(credits, style: const TextStyle(color: K.mist, fontSize: 13)),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity, height: 48,
            child: ElevatedButton(
              onPressed: () => _buyProduct(id, rawPrice),
              style: ElevatedButton.styleFrom(backgroundColor: featured ? K.gold : Colors.transparent, foregroundColor: featured ? K.night : K.gold, elevation: 0, side: featured ? null : const BorderSide(color: K.gold), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              child: const Text('Acheter', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }
}