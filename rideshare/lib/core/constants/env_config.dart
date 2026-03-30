class EnvConfig {
  static const bool isProduction = bool.fromEnvironment(
    'dart.vm.product',
    defaultValue: false,
  );

  static const String googleMapsApiKey = isProduction
      ? 'AIzaSyBS4ULytH5msEGRECGedllgf3ziF1Q5Itw'
      : 'AIzaSyBS4ULytH5msEGRECGedllgf3ziF1Q5Itw';

  static const String googleMapsApiKeyAndroid = isProduction
      ? 'AIzaSyBS4ULytH5msEGRECGedllgf3ziF1Q5Itw'
      : 'AIzaSyBS4ULytH5msEGRECGedllgf3ziF1Q5Itw';

  static const String googleMapsApiKeyIOS = isProduction
      ? 'AIzaSyBS4ULytH5msEGRECGedllgf3ziF1Q5Itw'
      : 'AIzaSyBS4ULytH5msEGRECGedllgf3ziF1Q5Itw';
}
