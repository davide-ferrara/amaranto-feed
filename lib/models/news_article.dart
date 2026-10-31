class NewsArticle {
  const NewsArticle({
    required this.title,
    required this.url,
    required this.source,
    required this.publishedAt,
    this.imageUrl,
    this.isOfficial = false,
    this.hasPublicationDate = true,
  });

  final String title;
  final String url;
  final String source;
  final DateTime publishedAt;
  final String? imageUrl;
  final bool isOfficial;
  final bool hasPublicationDate;
}
