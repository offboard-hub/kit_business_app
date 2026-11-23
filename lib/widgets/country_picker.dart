import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/countries.dart';
import '../core/theme.dart';

/// ============================================================================
///  SÉLECTEUR DE PAYS DU MONDE
///  Recherche instantanée (nom, code, devise, indicatif), drapeaux, et badge
///  de la route de paiement (SasPay dans la devise locale / Paddle EUR-USD).
/// ============================================================================

/// Ouvre la boîte de dialogue de sélection et mémorise le pays choisi.
Future<PaysMonde?> choisirPays(
  BuildContext context, {
  PaysMonde? selection,
}) async {
  final choisi = await showDialog<PaysMonde>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.72),
    builder: (context) => _DialoguePays(initial: selection ?? CountryStore.pays.value),
  );
  if (choisi != null) CountryStore.definir(choisi);
  return choisi;
}

/// Bouton compact affichant le pays sélectionné.
class PaysSelector extends StatelessWidget {
  const PaysSelector({
    super.key,
    this.compact = false,
    this.afficherDevise = true,
  });

  final bool compact;
  final bool afficherDevise;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<PaysMonde>(
      valueListenable: CountryStore.pays,
      builder: (context, pays, _) {
        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => choisirPays(context, selection: pays),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 10 : 13,
                vertical: compact ? 8 : 10,
              ),
              decoration: BoxDecoration(
                color: K.surface.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: K.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(pays.drapeau, style: TextStyle(fontSize: compact ? 16 : 18)),
                  SizedBox(width: compact ? 6 : 8),
                  Flexible(
                    child: Text(
                      compact ? pays.code : pays.nom,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: K.text,
                        fontSize: compact ? 12 : 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (afficherDevise && !compact) ...<Widget>[
                    const SizedBox(width: 6),
                    Text(
                      pays.devise,
                      style: const TextStyle(
                        color: K.faint,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                  const SizedBox(width: 4),
                  const Icon(Icons.keyboard_arrow_down_rounded, color: K.muted, size: 17),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Bandeau d'explication de la route de paiement.
class RoutePaiementBandeau extends StatelessWidget {
  const RoutePaiementBandeau({super.key, required this.pays, this.compact = false});

  final PaysMonde pays;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final sas = pays.viaSasPay;
    final couleur = sas ? K.or : K.emeraude;
    final texte = sas
        ? 'SasPay · débité en ${pays.devise} (mobile money ou carte)'
        : 'Paddle · facturé en ${pays.devisePaddle}, TVA gérée (≈ ${pays.devise} en local)';
    return Row(
      children: <Widget>[
        Icon(
          sas ? Icons.phone_android_rounded : Icons.credit_card_rounded,
          size: compact ? 13 : 15,
          color: couleur,
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            texte,
            style: TextStyle(
              color: compact ? K.faint : K.muted,
              fontSize: compact ? 10.5 : 11.5,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

class _DialoguePays extends StatefulWidget {
  const _DialoguePays({required this.initial});

  final PaysMonde initial;

  @override
  State<_DialoguePays> createState() => _DialoguePaysState();
}

class _DialoguePaysState extends State<_DialoguePays> {
  final TextEditingController _recherche = TextEditingController();
  late List<PaysMonde> _resultats;
  late PaysMonde _selection;

  @override
  void initState() {
    super.initState();
    _resultats = paysMonde;
    _selection = widget.initial;
  }

  @override
  void dispose() {
    _recherche.dispose();
    super.dispose();
  }

  void _filtrer(String requete) {
    setState(() => _resultats = rechercherPays(requete));
  }

  @override
  Widget build(BuildContext context) {
    final taille = MediaQuery.sizeOf(context);
    final largeur = math.min(560.0, taille.width - 28);
    final hauteur = math.min(660.0, taille.height * 0.82);

    return Dialog(
      insetPadding: const EdgeInsets.all(14),
      backgroundColor: Colors.transparent,
      child: Container(
        width: largeur,
        height: hauteur,
        decoration: BoxDecoration(
          color: K.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: K.borderLight),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.55),
              blurRadius: 40,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 10),
              child: Row(
                children: <Widget>[
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Votre pays',
                          style: TextStyle(
                            color: K.text,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          '23 pays en devise locale via SasPay · reste du monde via Paddle.',
                          style: TextStyle(color: K.muted, fontSize: 11.5),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Fermer',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: K.muted, size: 20),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
              child: TextField(
                controller: _recherche,
                autofocus: true,
                onChanged: _filtrer,
                style: const TextStyle(color: K.text, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Rechercher un pays, une devise…',
                  hintStyle: const TextStyle(color: K.faint, fontSize: 13),
                  prefixIcon: const Icon(Icons.search_rounded, color: K.faint, size: 20),
                  suffixIcon: _recherche.text.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _recherche.clear();
                            _filtrer('');
                          },
                          icon: const Icon(Icons.close_rounded, color: K.faint, size: 17),
                        ),
                  filled: true,
                  fillColor: K.bg.withValues(alpha: 0.55),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: K.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: K.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: K.or, width: 1.4),
                  ),
                ),
              ),
            ),
            Expanded(
              child: _resultats.isEmpty
                  ? const _AucunPays()
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
                      itemCount: _resultats.length,
                      itemBuilder: (context, index) {
                        final pays = _resultats[index];
                        return _LignePays(
                          pays: pays,
                          selectionne: pays.code == _selection.code,
                          onTap: () => Navigator.pop(context, pays),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LignePays extends StatelessWidget {
  const _LignePays({
    required this.pays,
    required this.selectionne,
    required this.onTap,
  });

  final PaysMonde pays;
  final bool selectionne;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          margin: const EdgeInsets.only(bottom: 3),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: selectionne
                ? K.or.withValues(alpha: 0.09)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selectionne
                  ? K.or.withValues(alpha: 0.45)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            children: <Widget>[
              SizedBox(
                width: 32,
                child: Text(pays.drapeau, style: const TextStyle(fontSize: 21)),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      pays.nom,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: selectionne ? K.text : K.text.withValues(alpha: 0.92),
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${pays.devise} · ${pays.indicatif}',
                      style: const TextStyle(color: K.faint, fontSize: 10.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              BadgeFournisseur(
                nom: pays.viaSasPay ? 'SasPay' : 'Paddle',
                actif: pays.viaSasPay,
              ),
              const SizedBox(width: 8),
              Icon(
                selectionne
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 19,
                color: selectionne ? K.or : K.borderLight,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AucunPays extends StatelessWidget {
  const _AucunPays();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.travel_explore_rounded, color: K.faint, size: 32),
            SizedBox(height: 10),
            Text(
              'Aucun pays ne correspond à cette recherche.',
              textAlign: TextAlign.center,
              style: TextStyle(color: K.muted, fontSize: 12.5),
            ),
          ],
        ),
      ),
    );
  }
}
