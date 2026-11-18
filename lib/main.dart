import 'package:flutter/services.dart'; // Pour le presse-papiers (Clipboard)
import 'package:printing/printing.dart'; // Pour la génération du PDF
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';

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
                    const AppLogo(size: 70),
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
                    const SizedBox(height: 40),
const Divider(color: Colors.white12),
const SizedBox(height: 20),
Wrap(
  spacing: 16,
  runSpacing: 8,
  alignment: WrapAlignment.center,
  children: [
    TextButton(
      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CGVPage())),
      child: const Text('CGV', style: TextStyle(color: K.mist, fontSize: 12, decoration: TextDecoration.underline)),
    ),
    TextButton(
      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MentionsLegalesPage())),
      child: const Text('Mentions Légales', style: TextStyle(color: K.mist, fontSize: 12, decoration: TextDecoration.underline)),
    ),
    TextButton(
      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FAQPage())),
      child: const Text('FAQ', style: TextStyle(color: K.mist, fontSize: 12, decoration: TextDecoration.underline)),
    ),
  ],
),
const SizedBox(height: 10),
const Text(
  '© 2026 Kit Business. Tous droits réservés.',
  style: TextStyle(color: K.mist, fontSize: 12),
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
  final _password = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _toast(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color, behavior: SnackBarBehavior.floating),
    );
  }

  // FONCTION UNIQUE : CONNEXION OU INSCRIPTION AUTOMATIQUE
  Future<void> _loginOrSignup() async {
    final email = _email.text.trim();
    final password = _password.text.trim();

    if (email.isEmpty || password.length < 6) {
      _toast('Entrez un email et un mot de passe (min. 6 caractères).', K.clay);
      return;
    }

    setState(() => _isLoading = true);
    try {
      // 1. On essaie de connecter
      await Supabase.instance.client.auth.signInWithPassword(email: email, password: password);
    } on AuthException catch (e) {
      // 2. Si le compte n'existe pas, on le crée automatiquement
      if (e.message.contains('Invalid login credentials')) {
        try {
          await Supabase.instance.client.auth.signUp(email: email, password: password);
          _toast('Compte créé et connecté !', const Color(0xFF2E7D5B));
        } catch (signUpError) {
          if (!mounted) return;
          _toast('Erreur lors de la création du compte.', Colors.red.shade700);
        }
      } else {
        if (!mounted) return;
        _toast('Erreur : ${e.message}', Colors.red.shade700);
      }
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
                    const AppLogo(size: 85),
                    const SizedBox(height: 18),
                    const Text(
                      'Accédez à votre espace',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: K.sand, height: 1.2),
                    ),
                    const SizedBox(height: 26),
                    TextField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(color: K.sand),
                      decoration: InputDecoration(
                        labelText: 'Votre email',
                        labelStyle: const TextStyle(color: K.mist),
                        filled: true,
                        fillColor: K.deep.withOpacity(0.6),
                        prefixIcon: const Icon(Icons.alternate_email, color: K.mist),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _password,
                      obscureText: true,
                      style: const TextStyle(color: K.sand),
                      decoration: InputDecoration(
                        labelText: 'Mot de passe',
                        labelStyle: const TextStyle(color: K.mist),
                        filled: true,
                        fillColor: K.deep.withOpacity(0.6),
                        prefixIcon: const Icon(Icons.key, color: K.mist),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 26),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _loginOrSignup,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: K.gold,
                          foregroundColor: K.night,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: _isLoading
                            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: K.night, strokeWidth: 2.5))
                            : const Text('Se connecter / S\'inscrire', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Pas de compte ? Il sera créé automatiquement.',
                      style: TextStyle(color: K.mist, fontSize: 12),
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

String _dernierProduitAchete = 'livre'; // Le produit simple acheté
bool _isPack = false; // Est-ce que le dernier achat est un pack ?
final _problemeCtrl = TextEditingController();
String _typeSelectionne = 'livre'; // 'livre', 'prompt', 'sheet', 'pack'
class _DashboardPageState extends State<DashboardPage> {
  int _credits = 0;
  final _secteurCtrl = TextEditingController();
  bool _isGenerating = false;
  List<dynamic> _mesKits = [];

  @override
  void initState() {
    super.initState();
    _fetchCredits();
  }

  @override
  void dispose() {
    _secteurCtrl.dispose();
    _problemeCtrl.dispose();
    super.dispose();
  }

  void _toast(String msg, Color color, {SnackBarAction? action}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg), 
        backgroundColor: color, 
        behavior: SnackBarBehavior.floating,
        action: action,
      ),
    );
  }

  Future<void> _fetchCredits() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      final res = await Supabase.instance.client
          .from('profiles')
          .select('credits')
          .eq('id', user.id)
          .maybeSingle();
      if (mounted) setState(() => _credits = (res?['credits'] ?? 0) as int);
    } catch (_) {}
  }

  Future<void> _fetchHistorique() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      final res = await Supabase.instance.client
          .from('kits')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false);
      if (mounted) setState(() => _mesKits = res);
    } catch (_) {}
  }

 Future<void> _buyProduct(String productId, double price, String typeProduit) async {
  _toast('Paiement en cours…', K.deep);
  try {
    final res = await Supabase.instance.client.functions.invoke('verify-payment', body: {
      'productId': productId, 'transactionId': 'TEST_TX_${DateTime.now().millisecondsSinceEpoch}', 'provider': 'test_mode', 'amountPaid': price,
    });
    if (res.status == 200) {
      await _fetchCredits();
      if (!mounted) return;
      
      // 👇 On mémorise le type d'achat
      setState(() {
        _isPack = (typeProduit == 'pack');
        if (!_isPack) _dernierProduitAchete = typeProduit;
      });

      _toast('Paiement validé !', const Color(0xFF2E7D5B));
    }
  } catch (e) {
    if (!mounted) return;
    _toast('Paiement impossible.', Colors.red.shade700);
  }
}

  // --- GÉNÉRATION SANS EMAIL (AFFICHAGE DIRECT) ---
Future<void> _generate() async {
  if (_secteurCtrl.text.trim().length < 3) { 
    _toast('Décrivez votre activité.', K.clay); 
    return; 
  }
  
  // Le type dépend de ce qui a été acheté
  final typeToGenerate = _isPack ? _typeSelectionne : _dernierProduitAchete;
  
  int cout = typeToGenerate == 'pack' ? 3 : 1;
  if (_credits < cout) { 
    _toast('Il vous faut $cout crédit(s).', K.clay); 
    return; 
  }
  
  setState(() => _isGenerating = true);
  
  try {
    // 👇 C'EST ICI QU'ON ENVOIE TOUT À SUPABASE
    final res = await Supabase.instance.client.functions.invoke('generate-kit', body: {
      'secteurClient': _secteurCtrl.text.trim(),
      'problemeClient': _problemeCtrl.text.trim(), // 👈 Le nouveau champ
      'emailClient': Supabase.instance.client.auth.currentUser!.email,
      'typeProduit': typeToGenerate,
    });
    
    if (res.status == 200) {
      await _fetchCredits();
      if (!mounted) return;
      
      // On vide les champs une fois que c'est fini
      _secteurCtrl.clear();
      _problemeCtrl.clear();
      
      _showResultDialog(res.data['livre'] ?? "", res.data['prompt'] ?? "", res.data['sheetUrl'] ?? "");
    } else {
      throw Exception(res.data['error']);
    }
  } catch (e) {
    if (!mounted) return;
    _toast('Génération impossible. Réessayez.', Colors.red.shade700);
  } finally {
    if (mounted) setState(() => _isGenerating = false);
  }
}

void _showResultDialog(String livre, String prompts, String sheetUrl) {
  showDialog(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: K.night,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 700, 
        height: 600, 
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          border: Border.all(color: K.gold.withOpacity(0.3)), 
          borderRadius: BorderRadius.circular(20)
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            
            // --- TITRE ET BOUTONS DU HAUT (PDF / COPIER / FERMER) ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween, 
              children: [
                const Text(
                  '✨ Votre Kit est prêt', 
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: K.sand)
                ),
                
                Row(
                  children: [
                    // Bouton Copier
                    IconButton(
                      icon: const Icon(Icons.copy, color: K.mist),
                      tooltip: "Copier le texte",
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: livre));
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Texte copié !')));
                      },
                    ),
                    
                    // Bouton PDF
                    IconButton(
                      icon: const Icon(Icons.picture_as_pdf, color: K.gold),
                      tooltip: "Télécharger en PDF",
                      onPressed: () async {
  if (livre.isEmpty) return;
  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Génération du PDF en cours...')));
  try {
    await Printing.layoutPdf(
      onLayout: (format) => Printing.convertHtml(
        format: format,
        html: livre,
      ),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur PDF: $e')));
  }
},
                    ),
                    
                    // Bouton Fermer
                    IconButton(
                      icon: const Icon(Icons.close, color: K.mist), 
                      onPressed: () => Navigator.pop(context)
                    )
                  ],
                )
              ]
            ),
            
            const Divider(color: K.mist),
            
            // --- CONTENU DU KIT (LIVRE ET PROMPTS) ---
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    
                    // Le Livre
                    if (livre.isNotEmpty) ...[
                      const Text('📘 Livre Stratégique', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: K.gold)),
                      const SizedBox(height: 8),
                      HtmlWidget(livre, textStyle: const TextStyle(color: K.sand, height: 1.5)),
                      const SizedBox(height: 24),
                    ],
                    
                    // Les Prompts
                    if (prompts.isNotEmpty) ...[
                      const Text('🤖 Prompts IA', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: K.gold)),
                      const SizedBox(height: 8),
                      HtmlWidget(prompts, textStyle: const TextStyle(color: K.sand, height: 1.5)),
                    ],
                    
                  ],
                ),
              ),
            ),
            
            // --- BOUTON GOOGLE SHEET (TOUT EN BAS) ---
            const SizedBox(height: 20),
            
            if (sheetUrl.isNotEmpty && !sheetUrl.contains('undefined'))
              BoutonOuvrirSheet(sheetUrl: sheetUrl),

          ], // Fin du children de la Column principale
        ), // Fin de la Column
      ), // Fin du Container
    ), // Fin du Dialog
  ); // Fin du showDialog
}

  // --- FENÊTRE HISTORIQUE ---
  void _showHistoriqueDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: K.night,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: 600, height: 500, padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(border: Border.all(color: K.gold.withOpacity(0.3)), borderRadius: BorderRadius.circular(20)),
          child: Column(
            children: [
              const Text('📚 Mes Kits', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: K.sand)),
              const Divider(color: K.mist),
              Expanded(
                child: _mesKits.isEmpty
                    ? const Center(child: Text("Aucun kit généré.", style: TextStyle(color: K.mist)))
                    : ListView.builder(
                        itemCount: _mesKits.length,
                        itemBuilder: (context, index) {
                          final kit = _mesKits[index];
                          return ListTile(
                            title: Text("Secteur : ${kit['secteur_client']}", style: const TextStyle(color: K.sand)),
                            subtitle: Text(kit['created_at'].toString().substring(0, 10), style: const TextStyle(color: K.mist)),
                            trailing: IconButton(
                              icon: const Icon(Icons.visibility, color: K.gold),
                              onPressed: () {
                                Navigator.pop(context);
                                _showResultDialog(kit['livre_html'], kit['prompts_html'], kit['sheet_url']);
                              },
                            ),
                          );
                        },
                      ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Fermer', style: TextStyle(color: K.mist)),
              )
            ],
          ),
        ),
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
            constraints: const BoxConstraints(maxWidth: 900),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- HEADER ---
                  Row(
  children: [
    const Expanded(
      child: Text(
        'Mon espace',
        style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: K.sand),
      ),
    ),
    // 👇 LE BOUTON HISTORIQUE EST DE RETOUR
    IconButton(
      tooltip: 'Mes Kits',
      icon: const Icon(Icons.folder_open_rounded, color: K.gold),
      onPressed: () {
        _fetchHistorique();
        _showHistoriqueDialog();
      },
    ),
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: K.gold,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$_credits crédit${_credits > 1 ? 's' : ''}',
        style: const TextStyle(fontWeight: FontWeight.w800, color: K.night),
      ),
    ),
    IconButton(
      tooltip: 'Se déconnecter',
      icon: const Icon(Icons.logout_rounded, color: K.mist),
      onPressed: () => Supabase.instance.client.auth.signOut(),
    ),
  ],
),
                  const SizedBox(height: 28),

                  // --- GÉNÉRATEUR ---
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: K.night.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: K.gold.withOpacity(0.35)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Générez votre kit',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: K.sand),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Décrivez votre activité. Votre livre, vos prompts et votre sheet apparaîtront instantanément.',
                          style: TextStyle(color: K.mist, height: 1.5),
                        ),
                        const SizedBox(height: 20),
                        
                        // Menu déroulant (seulement si Pack)
                        if (_isPack) ...[
                          DropdownButtonFormField<String>(
                            value: _typeSelectionne,
                            dropdownColor: K.night,
                            style: const TextStyle(color: K.sand),
                            decoration: InputDecoration(
                              filled: true, fillColor: K.deep.withOpacity(0.6),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'livre', child: Text('📘 Le Livre Stratégique')),
                              DropdownMenuItem(value: 'prompt', child: Text('🤖 Les Prompts IA')),
                              DropdownMenuItem(value: 'sheet', child: Text('📊 Le Google Sheet')),
                              DropdownMenuItem(value: 'pack', child: Text('💎 Le Pack Complet')),
                            ],
                            onChanged: (val) => setState(() => _typeSelectionne = val!),
                          ),
                          const SizedBox(height: 16),
                        ] else ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: K.deep.withOpacity(0.6), borderRadius: BorderRadius.circular(14)),
                            child: Text('Produit à générer : ${_dernierProduitAchete.toUpperCase()}', style: const TextStyle(color: K.gold, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Champ Secteur
                        TextField(
                          controller: _secteurCtrl,
                          style: const TextStyle(color: K.sand),
                          decoration: InputDecoration(
                            hintText: 'Ex : boulangerie à Bamako',
                            hintStyle: TextStyle(color: K.mist.withOpacity(0.6)),
                            filled: true,
                            fillColor: K.deep.withOpacity(0.6),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: K.gold, width: 1.5)),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Champ Problème
                        TextField(
                          controller: _problemeCtrl,
                          maxLines: 2,
                          style: const TextStyle(color: K.sand),
                          decoration: InputDecoration(
                            hintText: 'Quel est votre défi actuel ? (ex: Je ne trouve pas de clients)',
                            hintStyle: TextStyle(color: K.mist.withOpacity(0.6)),
                            filled: true,
                            fillColor: K.deep.withOpacity(0.6),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: K.gold, width: 1.5)),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Bouton Générer
                        SizedBox(
                          height: 54,
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isGenerating ? null : _generate,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: K.gold,
                              foregroundColor: K.night,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            child: _isGenerating
                                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: K.night, strokeWidth: 2.5))
                                : const Text('Générer mon Kit', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),

                  // --- BOUTIQUE ---
                  const Text(
                    'Choisissez votre kit',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: K.sand),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Chaque crédit génère un kit complet pour une activité.',
                    style: TextStyle(color: K.mist),
                  ),
                  const SizedBox(height: 20),
                  LayoutBuilder(builder: (context, c) {
                    final w = c.maxWidth < 640 ? c.maxWidth : (c.maxWidth - 20) / 2;
                    return Wrap(
                      spacing: 20,
                      runSpacing: 20,
                      children: [
                        
                        _buildProductCard(w, 'Le Livre Stratégique', 'Votre plan d\'action complet, rédigé pour votre secteur.', '1 crédit', '79 DH', 'f8a7dd07-d155-4b83-8289-286f2e44ee6b', 79, 'livre'),
                        _buildProductCard(w, 'Les Prompts IA', 'Des prompts prêts à copier pour vos ventes et votre contenu.', '1 crédit', '49 DH', '8cbddad5-7747-424e-8ed1-a1829ae46914', 49, 'prompt'),
                        _buildProductCard(w, 'Le Sheet Automatisé', 'Un Google Sheet qui calcule vos ventes, stocks et marges à votre place.', '1 crédit', '59 DH', 'd4b7a69e-1720-4038-8da8-cf782fed24e9', 59, 'sheet'),
                        _buildProductCard(w, 'Le Pack Complet', 'Le livre, les prompts et le sheet automatisé : tout votre kit en une fois.', '3 crédits', '149 DH', '54e2150a-1648-4119-a4df-208bcb121c27', 149, 'pack', featured: true),
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

  Widget _buildProductCard(
    double width,
    String title,
    String description,
    String credits,
    String price,
    String id,
    double rawPrice,
    String typeProduit, {
    bool featured = false,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: featured ? K.deep : K.night.withOpacity(0.7),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: featured ? K.gold : K.gold.withOpacity(0.2),
          width: featured ? 2 : 1,
        ),
        boxShadow: featured
            ? [BoxShadow(color: K.gold.withOpacity(0.18), blurRadius: 28, offset: const Offset(0, 8))]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (featured)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: K.gold, borderRadius: BorderRadius.circular(10)),
              child: const Text(
                'Le plus choisi',
                style: TextStyle(color: K.night, fontWeight: FontWeight.w800, fontSize: 12),
              ),
            ),
          Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: K.sand)),
          const SizedBox(height: 8),
          Text(description, style: const TextStyle(color: K.mist, height: 1.45, fontSize: 14)),
          const SizedBox(height: 18),
          Text(price, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: K.goldSoft)),
          Text(credits, style: const TextStyle(color: K.mist, fontSize: 13)),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () => _buyProduct(id, rawPrice, typeProduit),
              style: ElevatedButton.styleFrom(
                backgroundColor: featured ? K.gold : Colors.transparent,
                foregroundColor: featured ? K.night : K.gold,
                elevation: 0,
                side: featured ? null : const BorderSide(color: K.gold),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Acheter', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// LE LOGO KIT BUSINESS
// ==========================================
class AppLogo extends StatelessWidget {
  final double size;
  const AppLogo({super.key, this.size = 60});

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(size * 0.28);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [K.goldSoft, K.gold, K.clay],
          stops: [0.0, 0.5, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: K.gold.withOpacity(0.45),
            blurRadius: size * 0.45,
            spreadRadius: -size * 0.05,
            offset: Offset(0, size * 0.12),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: size * 0.2,
            offset: Offset(0, size * 0.06),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: size * 0.5,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withOpacity(0.35),
                      Colors.white.withOpacity(0.0),
                    ],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: radius,
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: size * 0.02,
                  ),
                ),
              ),
            ),
            Icon(
              Icons.rocket_launch_rounded,
              color: K.night,
              size: size * 0.52,
              shadows: [
                Shadow(
                  color: Colors.white.withOpacity(0.35),
                  blurRadius: size * 0.08,
                  offset: Offset(0, size * 0.02),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
// ==========================================
// WIDGET RÉUTILISABLE : BOUTON GOOGLE SHEET
// ==========================================
class BoutonOuvrirSheet extends StatelessWidget {
  final String sheetUrl;

  const BoutonOuvrirSheet({super.key, required this.sheetUrl});

  Future<void> _ouvrirGoogleSheet() async {
    final Uri uri = Uri.parse(sheetUrl);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception('Impossible d’ouvrir le lien $sheetUrl');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton.icon(
        onPressed: _ouvrirGoogleSheet,
        icon: const Icon(Icons.table_chart, color: K.night),
        label: const Text(
          "Ouvrir mon Google Sheet",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: K.gold,
          foregroundColor: K.night,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}
class PageTexteLegal extends StatelessWidget {
  final String titre;
  final String contenu;

  const PageTexteLegal({super.key, required this.titre, required this.contenu});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: K.night,
      appBar: AppBar(
        backgroundColor: K.deep,
        title: Text(titre, style: const TextStyle(color: K.gold, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: K.gold),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Text(
          contenu,
          style: const TextStyle(color: K.sand, fontSize: 14, height: 1.6),
        ),
      ),
    );
  }
}
// ==========================================
// 1. PAGE CGV
// ==========================================
class CGVPage extends StatelessWidget {
  const CGVPage({super.key});

  @override
  Widget build(BuildContext context) {
    const String texte = '''
1. Objet
Les présentes Conditions Générales de Vente (CGV) régissent les relations contractuelles entre Kit Business (édité par Offboard-Hub) et tout utilisateur effectuant un achat sur le site e-booklive.offboard-hub.com.

2. Produits et Services
Les produits proposés sont des contenus numériques (livres PDF, prompts IA, tableaux Google Sheets) générés par intelligence artificielle à la demande. Ils sont fournis immédiatement après le paiement. Aucune livraison physique n'est effectuée.

3. Prix et Moyens de Paiement
Les prix sont indiqués en Dirhams (MAD) et en Dollars (USD). Le paiement est exigible immédiatement. Pour sécuriser vos transactions, nous faisons appel à plusieurs prestataires de paiement certifiés :
- YouCan Pay (Cartes bancaires marocaines)
- Flutterwave (Cartes internationales, Mobile Money)
- Paystack (Cartes bancaires, virements)
- SinetPay (Mobile Money - Afrique de l'Ouest)
- Lemon Squeezy (Paiements internationaux)

4. Droit de rétractation
Conformément à la législation sur les produits numériques fournis immédiatement, le client renonce à son droit de rétractation une fois le produit généré. Toutefois, en cas d'erreur technique, les crédits sont automatiquement remboursés.

5. Contact
Pour toute question, contactez-nous à : contact@e-booklive.offboard-hub.com
''';

    return Scaffold(
      backgroundColor: K.night,
      appBar: AppBar(
        backgroundColor: K.deep,
        title: const Text('Conditions Générales', style: TextStyle(color: K.gold, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: K.gold),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Text(
          texte, // 👈 Le texte est bien ici
          style: const TextStyle(color: K.sand, fontSize: 15, height: 1.6),
        ),
      ),
    );
  }
}

// ==========================================
// 2. PAGE MENTIONS LÉGALES
// ==========================================
class MentionsLegalesPage extends StatelessWidget {
  const MentionsLegalesPage({super.key});

  @override
  Widget build(BuildContext context) {
    const String texte = '''
Éditeur du site :
Kit Business / Offboard-Hub
Email : contact@e-booklive.offboard-hub.com
Site web : https://e-booklive.offboard-hub.com

Hébergement :
Le site est hébergé par Netlify (www.netlify.com).

Propriété intellectuelle :
L'ensemble des contenus générés (textes, livres, prompts) est protégé. Toute reproduction sans autorisation est interdite.

Responsable de publication :
Fatima Touré
''';

    return Scaffold(
      backgroundColor: K.night,
      appBar: AppBar(
        backgroundColor: K.deep,
        title: const Text('Mentions Légales', style: TextStyle(color: K.gold, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: K.gold),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Text(
          texte,
          style: const TextStyle(color: K.sand, fontSize: 15, height: 1.6),
        ),
      ),
    );
  }
}

// ==========================================
// 3. PAGE FAQ (Questions Fréquentes)
// ==========================================
class FAQPage extends StatelessWidget {
  const FAQPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: K.night,
      appBar: AppBar(
        backgroundColor: K.deep,
        title: const Text('FAQ - Aide', style: TextStyle(color: K.gold, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: K.gold),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          FAQItem(
            question: 'Comment fonctionne Kit Business ?',
            reponse: 'Vous choisissez votre secteur d’activité, effectuez le paiement, et notre intelligence artificielle génère instantanément votre livre stratégique, vos prompts marketing et votre tableau financier Google Sheets.',
          ),
          FAQItem(
            question: 'Est-ce que je reçois un produit physique ?',
            reponse: 'Non, il s’agit de produits 100% numériques (fichiers PDF et liens Google Sheets). Ils sont disponibles immédiatement après le paiement.',
          ),
          FAQItem(
            question: 'Puis-je télécharger mon livre ?',
            reponse: 'Oui, une fois généré, un bouton "Télécharger en PDF" vous permet d’enregistrer votre livre sur votre appareil.',
          ),
          FAQItem(
            question: 'Quels sont les moyens de paiement acceptés ?',
            reponse: 'Nous acceptons les cartes bancaires (via YouCan Pay, Flutterwave, Paystack) et le Mobile Money (via SinetPay).',
          ),
          FAQItem(
            question: 'Comment obtenir de l’aide ?',
            reponse: 'Pour toute assistance, écrivez-nous à contact@e-booklive.offboard-hub.com. Nous répondons sous 24h.',
          ),
        ],
      ),
    );
  }
}

// Widget réutilisable pour la FAQ
class FAQItem extends StatelessWidget {
  final String question;
  final String reponse;
  const FAQItem({super.key, required this.question, required this.reponse});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: K.deep,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        iconColor: K.gold,
        collapsedIconColor: K.mist,
        title: Text(question, style: const TextStyle(color: K.sand, fontWeight: FontWeight.bold, fontSize: 16)),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(reponse, style: const TextStyle(color: K.mist, height: 1.5)),
          ),
        ],
      ),
    );
  }
}