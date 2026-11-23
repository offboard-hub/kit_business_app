import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import '../core/theme.dart';

/// Contrôleur de la salle Jitsi : chaque bouton Flutter pilote
/// l'IFrame API via le pont JavaScript `ebookliveJitsi` (web/index.html).
class JitsiController {
  const JitsiController();

  Future<void> basculerMicro() => _commande('toggleAudio');

  Future<void> basculerCamera() => _commande('toggleVideo');

  Future<void> partagerEcran() => _commande('toggleShareScreen');

  Future<void> quitter() async {
    final pont = _pont();
    if (pont == null) return;
    pont.callMethod('dispose'.toJS);
  }

  Future<void> _commande(String nom) async {
    final pont = _pont();
    if (pont == null) return;
    pont.callMethod('command'.toJS, nom.toJS);
  }

  JSObject? _pont() {
    final pont = globalContext['ebookliveJitsi'];
    if (pont == null || pont.isUndefinedOrNull) return null;
    return pont as JSObject;
  }
}

/// Intègre la salle Jitsi Meet dans un `HtmlElementView`.
Widget construireJitsi({
  Key? key,
  required String roomId,
  required String nomAffiche,
  required JitsiController controleur,
  bool moderateur = false,
}) {
  return _JitsiWeb(
    key: key,
    roomId: roomId,
    nomAffiche: nomAffiche,
    moderateur: moderateur,
  );
}

class _JitsiWeb extends StatefulWidget {
  const _JitsiWeb({
    super.key,
    required this.roomId,
    required this.nomAffiche,
    required this.moderateur,
  });

  final String roomId;
  final String nomAffiche;
  final bool moderateur;

  @override
  State<_JitsiWeb> createState() => _JitsiWebState();
}

class _JitsiWebState extends State<_JitsiWeb> {
  late final String _viewType;
  late final web.HTMLDivElement _conteneur;
  bool _pret = false;

  String get _nomSalle => 'ebooklive-${widget.roomId}';

  @override
  void initState() {
    super.initState();
    _viewType = 'jitsi-${widget.roomId}-${DateTime.now().microsecondsSinceEpoch}';
    _conteneur = web.document.createElement('div') as web.HTMLDivElement;
    _conteneur.id = 'jitsi-conteneur-${widget.roomId}';
    _conteneur.style
      ..width = '100%'
      ..height = '100%'
      ..border = 'none';

    ui_web.platformViewRegistry.registerViewFactory(
      _viewType,
      (int viewId) => _conteneur,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) => _demarrer());
  }

  Future<void> _demarrer() async {
    if (!mounted) return;
    await _chargerJitsi();
    if (!mounted) return;
    await Future<void>.delayed(const Duration(milliseconds: 150));
    if (!mounted) return;

    final options = <String, Object>{
      'roomName': _nomSalle,
      'userInfo': <String, Object>{
        'displayName': widget.nomAffiche.isEmpty ? 'Invité e-booklive' : widget.nomAffiche,
      },
      'configOverwrite': <String, Object>{
        'prejoinPageEnabled': false,
        'prejoinConfig': <String, Object>{'enabled': false},
        'startWithAudioMuted': true,
        'startWithVideoMuted': !widget.moderateur,
        'disableDeepLinking': true,
        'toolbarButtons': <String>[
          'microphone',
          'camera',
          'desktop',
          'chat',
          'participants-pane',
          'tileview',
          'fullscreen',
          'hangup',
        ],
      },
      'interfaceConfigOverwrite': <String, Object>{
        'SHOW_JITSI_WATERMARK': false,
        'SHOW_BRAND_WATERMARK': false,
        'DEFAULT_BACKGROUND': '#090D16',
        'DISABLE_JOIN_LEAVE_NOTIFICATIONS': false,
        'MOBILE_APP_PROMO': false,
      },
    };

    final pont = globalContext['ebookliveJitsi'];
    var cree = false;
    if (pont != null && !pont.isUndefinedOrNull) {
      try {
        final resultat = (pont as JSObject).callMethod(
          'create'.toJS,
          'meet.jit.si'.toJS,
          _conteneur.id.toJS,
          jsonEncode(options).toJS,
        );
        cree = resultat.dartify() == true;
      } catch (_) {
        cree = false;
      }
    }

    if (!cree) _iframeDeSecours();
    if (mounted) setState(() => _pret = true);
  }

  void _iframeDeSecours() {
    final iframe = web.document.createElement('iframe') as web.HTMLIFrameElement;
    iframe.src = 'https://meet.jit.si/${Uri.encodeComponent(_nomSalle)}';
    iframe.allow = 'camera; microphone; display-capture; fullscreen; autoplay';
    iframe.style
      ..width = '100%'
      ..height = '100%'
      ..border = '0';
    _conteneur.append(iframe);
  }

  /// Charge l'IFrame API Jitsi uniquement quand la régie s'ouvre.
  Future<void> _chargerJitsi() async {
    final existant = globalContext['JitsiMeetExternalAPI'];
    if (existant != null && !existant.isUndefinedOrNull) return;

    final script = web.document.createElement('script') as web.HTMLScriptElement;
    script.src = 'https://meet.jit.si/external_api.js';
    script.async = true;
    web.document.head!.append(script);

    for (var i = 0; i < 30; i++) {
      final api = globalContext['JitsiMeetExternalAPI'];
      if (api != null && !api.isUndefinedOrNull) return;
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
  }

  @override
  void dispose() {
    final pont = globalContext['ebookliveJitsi'];
    if (pont != null && !pont.isUndefinedOrNull) {
      try {
        (pont as JSObject).callMethod('dispose'.toJS);
      } catch (_) {}
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: ColoredBox(
        color: K.bg,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            HtmlElementView(viewType: _viewType),
            if (!_pret)
              const Center(
                child: SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(color: K.or, strokeWidth: 2.4),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
