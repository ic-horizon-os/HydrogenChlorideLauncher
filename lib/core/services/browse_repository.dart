import '../demo/demo_data.dart';
import '../models/browse_item.dart';

enum BrowseSort { popular, recent, name }

class BrowseRepository {
  BrowseRepository({List<BrowseItem>? items})
    : _items = items ?? DemoData.buildBrowseItems();

  final List<BrowseItem> _items;

  List<BrowseItem> get all => List<BrowseItem>.unmodifiable(_items);

  bool get isDemoSource => true;

  List<BrowseItem> query({
    required BrowseCategory category,
    String search = '',
    String? loader,
    BrowseSort sort = BrowseSort.popular,
  }) {
    final String needle = search.trim().toLowerCase();
    final List<BrowseItem> result = _items
        .where((BrowseItem item) {
          if (item.category != category) return false;
          if (loader != null &&
              loader.isNotEmpty &&
              !item.loaders.contains(loader)) {
            return false;
          }
          if (needle.isEmpty) return true;
          return item.name.toLowerCase().contains(needle) ||
              item.summary.toLowerCase().contains(needle) ||
              item.author.toLowerCase().contains(needle) ||
              item.tags.any((String tag) => tag.toLowerCase().contains(needle));
        })
        .toList(growable: false);

    final List<BrowseItem> sorted = List<BrowseItem>.of(result);
    switch (sort) {
      case BrowseSort.popular:
        sorted.sort(
          (BrowseItem a, BrowseItem b) => b.downloads.compareTo(a.downloads),
        );
      case BrowseSort.recent:
        sorted.sort(
          (BrowseItem a, BrowseItem b) => b.updatedAt.compareTo(a.updatedAt),
        );
      case BrowseSort.name:
        sorted.sort(
          (BrowseItem a, BrowseItem b) =>
              a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
    }
    return sorted;
  }

  List<String> loadersFor(BrowseCategory category) {
    final Set<String> loaders = <String>{};
    for (final BrowseItem item in _items) {
      if (item.category != category) continue;
      loaders.addAll(item.loaders);
    }
    final List<String> ordered = loaders.toList()
      ..sort((String a, String b) => a.compareTo(b));
    return ordered;
  }
}
