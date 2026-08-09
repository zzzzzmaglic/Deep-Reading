import 'package:app/core/router/app_router.dart';
import 'package:app/features/reader/presentation/article_asset_summary_controller.dart';
import 'package:app/features/reading_assets/data/reading_asset_repository.dart';
import 'package:app/features/reading_assets/domain/reading_asset.dart';
import 'package:app/features/reading_assets/presentation/delete_asset_dialog.dart';
import 'package:app/features/reading_assets/presentation/reading_asset_card.dart';
import 'package:flutter/material.dart';

class ArticleAssetSummaryScreen extends StatefulWidget {
  const ArticleAssetSummaryScreen({
    required this.articleId,
    required this.repository,
    super.key,
  });

  final String articleId;
  final ReadingAssetRepository repository;

  @override
  State<ArticleAssetSummaryScreen> createState() =>
      _ArticleAssetSummaryScreenState();
}

class _ArticleAssetSummaryScreenState extends State<ArticleAssetSummaryScreen> {
  late final ArticleAssetSummaryController _controller =
      ArticleAssetSummaryController(
        articleId: widget.articleId,
        repository: widget.repository,
      )..load();
  String? _actionError;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => Scaffold(
        appBar: AppBar(leading: const BackButton(), title: const Text('标注与笔记')),
        body: _body(context),
        bottomNavigationBar: _controller.selectedIds.isEmpty
            ? null
            : SafeArea(
                minimum: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: FilledButton.icon(
                  key: const Key('article-summary-delete'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                  ),
                  onPressed: _confirmDelete,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('删除'),
                ),
              ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    if (_controller.isLoading && _controller.assets.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_controller.error != null && _controller.assets.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('标注与笔记加载失败'),
            const SizedBox(height: 12),
            FilledButton(onPressed: _controller.load, child: const Text('重试')),
          ],
        ),
      );
    }
    if (_controller.assets.isEmpty) {
      return const Center(child: Text('暂无标注与笔记'));
    }
    return Column(
      children: [
        if (_actionError != null)
          MaterialBanner(
            content: Text(_actionError!),
            actions: [
              TextButton(
                onPressed: () => setState(() => _actionError = null),
                child: const Text('关闭'),
              ),
            ],
          ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
            itemCount: _controller.assets.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) =>
                _buildAssetItem(context, _controller.assets[index]),
          ),
        ),
      ],
    );
  }

  Widget _buildAssetItem(BuildContext context, ReadingAsset asset) {
    final selected = _controller.selectedIds.contains(asset.id);
    final anchor = asset.anchor;
    final note = asset.noteContent;
    return Dismissible(
      key: ValueKey('summary-asset-${asset.id}'),
      direction: DismissDirection.startToEnd,
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        color: const Color(0xfff0f0f2),
        child: const Icon(Icons.check_circle_outline),
      ),
      confirmDismiss: (_) async {
        _controller.toggleSelection(asset.id);
        return false;
      },
      child: Material(
        color: selected ? const Color(0xfff0f0f2) : Colors.white,
        child: InkWell(
          onTap: () => _openAsset(context, asset),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    if (selected)
                      const Padding(
                        padding: EdgeInsets.only(right: 8),
                        child: Icon(Icons.check_circle_outline, size: 20),
                      ),
                    Expanded(
                      child: Text(
                        _kindLabel(asset.kind),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ],
                ),
                if (anchor != null) ...[
                  const SizedBox(height: 8),
                  Text(anchor.selectedText),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => showInArticle(context, asset),
                      icon: const Icon(Icons.my_location_outlined, size: 18),
                      label: const Text('在文中显示'),
                    ),
                  ),
                ],
                if (note != null && note.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(note),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openAsset(BuildContext context, ReadingAsset asset) async {
    if (_controller.selectedIds.isNotEmpty) {
      _controller.toggleSelection(asset.id);
      return;
    }
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => ReadingAssetCard(
        asset: asset,
        repository: widget.repository,
        onClosed: () => Navigator.of(dialogContext).pop(),
        onDeleted: (_) => _controller.load(),
      ),
    );
  }

  Future<void> _confirmDelete() async {
    if (!await showDeleteAssetDialog(context)) return;
    try {
      setState(() => _actionError = null);
      await _controller.deleteSelectedAssets(_controller.selectedIds);
    } catch (_) {
      if (mounted) setState(() => _actionError = '删除失败，请重试');
    }
  }

  void showInArticle(BuildContext context, ReadingAsset asset) {
    final anchorId = asset.anchor?.id;
    if (anchorId == null) return;
    replaceSummaryWithReader(
      context,
      articleId: widget.articleId,
      anchorId: anchorId,
    );
  }

  String _kindLabel(ReadingAssetKind kind) => switch (kind) {
    ReadingAssetKind.highlightOnly => '纯划线',
    ReadingAssetKind.linkedNote => '关联型笔记',
    ReadingAssetKind.standaloneNote => '独立型笔记',
  };
}
