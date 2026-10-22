enum Flavor { dev, prod }

/// App-wide configuration resolved once at startup by the flavor-specific
/// entrypoint (`main_dev.dart` / `main_prod.dart`) via [AppConfig.init].
/// Mirrors Dad-mobile's `lib/core/config/app_config.dart` exactly.
class AppConfig {
  AppConfig._({required this.flavor, required this.apiBaseUrl});

  final Flavor flavor;
  final String apiBaseUrl;

  static AppConfig? _instance;

  static AppConfig get instance {
    assert(_instance != null, 'AppConfig.init() must be called before use');
    return _instance!;
  }

  static void init(Flavor flavor) {
    _instance = AppConfig._(flavor: flavor, apiBaseUrl: _resolveBaseUrl(flavor));
  }

  static String _resolveBaseUrl(Flavor flavor) {
    switch (flavor) {
      case Flavor.prod:
        return 'https://pypecrm.com/api';
      case Flavor.dev:
        // Android reaches the host via `adb reverse tcp:5001 tcp:5001` —
        // run that before `flutter run -t lib/main_dev.dart`.
        return 'http://localhost:5001/api';
    }
  }

  bool get isProd => flavor == Flavor.prod;
}
