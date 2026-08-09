import 'package:app/features/reading_assets/data/reading_asset_repository.dart';
import 'package:app/features/reading_assets/domain/reading_asset.dart';

class AssetEditorDraft {
  AssetEditorDraft({
    required this.originalAsset,
    required this.noteContent,
    this.articleId,
    required Set<String> selectedTagIds,
  }) : selectedTagIds = Set.unmodifiable(selectedTagIds),
       _originalNoteContent = originalAsset?.noteContent ?? '',
       _originalTagIds = Set.unmodifiable(
         originalAsset?.tags.map((tag) => tag.id).toSet() ?? const {},
       );

  factory AssetEditorDraft.fromAsset(ReadingAsset asset) {
    return AssetEditorDraft(
      originalAsset: asset,
      noteContent: asset.noteContent ?? '',
      articleId: asset.articleId,
      selectedTagIds: asset.tags.map((tag) => tag.id).toSet(),
    );
  }

  factory AssetEditorDraft.newStandalone({
    Set<String> initialTagIds = const {},
    String? articleId,
  }) {
    return AssetEditorDraft(
      originalAsset: null,
      noteContent: '',
      articleId: articleId,
      selectedTagIds: initialTagIds,
    );
  }

  final ReadingAsset? originalAsset;
  final String noteContent;
  final String? articleId;
  final Set<String> selectedTagIds;
  final String _originalNoteContent;
  final Set<String> _originalTagIds;

  String? get assetId => originalAsset?.id;

  ReadingAssetKind get kind => deriveReadingAssetKind(
    anchor: originalAsset?.anchor,
    noteContent: noteContent,
  );

  bool get hasUnsavedChanges =>
      noteContent.trim() != _originalNoteContent.trim() ||
      !_sameIds(selectedTagIds, _originalTagIds);

  AssetEditorDraft withNote(String value) {
    return AssetEditorDraft(
      originalAsset: originalAsset,
      noteContent: value,
      articleId: articleId,
      selectedTagIds: selectedTagIds,
    );
  }

  AssetEditorDraft withSelectedTagIds(Set<String> ids) {
    return AssetEditorDraft(
      originalAsset: originalAsset,
      noteContent: noteContent,
      articleId: articleId,
      selectedTagIds: ids,
    );
  }

  static bool _sameIds(Set<String> left, Set<String> right) {
    if (left.length != right.length) return false;
    return left.containsAll(right);
  }
}

class AssetEditorController {
  factory AssetEditorController({
    required ReadingAssetRepository repository,
    required AssetEditorDraft draft,
  }) => AssetEditorController._(repository: repository, draft: draft);

  AssetEditorController._({required this.repository, required this._draft});

  final ReadingAssetRepository repository;
  AssetEditorDraft _draft;

  AssetEditorDraft get draft => _draft;

  bool get hasUnsavedChanges => _draft.hasUnsavedChanges;

  void setNoteContent(String value) {
    _draft = _draft.withNote(value);
  }

  void setSelectedTagIds(Set<String> ids) {
    _draft = _draft.withSelectedTagIds(ids);
  }

  void syncFromAsset(ReadingAsset asset) {
    _draft = AssetEditorDraft.fromAsset(asset);
  }

  Future<ReadingAsset> save() async {
    final noteContent = _draft.noteContent.trim();
    final existingAsset = _draft.originalAsset;
    return existingAsset == null
        ? repository.createStandaloneNoteWithTags(
            noteContent: noteContent,
            tagIds: _draft.selectedTagIds.toList(growable: false),
            articleId: _draft.articleId,
          )
        : repository.saveReadingAsset(
            assetId: existingAsset.id,
            noteContent: noteContent.isEmpty ? null : noteContent,
            tagIds: _draft.selectedTagIds.toList(growable: false),
          );
  }
}
