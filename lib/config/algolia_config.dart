

class AlgoliaConfig {
  // ← Replace with your actual Algolia credentials
  static const String appId     = 'S6HFLPZ3NQ';
  static const String searchKey = '036879aa902fed93e061b355ba8ce32c';
  // ← Index name must match what Firebase Extension created
  // Usually same as Firestore collection name
  static const String campusIndex = 'campus_sell_main';

  static String get searchUrl =>
      'https://$appId-dsn.algolia.net/1/indexes/$campusIndex/query';
}