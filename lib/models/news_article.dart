class NewsArticle {
  const NewsArticle({
    required this.title,
    required this.url,
    required this.source,
    required this.publishedAt,
    this.imageUrl,
  });

  final String title;
  final String url;
  final String source;
  final DateTime publishedAt;
  final String? imageUrl;
}
