import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  
  await Supabase.initialize(
    url: 'https://ynephuutnazdnjhsdlsy.supabase.co',
    publishableKey: 'sb_publishable_abG7DSxcPMPolOnLKPNcJw_Rod7G7S8', 
  );

  runApp(const KitBusinessApp());
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
        scaffoldBackgroundColor: const Color(0xFF030712), // Noir profond
        primaryColor: const Color(0xFF22C55E), // Vert Néon
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}

// --- GESTION DE L'AUTHENTIFICATION ---
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
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

  Future<void> _signIn() async {
    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: _email.text.trim(),
        password: _password.text.trim(),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur : ${e.toString()}'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signUp() async {
    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.auth.signUp(
        email: _email.text.trim(),
        password: _password.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Compte créé ! Vous pouvez vous connecter.'), backgroundColor: Colors.green));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur : ${e.toString()}'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            width: 400,
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.rocket_launch, size: 60, color: Color(0xFF22C55E)),
                const SizedBox(height: 20),
                const Text('Kit Business', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                const SizedBox(height: 30),
                TextField(
                  controller: _email,
                  decoration: InputDecoration(labelText: 'Email', filled: true, fillColor: Colors.white.withOpacity(0.05), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _password,
                  obscureText: true,
                  decoration: InputDecoration(labelText: 'Mot de passe', filled: true, fillColor: Colors.white.withOpacity(0.05), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _signIn,
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF22C55E), foregroundColor: Colors.black),
                    child: _isLoading ? const CircularProgressIndicator() : const Text('Se connecter', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
                TextButton(
                  onPressed: _isLoading ? null : _signUp,
                  child: const Text('Créer un compte', style: TextStyle(color: Color(0xFF22C55E))),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// --- DASHBOARD (Catalogue + Génération) ---
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _credits = 0;
  final _secteurCtrl = TextEditingController();
  bool _isGenerating = false;

  // Tes vrais IDs de produits (créés dans le SQL)
  final String idLivre = "78f5445b-6a3d-4970-868e-991b3ee6514c"; 
  final String idPack = "01e34186-f267-47b2-ac43-0dffe571e514";

  @override
  void initState() {
    super.initState();
    _fetchCredits();
  }

  Future<void> _fetchCredits() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      final res = await Supabase.instance.client.from('profiles').select('credits').eq('id', user.id).single();
      if (mounted) setState(() => _credits = res['credits'] ?? 0);
    }
  }

  Future<void> _buyProduct(String productId, double price) async {
    // Simulation de paiement (Mode Test)
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Simulation d\'achat en cours...')));
    
    try {
      final res = await Supabase.instance.client.functions.invoke('verify-payment', body: {
        'productId': productId,
        'transactionId': 'TEST_TX_${DateTime.now().millisecondsSinceEpoch}',
        'provider': 'test_mode',
        'amountPaid': price,
      });
      
      if (res.status == 200) {
        await _fetchCredits();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('🎉 Paiement validé ! Crédits ajoutés.'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _generate() async {
    if (_secteurCtrl.text.length < 3) return;
    if (_credits < 1) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Veuillez acheter des crédits !'), backgroundColor: Colors.red));
      return;
    }

    setState(() => _isGenerating = true);
    try {
      final res = await Supabase.instance.client.functions.invoke('generate-kit', body: {
        'secteurClient': _secteurCtrl.text.trim(),
        'emailClient': Supabase.instance.client.auth.currentUser!.email,
      });

      if (res.status == 200) {
        await _fetchCredits();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('🎉 Kit généré ! Vérifiez vos emails.'), backgroundColor: Colors.green));
      } else {
        throw Exception(res.data['error']);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Mon Espace Business'),
        actions: [
          Center(child: Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Chip(label: Text('$_credits Crédits', style: const TextStyle(fontWeight: FontWeight.bold)), backgroundColor: const Color(0xFF22C55E)),
          )),
          IconButton(icon: const Icon(Icons.logout, color: Colors.red), onPressed: () => Supabase.instance.client.auth.signOut()),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- GÉNÉRATEUR ---
            Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('🚀 Générateur de Kit', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  const Text('Décris ton activité pour générer ton livre et tes prompts.', style: TextStyle(color: Colors.white54)),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _secteurCtrl,
                          decoration: InputDecoration(
                            hintText: 'Ex: Boulangerie à Bamako',
                            filled: true, fillColor: Colors.white.withOpacity(0.05),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 20),
                      SizedBox(
                        height: 55,
                        child: ElevatedButton(
                          onPressed: _isGenerating ? null : _generate,
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF22C55E), foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                          child: _isGenerating ? const CircularProgressIndicator() : const Text('Générer (-1 Crédit)', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 40),
            const Text('🛍️ Boutique', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            
       // --- CATALOGUE ---
Wrap(
  spacing: 20,
  runSpacing: 20,
  children: [
    _buildProductCard(
      'Le Livre Stratégique',
      '1 Crédit',
      '79 DH',
      'f8a7dd07-d155-4b83-8289-286f2e44ee6b',
      79,
    ),
    _buildProductCard(
      'Les Prompts IA',
      '1 Crédit',
      '49 DH',
      '8cbddad5-7747-424e-8ed1-a1829ae46914',
      49,
    ),
    _buildProductCard(
      'Le Sheet Financier',
      '1 Crédit',
      '69 DH',
      'd4b7a69e-1720-4038-8da8-cf782fed24e9',
      69,
    ),
    _buildProductCard(
      'Pack Duo',
      '2 Crédits',
      '120 DH',
      '8c63364d-3d74-4100-adc6-d7d435920012',
      120,
    ),
    _buildProductCard(
      'Pack Complet',
      '3 Crédits',
      '149 DH',
      '54e2150a-1648-4119-a4df-208bcb121c27',
      149,
    ),
  ],
), // <-- La fermeture du Wrap
        
    ],
        ),
      ),
    );
  }

  Widget _buildProductCard(String title, String subtitle, String price, String id, double rawPrice) {
    return Container(
      width: 250,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 5),
          Text(subtitle, style: const TextStyle(color: Color(0xFF22C55E), fontWeight: FontWeight.w600)),
          const SizedBox(height: 15),
          Text(price, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
          const SizedBox(height: 15),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _buyProduct(id, rawPrice),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white, 
                foregroundColor: Colors.black,
              ),
              child: const Text('Acheter'),
            ),
          ), // <-- La virgule qui manquait ici
        ],
      ), // <-- Fermeture du Column
    ); // <-- Fermeture du Container et le point-virgule
  }
} // <-- Fermeture de la classe _DashboardPageState