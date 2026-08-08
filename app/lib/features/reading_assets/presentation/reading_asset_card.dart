import 'dart:math' as math;

import 'package:app/features/reading_assets/data/reading_asset_repository.dart';
import 'package:app/features/reading_assets/domain/reading_asset.dart';
import 'package:app/features/reading_assets/presentation/asset_editor_controller.dart';
import 'package:app/features/reading_assets/presentation/delete_asset_dialog.dart';
import 'package:app/features/reading_assets/presentation/reading_asset_editor.dart';
import 'package:app/features/reading_assets/presentation/tag_management_sheet.dart';
import 'package:app/features/reader/presentation/selection/reader_selection_adapter.dart';
import 'package:flutter/material.dart';

typedef ReadingAssetCardRequestLoader =
    Future<ReadingAsset> Function(ReaderAssetCardRequest request);
typedef StandaloneNoteCardRequestLoader =
    Future<ReadingAsset> Function(ReaderStandaloneNoteDraftRequest request);

class ReadingAssetCardRequestPresenter {
  const ReadingAssetCardRequestPresenter({required this.repository});

  final ReadingAssetRepository repository;

  Future<void> presentAssetRequest(
    BuildContext context, {
    required ReaderAssetCardRequest request,
    required ReadingAssetCardRequestLoader load,
    ValueChanged<ReadingAsset>? onHighlightRemoved,
  }) async {
    final asset = await load(request);
    if (!context.mounted) return;
    await _show(context, asset, onHighlightRemoved: onHighlightRemoved);
  }

  Future<void> presentStandaloneNoteRequest(
    BuildContext context, {
    required ReaderStandaloneNoteDraftRequest request,
    required StandaloneNoteCardRequestLoader load,
  }) async {
    final asset = await load(request);
    if (!context.mounted) return;
    await _show(context, asset);
  }

  Future<void> _show(
    BuildContext context,
    ReadingAsset asset, {
    ValueChanged<ReadingAsset>? onHighlightRemoved,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ReadingAssetCard(
        asset: asset,
        repository: repository,
        onHighlightRemoved: onHighlightRemoved,
        onClosed: () => Navigator.of(context).pop(),
      ),
    );
  }
}

class ReadingAssetCard extends StatefulWidget {
  const ReadingAssetCard({
    required this.asset,
    required this.repository,
    this.availableTags,
    this.onClosed,
    this.onSaved,
    this.onHighlightRemoved,
    super.key,
  });

  final ReadingAsset asset;
  final ReadingAssetRepository repository;
  final List<Tag>? availableTags;
  final VoidCallback? onClosed;
  final ValueChanged<ReadingAsset>? onSaved;
  final ValueChanged<ReadingAsset>? onHighlightRemoved;

  @override
  State<ReadingAssetCard> createState() => _ReadingAssetCardState();
}

class _ReadingAssetCardState extends State<ReadingAssetCard> {
  late final AssetEditorController _controller = AssetEditorController(
    repository: widget.repository,
    draft: AssetEditorDraft.fromAsset(widget.asset),
  );
  bool _editing = false;
  bool _busy = false;

  List<Tag> get _tags => widget.availableTags ?? widget.asset.tags;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _requestClose,
        child: Center(
          child: GestureDetector(
            onTap: () {},
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: math.min(560, MediaQuery.sizeOf(context).width - 32),
                maxHeight: MediaQuery.sizeOf(context).height - 80,
              ),
              child: Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: SingleChildScrollView(
                    child: _editing ? _buildEditor() : _buildViewer(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildViewer() {
    final anchorText = widget.asset.anchor?.selectedText;
    final isLong = (anchorText?.length ?? 0) > 120;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _kindLabel(widget.asset.kind),
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
        if (anchorText != null) ...[
          Text(
            isLong ? '${anchorText.substring(0, 120)}…' : anchorText,
            style: const TextStyle(fontSize: 18),
          ),
          if (isLong)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => _showFullHighlight(anchorText),
                child: const Text('查看完整划线'),
              ),
            ),
        ],
        if (widget.asset.noteContent?.trim().isNotEmpty ?? false)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text(widget.asset.noteContent!),
          )
        else if (widget.asset.anchor != null)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: OutlinedButton(
              onPressed: () => setState(() => _editing = true),
              child: const Text('添加笔记内容'),
            ),
          ),
        const SizedBox(height: 16),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: _openTags,
              icon: const Icon(Icons.tag),
              label: const Text('标签'),
            ),
            const Spacer(),
            IconButton(
              tooltip: '删除',
              onPressed: _delete,
              icon: const Icon(Icons.delete_outline),
            ),
            FilledButton(
              onPressed: () => setState(() => _editing = true),
              child: const Text('编辑'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEditor() {
    return ReadingAssetEditor(
      controller: _controller,
      onOpenTags: _openTags,
      onSave: _save,
      onDelete: _delete,
    );
  }

  Future<void> _openTags() async {
    final selected = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      builder: (context) => TagManagementSheet(
        tags: _tags,
        selectedTagIds: _editing
            ? _controller.draft.selectedTagIds
            : widget.asset.tags.map((tag) => tag.id).toSet(),
        lockedTagIds: {
          for (final tag in _tags)
            if (tag.isSystem) tag.id,
        },
        onConfirm: (ids) => Navigator.of(context).pop(ids),
        onCreateTag: (name) => widget.repository.createTag(name: name),
      ),
    );
    if (!mounted || selected == null) return;
    if (_editing) {
      setState(() => _controller.setSelectedTagIds(selected));
    } else {
      await widget.repository.setAssetTags(
        assetId: widget.asset.id,
        tagIds: selected.toList(growable: false),
      );
    }
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final saved = await _controller.save();
      if (!mounted) return;
      widget.onSaved?.call(saved);
      widget.onClosed?.call();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    if (_busy) return;
    final confirmed = await showDeleteAssetDialog(context);
    if (!confirmed || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.repository.deleteReadingAsset(widget.asset.id);
      if (!mounted) return;
      if (widget.asset.anchor != null) {
        widget.onHighlightRemoved?.call(widget.asset);
      }
      widget.onClosed?.call();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _requestClose() async {
    if (!_editing || !_controller.hasUnsavedChanges) {
      widget.onClosed?.call();
      return;
    }
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('放弃编辑'),
        content: const Text('尚有未保存的修改，确定放弃编辑吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('继续编辑'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('放弃编辑'),
          ),
        ],
      ),
    );
    if (discard == true && mounted) widget.onClosed?.call();
  }

  Future<void> _showFullHighlight(String text) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('完整划线'),
        content: SingleChildScrollView(child: SelectableText(text)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  String _kindLabel(ReadingAssetKind kind) {
    return switch (kind) {
      ReadingAssetKind.highlightOnly => '划线',
      ReadingAssetKind.linkedNote => '划线与笔记',
      ReadingAssetKind.standaloneNote => '笔记',
    };
  }
}
