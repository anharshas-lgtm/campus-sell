/// Builds resized / optimised Cloudinary delivery URLs from a stored original URL.
///
/// Original: https://res.cloudinary.com/<cloud>/image/upload/v123/abc.jpg
/// Thumb:    https://res.cloudinary.com/<cloud>/image/upload/c_limit,w_500,q_auto,f_auto/v123/abc.jpg
///
/// Firestore keeps storing the original `secure_url`; these variants are
/// derived at display time, so existing ads get thumbnails automatically.
/// Non-Cloudinary URLs are returned unchanged.
class CloudinaryUrl {
  CloudinaryUrl._();

  static const String _host = 'res.cloudinary.com';
  static const String _marker = '/image/upload/';

  /// Home grid cards (small, loads fast).
  static String thumb(String url) =>
      _apply(url, 'c_limit,w_500,q_auto,f_auto');

  /// Detail screen carousel.
  static String medium(String url) =>
      _apply(url, 'c_limit,w_1080,q_auto,f_auto');

  /// Full-screen zoom viewer.
  static String large(String url) =>
      _apply(url, 'c_limit,w_1600,q_auto,f_auto');

  static String _apply(String url, String transformation) {
    if (!url.contains(_host)) return url;
    final index = url.indexOf(_marker);
    if (index == -1) return url;
    final insertAt = index + _marker.length;
    return '${url.substring(0, insertAt)}$transformation/'
        '${url.substring(insertAt)}';
  }
}