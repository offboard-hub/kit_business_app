import 'package:flutter/material.dart';

import '../core/theme.dart';
import 'whatsapp.dart';

/// En-tête commun à toutes les pages publiques.
class AppHeader extends StatelessWidget {
  const AppHeader({super.key, this.afficherAide = true});

  final bool afficherAide;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, contraintes) {
        final large = contraintes.maxWidth > 620;

        return Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 6),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      children: [
                        const AppLogo(size: 38),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'KIT BUSINESS',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: K.sand,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 15,
                                  letterSpacing: 1.4,
                                ),
                              ),
                              if (large)
                                const Text(
                                  'Kits métiers clés en main • Afrique',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: K.mist, fontSize: 10.5),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (afficherAide) AideWhatsApp(compact: !large),
              const SizedBox(width: 6),
              OutlinedButton.icon(
                onPressed: () => Navigator.pushNamed(context, '/mon-espace'),
                icon: const Icon(Icons.person_rounded, size: 17, color: K.gold),
                label: large
                    ? const Text(
                        'Mon espace',
                        style: TextStyle(color: K.gold, fontWeight: FontWeight.w700, fontSize: 13),
                      )
                    : const SizedBox.shrink(),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: K.gold.withValues(alpha: 0.5)),
                  padding: EdgeInsets.symmetric(horizontal: large ? 16 : 10, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
