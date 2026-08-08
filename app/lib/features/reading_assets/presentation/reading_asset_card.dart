import 'package:app/features/reader/presentation/selection/reader_selection_adapter.dart';
import 'package:app/features/reader/domain/article.dart';
import 'package:app/features/reading_assets/data/reading_asset_repository.dart';
import 'package:app/features/reading_assets/domain/reading_asset.dart';
import 'package:app/features/reading_assets/presentation/asset_editor_controller.dart';
import 'package:app/features/reading_assets/presentation/delete_asset_dialog.dart';
import 'package:app/features/reading_assets/presentation/reading_asset_editor.dart';
import 'package:app/features/reading_assets/presentation/tag_management_sheet.dart';
import 'package:flutter/material.dart';

class ReadingAssetCardRequestPresenter {
  const ReadingAssetCardRequestPresenter({required this.repository});
  final ReadingAssetRepository repository;

  Future<void> presentAssetRequest(
    BuildContext context, {
    required ReaderAssetCardRequest request,
    required Article article,
    required Future<void> Function() onReaderAssetsRefresh,
  }) async {
    if (article.id != request.articleId) {
      throw ArgumentError.value(
        article,
        'article',
        'must match request.articleId',
      );
    }
    final anchor = selectionToAnchor(article, request.selection);
    final asset = await repository.createHighlightAsset(
      articleId: anchor.articleId,
      startBlockId: anchor.startBlockId,
      endBlockId: anchor.endBlockId,
      startUtf16Offset: anchor.startUtf16Offset,
      endUtf16Offset: anchor.endUtf16Offset,
      selectedText: anchor.selectedText,
      contentChecksum: anchor.contentChecksum,
    );
    if (!context.mounted) return;
    await _show(
      context,
      asset: asset,
      startInEditing: true,
      onDeleted: (_) => onReaderAssetsRefresh(),
    );
  }

  Future<void> presentStandaloneNoteRequest(
    BuildContext context, {
    required ReaderStandaloneNoteDraftRequest request,
  }) async {
    final tags = await repository.readTags();
    if (!context.mounted) return;
    await _show(
      context,
      draft: AssetEditorDraft.newStandalone(
        initialTagIds: {
          for (final tag in tags)
            if (tag.isSystem) tag.id,
        },
      ),
      availableTags: tags,
      startInEditing: true,
    );
  }

  Future<void> _show(
    BuildContext context, {
    ReadingAsset? asset,
    AssetEditorDraft? draft,
    List<Tag>? availableTags,
    bool startInEditing = false,
    Future<void> Function(ReadingAsset)? onDeleted,
  }) => showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => ReadingAssetCard(
      asset: asset,
      draft: draft,
      availableTags: availableTags,
      repository: repository,
      startInEditing: startInEditing,
      onDeleted: onDeleted,
      onClosed: () => Navigator.of(dialogContext).pop(),
    ),
  );
}

class ReadingAssetCard extends StatefulWidget {
  const ReadingAssetCard({
    this.asset,
    this.draft,
    required this.repository,
    this.availableTags,
    this.startInEditing = false,
    this.onClosed,
    this.onSaved,
    this.onDeleted,
    super.key,
  }) : assert(asset != null || draft != null);
  final ReadingAsset? asset;
  final AssetEditorDraft? draft;
  final ReadingAssetRepository repository;
  final List<Tag>? availableTags;
  final bool startInEditing;
  final VoidCallback? onClosed;
  final ValueChanged<ReadingAsset>? onSaved;
  final Future<void> Function(ReadingAsset asset)? onDeleted;
  @override
  State<ReadingAssetCard> createState() => _ReadingAssetCardState();
}

class _ReadingAssetCardState extends State<ReadingAssetCard> {
  late final AssetEditorController _controller = AssetEditorController(
    repository: widget.repository,
    draft: widget.draft ?? AssetEditorDraft.fromAsset(widget.asset!),
  );
  final FocusNode _editorFocus = FocusNode();
  late ReadingAsset? _asset = widget.asset;
  late List<Tag> _tags = widget.availableTags ?? <Tag>[];
  late bool _editing = widget.startInEditing;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.availableTags == null) _loadTags();
    if (_editing) _restoreFocus();
  }

  @override
  void dispose() {
    _editorFocus.dispose();
    super.dispose();
  }

  Future<void> _loadTags() async {
    try {
      final tags = await widget.repository.readTags();
      if (mounted) setState(() => _tags = tags);
    } catch (_) {
      if (mounted) setState(() => _error = '标签加载失败');
    }
  }

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.black54,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _requestClose,
      child: Center(
        child: GestureDetector(
          onTap: () {},
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 560, maxHeight: 760),
            child: Card(
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: SingleChildScrollView(
                  child: _editing ? _editor() : _viewer(),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _header() => GestureDetector(
    key: const ValueKey('asset-card-drag-handle'),
    onVerticalDragEnd: (details) {
      if ((details.primaryVelocity ?? 0) > 250) _requestClose();
    },
    child: Row(
      children: [
        Expanded(
          child: Text(
            _asset == null ? '新建笔记' : _kind(_asset!.kind),
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        IconButton(
          tooltip: '关闭',
          onPressed: _requestClose,
          icon: const Icon(Icons.close),
        ),
      ],
    ),
  );
  Widget _round(IconData icon, String tooltip, VoidCallback onPressed) =>
      Container(
        decoration: const BoxDecoration(
          color: Colors.blue,
          shape: BoxShape.circle,
        ),
        child: IconButton(
          tooltip: tooltip,
          color: Colors.white,
          onPressed: onPressed,
          icon: Icon(icon),
        ),
      );
  Widget _errorView() => _error == null
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(
            _error!,
            key: const ValueKey('asset-card-error'),
            style: const TextStyle(color: Colors.red),
          ),
        );

  Widget _viewer() {
    final text = _asset?.anchor?.selectedText;
    final long = (text?.length ?? 0) > 120;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(),
        if (text != null)
          Text(
            long ? '${text.substring(0, 120)}…' : text,
            style: const TextStyle(fontSize: 18),
          ),
        if (long)
          TextButton(
            onPressed: () => _detail(text!),
            child: const Text('查看完整划线'),
          ),
        if (_asset?.noteContent?.trim().isNotEmpty ?? false)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text(_asset!.noteContent!),
          ),
        if (_asset?.anchor != null &&
            !(_asset?.noteContent?.trim().isNotEmpty ?? false))
          Align(
            alignment: Alignment.centerLeft,
            child: _round(Icons.edit, '添加笔记内容', _enterEdit),
          ),
        _errorView(),
        const SizedBox(height: 12),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: _openTags,
              icon: const Icon(Icons.tag),
              label: const Text('#标签'),
            ),
            const Spacer(),
            IconButton(
              tooltip: '删除',
              color: Colors.red,
              onPressed: _delete,
              icon: const Icon(Icons.delete_outline),
            ),
            _round(Icons.edit, '编辑', _enterEdit),
          ],
        ),
      ],
    );
  }

  Widget _editor() => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      _header(),
      ReadingAssetEditor(
        controller: _controller,
        focusNode: _editorFocus,
        saving: _saving,
        onOpenTags: _openTags,
        onSave: _save,
        onDelete: _asset == null ? null : _delete,
      ),
      _errorView(),
    ],
  );

  void _enterEdit() {
    setState(() {
      _editing = true;
      _error = null;
    });
    _restoreFocus();
  }

  void _restoreFocus() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted) _editorFocus.requestFocus();
  });
  Future<void> _openTags() async {
    FocusScope.of(context).unfocus();
    if (_tags.isEmpty && widget.availableTags == null) await _loadTags();
    if (!mounted) return;
    final selected = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => TagManagementSheet(
        tags: _tags,
        selectedTagIds: _controller.draft.selectedTagIds,
        lockedTagIds: {
          for (final tag in _tags)
            if (tag.isSystem) tag.id,
        },
        onConfirm: (ids) => Navigator.of(sheetContext).pop(ids),
        onCreateTag: (name) => widget.repository.createTag(name: name),
      ),
    );
    if (!mounted || selected == null) {
      if (_editing) _restoreFocus();
      return;
    }
    if (_editing) {
      setState(() => _controller.setSelectedTagIds(selected));
      _restoreFocus();
      return;
    }
    try {
      await widget.repository.setAssetTags(
        assetId: _asset!.id,
        tagIds: selected.toList(),
      );
      if (mounted) {
        setState(
          () => _asset = _copy(
            _asset!,
            _tags.where((tag) => selected.contains(tag.id)).toList(),
          ),
        );
      }
    } catch (_) {
      if (mounted) setState(() => _error = '标签保存失败，请重试');
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final saved = await _controller.save();
      if (!mounted) return;
      widget.onSaved?.call(saved);
      widget.onClosed?.call();
    } catch (_) {
      if (mounted) setState(() => _error = '保存失败，请重试');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    if (_asset == null || _saving || !await showDeleteAssetDialog(context)) {
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.deleteReadingAsset(_asset!.id);
      if (widget.onDeleted != null) {
        await widget.onDeleted!(_asset!);
      }
      if (mounted) {
        widget.onClosed?.call();
      }
    } catch (_) {
      if (mounted) setState(() => _error = '删除失败，请重试');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _requestClose() async {
    if (!_editing || !_controller.hasUnsavedChanges) {
      widget.onClosed?.call();
      return;
    }
    FocusScope.of(context).unfocus();
    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('放弃编辑'),
        content: const Text('尚有未保存的修改，确定放弃编辑吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('继续编辑'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('放弃编辑'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (discard == true) {
      widget.onClosed?.call();
    } else {
      _restoreFocus();
    }
  }

  Future<void> _detail(String text) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('完整划线'),
      content: SingleChildScrollView(child: SelectableText(text)),
    ),
  );
  ReadingAsset _copy(ReadingAsset asset, List<Tag> tags) => ReadingAsset(
    id: asset.id,
    ownerId: asset.ownerId,
    anchor: asset.anchor,
    noteContent: asset.noteContent,
    tags: List.unmodifiable(tags),
  );
  String _kind(ReadingAssetKind kind) => switch (kind) {
    ReadingAssetKind.highlightOnly => '划线',
    ReadingAssetKind.linkedNote => '划线与笔记',
    ReadingAssetKind.standaloneNote => '笔记',
  };
}
