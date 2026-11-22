import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config.dart';
import '../core/links.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../services/api.dart';
import '../widgets/app_header.dart';
import '../widgets/site_assistant_chat.dart';
import '../widgets/whatsapp.dart';
import 'auth_page.dart';
import 'confirmation_page.dart';

/// Porte d'entrée de l'espace client : session active ou page de connexion.
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
        if (Supabase.instance.client.auth.currentSession != null) {
          return const DashboardPage();
        }
        return const AuthPage();
      },
    );
  }
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final TextEditingController _nomProjet = TextEditingController();
  final TextEditingController _precisions = TextEditingController();

  int _credits = 0;
  bool _admin = false;
  bool _chargement = true;
  bool _generation = false;
  List<Map<String, dynamic>> _kits = [];
  List<CommandeResume> _commandes = [];

  String _metierCode = 'restaurant';
  Offre _offre = offres.last;
  Pays _pays = paysAfricains.first;

  @override
  void initState() {
    super.initState();
    _chargerTout();
  }

  @override
  void dispose() {
    _nomProjet.dispose();
    _precisions.dispose();
    super.dispose();
  }

  Future<void> _chargerTout() async {
    if (!mounted) return;
    setState(() => _chargement = true);
    final credits = await ApiService.credits();
    final admin = await ApiService.estAdmin();
    final kits = await ApiService.mesKits().catchError((_) => <Map<String, dynamic>>[]);
    final commandes = await ApiService.mesCommandes();
    if (!mounted) return;
    setState(() {
      _credits = credits;
      _admin = admin;
      _kits = kits;
      _commandes = commandes;
      _chargement = false;
    });
  }

  void _toast(String message, {Color couleur = K.clay}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: couleur, behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _deconnexion() async {
    await Supabase.instance.client.auth.signOut();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
  }

  Future<void> _regenerer() async {
    final cout = _offre.credits;
    if (_nomProjet.text.trim().length < 3) {
      _toast('Renseignez le nom de votre projet.');
      return;
    }
    if (_credits < cout) {
      _toast('Il vous faut $cout crédit(s). Passez commande pour recharger.');
      return;
    }

    setState(() => _generation = true);
    try {
      final resultat = await ApiService.regenererKit(
        metierCode: _metierCode,
        nomProjet: _nomProjet.text.trim(),
        paysCode: _pays.code,
        produitType: _offre.apiType,
        precisions: _precisions.text.trim(),
      );
      if (!mounted) return;
      setState(() => _generation = false);
      _nomProjet.clear();
      _precisions.clear();
      await _chargerTout();
      if (!mounted) return;
      await _afficherResultat(resultat);
    } catch (erreur) {
      if (!mounted) return;
      setState(() => _generation = false);
      _toast(erreur is ApiException ? erreur.message : 'Génération impossible.', couleur: K.danger);
    }
  }

  Future<void> _afficherResultat(Map<String, dynamic> resultat) async {
    final livre = '${resultat['livre'] ?? ''}';
    final prompts = '${resultat['prompt'] ?? ''}';
    final liens = LiensKit.fromJson(resultat['liens']);

    await showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: K.night,
        insetPadding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720, maxHeight: 620),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        '✨ Votre kit est prêt',
                        style: TextStyle(color: K.sand, fontSize: 19, fontWeight: FontWeight.w900),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Copier le texte',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: '$livre\n\n$prompts'));
                        _toast('Texte copié.', couleur: K.success);
                      },
                      icon: const Icon(Icons.copy_rounded, color: K.mist),
                    ),
                    IconButton(
                      tooltip: 'Ouvrir la version PDF',
                      onPressed: liens.livre == null
                          ? null
                          : () {
                              Navigator.pop(context);
                              ouvrirLienAvecRetour(context, liens.livre!);
                            },
                      icon: const Icon(Icons.picture_as_pdf_rounded, color: K.gold),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded, color: K.mist),
                    ),
                  ],
                ),
                const Divider(color: Colors.white12),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (livre.isNotEmpty) ...[
                          const Text(
                            '📘 Livre stratégique',
                            style: TextStyle(color: K.gold, fontSize: 15, fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 8),
                          HtmlWidget(livre, textStyle: const TextStyle(color: K.sand, height: 1.5)),
                          const SizedBox(height: 18),
                        ],
                        if (prompts.isNotEmpty) ...[
                          const Text(
                            '🤖 Prompts IA',
                            style: TextStyle(color: K.gold, fontSize: 15, fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 8),
                          HtmlWidget(prompts, textStyle: const TextStyle(color: K.sand, height: 1.5)),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (liens.aDesLiens)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (liens.livre != null)
                        OrButton(
                          label: 'Ouvrir le livre',
                          icone: Icons.menu_book_rounded,
                          hauteur: 42,
                          onPressed: () => ouvrirLienAvecRetour(context, liens.livre!),
                        ),
                      if (liens.prompts != null)
                        OrButton(
                          label: 'Ouvrir les prompts',
                          icone: Icons.auto_awesome_rounded,
                          hauteur: 42,
                          plein: false,
                          onPressed: () => ouvrirLienAvecRetour(context, liens.prompts!),
                        ),
                      if (liens.sheet != null)
                        OrButton(
                          label: 'Ouvrir le Sheet',
                          icone: Icons.table_chart_rounded,
                          hauteur: 42,
                          plein: false,
                          onPressed: () => ouvrirLienAvecRetour(context, liens.sheet!),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _ouvrirKit(Map<String, dynamic> kit) async {
    final kitId = '${kit['id']}';
    final jeton = '${kit['access_token'] ?? ''}';
    final sheet = kit['sheet_url'] == null ? null : '${kit['sheet_url']}';
    final aLivre = (kit['livre_html'] ?? '').toString().isNotEmpty;
    final aPrompts = (kit['prompts_html'] ?? '').toString().isNotEmpty;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: K.night,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${kit['nom_projet'] ?? kit['secteur_client'] ?? 'Mon kit'}',
                style: const TextStyle(color: K.sand, fontSize: 17, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                '${offreParApiType('${kit['produit_type'] ?? 'livre'}').titre} · ${_dateCourte(kit['created_at'])}',
                style: const TextStyle(color: K.mist, fontSize: 11.5),
              ),
              const SizedBox(height: 14),
              if (aLivre)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.menu_book_rounded, color: K.gold),
                  title: const Text('Livre stratégique', style: TextStyle(color: K.sand)),
                  subtitle: const Text('Consultation + PDF', style: TextStyle(color: K.mist, fontSize: 11)),
                  trailing: const Icon(Icons.open_in_new_rounded, color: K.mist, size: 18),
                  onTap: () => ouvrirLienAvecRetour(
                    context,
                    AppConfig.lienKit(kitId: kitId, jeton: jeton, type: 'livre'),
                  ),
                ),
              if (aPrompts)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.auto_awesome_rounded, color: K.gold),
                  title: const Text('Prompts IA', style: TextStyle(color: K.sand)),
                  subtitle: const Text('Prêts à copier', style: TextStyle(color: K.mist, fontSize: 11)),
                  trailing: const Icon(Icons.open_in_new_rounded, color: K.mist, size: 18),
                  onTap: () => ouvrirLienAvecRetour(
                    context,
                    AppConfig.lienKit(kitId: kitId, jeton: jeton, type: 'prompt'),
                  ),
                ),
              if (sheet != null && sheet.startsWith('http'))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.table_chart_rounded, color: K.gold),
                  title: const Text('Google Sheet', style: TextStyle(color: K.sand)),
                  subtitle: const Text('Tableau de gestion', style: TextStyle(color: K.mist, fontSize: 11)),
                  trailing: const Icon(Icons.open_in_new_rounded, color: K.mist, size: 18),
                  onTap: () => ouvrirLienAvecRetour(context, sheet),
                ),
              const SizedBox(height: 8),
              const AideWhatsApp(pleinLargeur: true),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final utilisateur = Supabase.instance.client.auth.currentUser;

    return Scaffold(
      body: PatternBackground(
        child: SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            child: Column(
              children: [
                const AppHeader(),
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 880),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 110),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Mon espace',
                                  style: TextStyle(
                                    color: K.sand,
                                    fontSize: 26,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                decoration: BoxDecoration(
                                  color: K.gold,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '$_credits crédit${_credits > 1 ? 's' : ''}',
                                  style: const TextStyle(
                                    color: K.night,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                tooltip: 'Mes kits',
                                onPressed: _chargerTout,
                                icon: const Icon(Icons.refresh_rounded, color: K.gold),
                              ),
                              IconButton(
                                tooltip: 'Se déconnecter',
                                onPressed: _deconnexion,
                                icon: const Icon(Icons.logout_rounded, color: K.mist),
                              ),
                            ],
                          ),
                          Text(
                            utilisateur?.email ?? '',
                            style: TextStyle(color: K.mist.withValues(alpha: 0.8), fontSize: 11.5),
                          ),
                          const SizedBox(height: 18),
                          if (_admin) ...[
                            _carteAdmin(),
                            const SizedBox(height: 14),
                          ],
                          _carteCommandes(),
                          const SizedBox(height: 14),
                          _carteKits(),
                          const SizedBox(height: 14),
                          _carteRegeneration(),
                          const SizedBox(height: 20),
                          const AideWhatsApp(pleinLargeur: true),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: const SiteAssistantChat(),
    );
  }

  Widget _carteAdmin() {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Icon(Icons.movie_filter_rounded, color: K.gold, size: 26),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Agence Vidéo IA',
                  style: TextStyle(color: K.sand, fontWeight: FontWeight.w800, fontSize: 14),
                ),
                Text(
                  '4 agents : décorticage, sous-titres, copy, distribution',
                  style: TextStyle(color: K.mist, fontSize: 11),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pushNamed(context, '/admin-videos'),
            child: const Text('Ouvrir', style: TextStyle(color: K.gold, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  Widget _carteCommandes() {
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Mes commandes',
                style: TextStyle(color: K.sand, fontSize: 16, fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => Navigator.pushNamed(context, '/commande'),
                child: const Text('Nouvelle commande', style: TextStyle(color: K.gold, fontSize: 12)),
              ),
            ],
          ),
          if (_chargement)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: CircularProgressIndicator(color: K.gold)),
            )
          else if (_commandes.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Text(
                'Aucune commande pour l\'instant. Choisissez votre kit métier et recevez tout en 2 minutes.',
                style: TextStyle(color: K.mist, fontSize: 12.5, height: 1.5),
              ),
            )
          else
            for (final commande in _commandes)
              InkWell(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ConfirmationPage(
                      orderId: commande.id,
                      nomProjet: commande.nomProjet,
                      metier: commande.metier,
                      montant: commande.montant,
                    ),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              commande.nomProjet,
                              style: const TextStyle(color: K.sand, fontSize: 13, fontWeight: FontWeight.w700),
                            ),
                            Text(
              '${commande.metier} · ${AppConfig.fcfa(commande.montant)} · ${_dateCourte(commande.createdAt)}',
              style: const TextStyle(color: K.mist, fontSize: 10.5),
            ),
                          ],
                        ),
                      ),
                      _statut(commande.statut),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }

  Widget _statut(String statut) {
    final (libelle, couleur) = switch (statut) {
      'LIVRE' => ('Livré', K.success),
      'PAYE' => ('Payé', K.gold),
      'EN_COURS' => ('Génération', K.gold),
      'ERREUR' => ('Erreur', K.danger),
      'ECHEC' => ('Échec', K.danger),
      _ => ('En attente', K.mist),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: couleur.withValues(alpha: 0.4)),
      ),
      child: Text(libelle, style: TextStyle(color: couleur, fontSize: 10, fontWeight: FontWeight.w800)),
    );
  }

  Widget _carteKits() {
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Mes kits',
            style: TextStyle(color: K.sand, fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          if (_kits.isEmpty)
            const Text(
              'Vos kits générés apparaîtront ici, avec leurs liens de consultation.',
              style: TextStyle(color: K.mist, fontSize: 12.5, height: 1.5),
            )
          else
            for (final kit in _kits)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.folder_open_rounded, color: K.gold, size: 22),
                title: Text(
                  '${kit['nom_projet'] ?? kit['secteur_client'] ?? 'Kit'}',
                  style: const TextStyle(color: K.sand, fontSize: 13, fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  '${_dateCourte(kit['created_at'])} · ${kit['status']}',
                  style: const TextStyle(color: K.mist, fontSize: 10.5),
                ),
                trailing: const Icon(Icons.chevron_right_rounded, color: K.mist),
                onTap: () => _ouvrirKit(kit),
              ),
        ],
      ),
    );
  }

  Widget _carteRegeneration() {
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Régénérer un kit',
            style: TextStyle(color: K.sand, fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          const Text(
            'Utilisez vos crédits pour générer une nouvelle version avec d\'autres précisions.',
            style: TextStyle(color: K.mist, fontSize: 12, height: 1.5),
          ),
          const SizedBox(height: 14),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _metierCode,
              isExpanded: true,
              dropdownColor: K.night,
              style: const TextStyle(color: K.sand, fontSize: 13),
              items: [
                for (final kit in kitsMetiers)
                  DropdownMenuItem(value: kit.code, child: Text('${kit.emoji}  ${kit.label}')),
              ],
              onChanged: (valeur) {
                if (valeur != null) setState(() => _metierCode = valeur);
              },
            ),
          ),
          const Divider(color: Colors.white12),
          DropdownButtonHideUnderline(
            child: DropdownButton<Offre>(
              value: _offre,
              isExpanded: true,
              dropdownColor: K.night,
              style: const TextStyle(color: K.sand, fontSize: 13),
              items: [
                for (final offre in offres)
                  DropdownMenuItem(
                    value: offre,
                    child: Text('${offre.titre} — ${offre.prixAffiche} (${offre.credits} crédit)'),
                  ),
              ],
              onChanged: (valeur) {
                if (valeur != null) setState(() => _offre = valeur);
              },
            ),
          ),
          const Divider(color: Colors.white12),
          DropdownButtonHideUnderline(
            child: DropdownButton<Pays>(
              value: _pays,
              isExpanded: true,
              dropdownColor: K.night,
              style: const TextStyle(color: K.sand, fontSize: 13),
              items: [
                for (final pays in paysAfricains)
                  DropdownMenuItem(value: pays, child: Text('${pays.drapeau}  ${pays.nom}')),
              ],
              onChanged: (valeur) {
                if (valeur != null) setState(() => _pays = valeur);
              },
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nomProjet,
            style: const TextStyle(color: K.sand),
            decoration: champ(label: 'Nom du projet', icone: Icons.storefront_rounded),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _precisions,
            maxLines: 2,
            style: const TextStyle(color: K.sand),
            decoration: champ(
              label: 'Précisions (optionnel)',
              icone: Icons.notes_rounded,
            ),
          ),
          const SizedBox(height: 14),
          OrButton(
            label: 'Générer avec ${_offre.credits} crédit${_offre.credits > 1 ? 's' : ''}',
            icone: Icons.auto_awesome_rounded,
            chargement: _generation,
            onPressed: _regenerer,
          ),
          const SizedBox(height: 6),
          Text(
            'Crédits disponibles : $_credits',
            style: const TextStyle(color: K.mist, fontSize: 11),
          ),
        ],
      ),
    );
  }

  String _dateCourte(dynamic valeur) {
    final date = valeur is DateTime ? valeur : DateTime.tryParse('$valeur');
    if (date == null) return '—';
    final jour = date.day.toString().padLeft(2, '0');
    final mois = date.month.toString().padLeft(2, '0');
    return '$jour/$mois/${date.year}';
  }
}
