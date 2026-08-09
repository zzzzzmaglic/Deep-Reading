import 'package:app/features/reading_assets/data/reading_asset_repository.dart';
import 'package:app/features/reading_assets/domain/reading_asset.dart';
import 'package:flutter/foundation.dart';

class ArticleAssetSummaryController extends ChangeNotifier {
  ArticleAssetSummaryController({
    required this.articleId,
    required this.repository,
  });

  final String articleId;
  final ReadingAssetRepository repository;

  List<ReadingAsset> _assets = const [];
  final Set<String> _selectedIds = <String>{};
  Object? _error;
  bool _loading = false;

  List<ReadingAsset> get assets => List.unmodifiable(_assets);
  Set<String> get selectedIds => Set.unmodifiable(_selectedIds);
  Object? get error => _error;
  bool get isLoading => _loading;

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _assets = await repository.readAssets(articleId: articleId);
    } catch (error) {
      _error = error;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void toggleSelection(String assetId) {
    if (_selectedIds.contains(assetId)) {
      _selectedIds.remove(assetId);
    } else {
      _selectedIds.add(assetId);
    }
    notifyListeners();
  }

  Future<void> deleteSelectedAssets(Set<String> assetIds) async {
    for (final assetId in assetIds) {
      await repository.deleteReadingAsset(assetId);
    }
    await load();
    _selectedIds.removeAll(assetIds);
    notifyListeners();
  }
}
