/// Conditional export: uses Web Audio API on web browser, and mobile capture on native.
export 'audio_capture_mobile.dart'
    if (dart.library.html) 'audio_capture_web.dart';
