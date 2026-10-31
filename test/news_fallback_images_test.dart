import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:amaranto_feed/services/news_fallback_images.dart';

void main() {
  test(
    'uses all five images before repeating, with no cycle boundary repeats',
    () {
      final images = NewsFallbackImages(random: Random(42));
      final selected = List.generate(
        50,
        (index) => images.forArticle('article-$index'),
      );
      for (var index = 0; index < selected.length; index += 5) {
        expect(
          selected.sublist(index, index + 5).toSet(),
          NewsFallbackImages.assets.toSet(),
        );
      }
      for (var index = 1; index < selected.length; index++) {
        expect(selected[index], isNot(selected[index - 1]));
      }
    },
  );

  test('rebuilding or revisiting an article keeps its image and does not use another turn', () {
    final images = NewsFallbackImages(random: Random(2));
    final first = images.forArticle('first');
    for (var index = 0; index < 10; index++) {
      expect(images.forArticle('first'), first);
    }
    final next = List.generate(4, (index) => images.forArticle('next-$index'));
    expect({first, ...next}.length, 5);
    expect(images.forArticle('first'), first);
  });
}
