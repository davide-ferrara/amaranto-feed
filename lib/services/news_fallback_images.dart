import 'dart:math';

/// Deals every fallback once per shuffled cycle and keeps each article stable.
class NewsFallbackImages {
  NewsFallbackImages({Random? random}) : _random = random ?? Random();

  static const assets = [
    'assets/images/news_fallback_stadium.png',
    'assets/images/news_fallback_stand.png',
    'assets/images/news_fallback_corner.png',
    'assets/images/news_fallback_curva_front.png',
    'assets/images/news_fallback_curva_angle.png',
  ];

  final Random _random;
  final Map<String, String> _articles = {};
  final List<String> _remaining = [];
  String? _lastImage;

  String forArticle(String url) => _articles.putIfAbsent(url, () {
    if (_remaining.isEmpty) {
      _remaining.addAll(assets.toList()..shuffle(_random));
      if (_remaining.last == _lastImage) {
        final first = _remaining.first;
        _remaining[0] = _remaining.last;
        _remaining[_remaining.length - 1] = first;
      }
    }
    return _lastImage = _remaining.removeLast();
  });
}
