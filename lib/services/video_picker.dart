// Point d'entrée conditionnel : implémentation web (package:web) ou stub.
export 'video_picker_model.dart';
export 'video_picker_stub.dart'
    if (dart.library.js_interop) 'video_picker_web.dart';
