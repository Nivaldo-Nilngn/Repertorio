/// Conditional export: picks the web implementation when running in a browser,
/// and a safe no-op stub when running on Android/iOS.
///
/// dart.library.html is only available in web targets.
export 'midi_service_mobile.dart'
    if (dart.library.html) 'midi_service_web.dart';
