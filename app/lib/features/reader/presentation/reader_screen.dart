import 'dart:async';

import 'package:app/core/router/app_router.dart';
import 'package:app/core/storage/preference_store.dart';
import 'package:app/features/reader/data/article_repository.dart';
import 'package:app/features/reader/domain/article.dart';
import 'package:app/features/reader/presentation/reader_controller.dart';
import 'package:app/features/reader/presentation/reader_style_sheet.dart';
import 'package:app/features/reader/presentation/selection/reader_context_menu.dart';
import 'package:app/features/reader/presentation/selection/reader_selection_adapter.dart';
import 'package:app/features/reading_assets/data/reading_asset_repository.dart';
import 'package:app/features/reading_assets/domain/reading_asset.dart';
import 'package:app/features/reading_assets/presentation/reading_asset_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

export 'reader_style_sheet.dart';

class ReaderScreen extends StatefulWidget {
  const ReaderScreen({
    required this.articleId,
    required this.routeContext,
    this.articleRepository,
    this.readingAssetRepository,
    this.preferenceStore,
    this.progressReader,
    this.connectivity,
    this.selectionAdapter = const FlutterReaderSelectionAdapter(),
    this.onOpenAssetCard,
    this.onExplainWithAi,
    this.onStandaloneNoteRequested,
    this.progressDebounceDuration = const Duration(milliseconds: 350),
    super.key,
  });

  final String articleId;
  final ReaderRouteContext routeContext;
  final ArticleRepository? articleRepository;
  final ReadingAssetRepository? readingAssetRepository;
  final PreferenceStore? preferenceStore;
  final Future<ProgressPosition?> Function(String articleId)? progressReader;
  final ReaderConnectivityPort? connectivity;
  final ReaderSelectionAdapter selectionAdapter;
  final ValueChanged<ReaderAssetCardRequest>? onOpenAssetCard;
  final ValueChanged<ReaderAiExplanationRequest>? onExplainWithAi;
  final ValueChanged<ReaderStandaloneNoteDraftRequest>?
  onStandaloneNoteRequested;
  final Duration progressDebounceDuration;

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _viewportKey = GlobalKey();
  final Map<String, GlobalKey> _blockKeys = <String, GlobalKey>{};

  Article? _article;
  ReaderController? _readerController;
  Object? _loadError;
  String? _anchorError;
  ProgressPosition? _initialPosition;
  ProgressPosition? _lastViewportPosition;
  String? _routeAnchorId;
  bool _hasViewportProgressScheduled = false;
  bool _controlsVisible = true;
  ReaderFontSize _fontSize = ReaderFontSize.defaultSize;
  ReaderThemeMode _themeMode = ReaderThemeMode.system;
  List<ReadingAsset> _assets = const [];
  ReaderSelection? _selection;
  ReaderSelectionSession? _selectionSession;
  ReadingAssetRepository? _assetRepository;
  Object? _assetsReadError;
  Object? _highlightError;
  ReaderSelection? _retryHighlightSelection;
  bool _retryHighlightRefreshOnly = false;
  bool _highlightInFlight = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scheduleViewportProgress);
    unawaited(_loadPreferences());
    unawaited(_loadArticle());
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_scheduleViewportProgress)
      ..dispose();
    _readerController?.dispose();
    _selectionSession?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = switch (_themeMode) {
      ReaderThemeMode.light => Brightness.light,
      ReaderThemeMode.dark => Brightness.dark,
      ReaderThemeMode.system => MediaQuery.platformBrightnessOf(context),
    };
    final theme = ThemeData(
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xff356ae6),
        brightness: brightness,
      ),
      scaffoldBackgroundColor: brightness == Brightness.light
          ? const Color(0xfffffcf7)
          : const Color(0xff171717),
    );
    return Theme(
      data: theme,
      child: Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            _buildContent(context),
            _buildToolbar(context),
            if (_assetsReadError != null) _buildAssetsReadError(context),
            if (_highlightError != null) _buildHighlightError(context),
            if (_readerController?.hasProgressError ?? false)
              _buildProgressError(context),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final article = _article;
    if (article == null) {
      if (_loadError != null) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Unable to load this article.'),
              const SizedBox(height: 8),
              Text(_loadError.toString(), textAlign: TextAlign.center),
              const SizedBox(height: 12),
              TextButton(
                key: const Key('reader-article-retry'),
                onPressed: _loadArticle,
                child: const Text('Retry'),
              ),
            ],
          ),
        );
      }
      return const Center(child: CircularProgressIndicator());
    }

    final content = NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is UserScrollNotification) {
          if (notification.direction == ScrollDirection.forward &&
              !_controlsVisible) {
            setState(() => _controlsVisible = true);
          } else if (notification.direction == ScrollDirection.reverse &&
              _controlsVisible) {
            setState(() => _controlsVisible = false);
          }
        }
        if (notification is ScrollUpdateNotification ||
            notification is ScrollEndNotification) {
          _scheduleViewportProgress();
        }
        return false;
      },
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () {
          if (_selection != null) {
            return;
          }
          setState(() => _controlsVisible = !_controlsVisible);
        },
        child: CustomScrollView(
          key: _viewportKey,
          controller: _scrollController,
          slivers: [
            if (_anchorError != null)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(0, 84, 0, 0),
                sliver: SliverToBoxAdapter(child: _buildAnchorError(context)),
              ),
            SliverPadding(
              padding: const EdgeInsets.only(
                top: 84,
                left: 20,
                right: 20,
                bottom: 112,
              ),
              sliver: SliverToBoxAdapter(
                child: Column(
                  children: article.blocks
                      .map((block) => _buildBlock(context, block))
                      .toList(growable: false),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    final selectionSession = _selectionSession;
    return selectionSession == null
        ? content
        : selectionSession.wrap(
            contextMenuBuilder: _buildContextMenu,
            child: content,
          );
  }

  String? get _routeAnchorBlockId {
    if (_routeAnchorId == null) {
      return null;
    }
    return _initialPosition?.blockId;
  }

  Widget _buildBlock(BuildContext context, ArticleBlock block) {
    final highlightRanges = _highlightRangesFor(block);
    final content = Padding(
      key: _blockKeys[block.id],
      padding: const EdgeInsets.only(bottom: 4),
      child: Text.rich(_buildBlockSpan(context, block, highlightRanges)),
    );
    final selectableContent =
        _selectionSession?.wrapBlock(block: block, child: content) ?? content;
    final highlightedContent = highlightRanges.isEmpty
        ? selectableContent
        : KeyedSubtree(
            key: Key('highlighted-block-${block.id}'),
            child: selectableContent,
          );
    final isRouteAnchor = block.id == _routeAnchorBlockId;
    return KeyedSubtree(
      key: Key('reader-block-${block.id}'),
      child: isRouteAnchor
          ? KeyedSubtree(
              key: Key('reader-anchor-${_routeAnchorId!}'),
              child: highlightedContent,
            )
          : highlightedContent,
    );
  }

  TextSpan _buildBlockSpan(
    BuildContext context,
    ArticleBlock block,
    List<_HighlightRange> ranges,
  ) {
    final style = TextStyle(
      fontSize: _fontSize.points,
      height: 1.45,
      color: Theme.of(context).colorScheme.onSurface,
    );
    if (ranges.isEmpty) {
      return TextSpan(text: block.content, style: style);
    }
    final children = <InlineSpan>[];
    var cursor = 0;
    for (final range in ranges) {
      if (range.start > cursor) {
        children.add(
          TextSpan(text: block.content.substring(cursor, range.start)),
        );
      }
      children.add(
        TextSpan(
          text: block.content.substring(range.start, range.end),
          style: style.copyWith(backgroundColor: const Color(0x66FFD54F)),
        ),
      );
      cursor = range.end;
    }
    if (cursor < block.content.length) {
      children.add(TextSpan(text: block.content.substring(cursor)));
    }
    return TextSpan(style: style, children: children);
  }

  List<_HighlightRange> _highlightRangesFor(ArticleBlock block) {
    final ranges = <_HighlightRange>[];
    for (final asset in _assets) {
      final anchor = asset.anchor;
      if (anchor == null || anchor.articleId != _article?.id) {
        continue;
      }
      if (anchor.startBlockId == block.id && anchor.endBlockId == block.id) {
        ranges.add(
          _HighlightRange(anchor.startUtf16Offset, anchor.endUtf16Offset),
        );
      } else if (anchor.startBlockId == block.id) {
        ranges.add(
          _HighlightRange(anchor.startUtf16Offset, block.content.length),
        );
      } else if (anchor.endBlockId == block.id) {
        ranges.add(_HighlightRange(0, anchor.endUtf16Offset));
      } else if (_isBlockBetween(block.id, anchor)) {
        ranges.add(_HighlightRange(0, block.content.length));
      }
    }
    ranges
      ..removeWhere((range) => range.end <= range.start)
      ..sort((a, b) => a.start.compareTo(b.start));
    final merged = <_HighlightRange>[];
    for (final range in ranges) {
      final bounded = _HighlightRange(
        range.start.clamp(0, block.content.length),
        range.end.clamp(0, block.content.length),
      );
      if (merged.isNotEmpty && bounded.start <= merged.last.end) {
        merged[merged.length - 1] = _HighlightRange(
          merged.last.start,
          bounded.end > merged.last.end ? bounded.end : merged.last.end,
        );
      } else {
        merged.add(bounded);
      }
    }
    return merged;
  }

  bool _isBlockBetween(String blockId, TextAnchor anchor) {
    final article = _article;
    if (article == null) {
      return false;
    }
    final blockIndex = article.blocks.indexWhere(
      (block) => block.id == blockId,
    );
    final startIndex = article.blocks.indexWhere(
      (block) => block.id == anchor.startBlockId,
    );
    final endIndex = article.blocks.indexWhere(
      (block) => block.id == anchor.endBlockId,
    );
    return startIndex >= 0 &&
        endIndex >= 0 &&
        blockIndex > startIndex &&
        blockIndex < endIndex;
  }

  Widget _buildAnchorError(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Material(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
        child: ListTile(
          key: const Key('reader-anchor-error'),
          title: Text(_anchorError!),
          trailing: IconButton(
            key: const Key('reader-anchor-retry'),
            tooltip: 'Retry',
            icon: const Icon(Icons.refresh),
            onPressed: _retryAnchorResolution,
          ),
        ),
      ),
    );
  }

  Widget _buildToolbar(BuildContext context) {
    return IgnorePointer(
      ignoring: !_controlsVisible,
      child: AnimatedOpacity(
        key: const Key('reader-controls'),
        duration: const Duration(milliseconds: 180),
        opacity: _controlsVisible ? 1 : 0,
        child: SafeArea(
          child: Stack(
            children: [
              Positioned(
                top: 8,
                left: 12,
                child: IconButton(
                  tooltip: 'Back',
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ),
              Positioned(
                bottom: 12,
                left: 16,
                child: IconButton(
                  key: const Key('reader-style-settings'),
                  tooltip: 'Reader style settings',
                  icon: const Icon(Icons.format_size),
                  onPressed: () => _showStyleSheet(context),
                ),
              ),
              Positioned(
                bottom: 12,
                right: 16,
                child: IconButton(
                  key: const Key('reader-add-standalone-note'),
                  tooltip: 'Add standalone note',
                  icon: const Icon(Icons.note_add_outlined),
                  onPressed: _requestStandaloneNote,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressError(BuildContext context) {
    return Positioned(
      left: 16,
      right: 16,
      bottom: 76,
      child: Material(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
        child: ListTile(
          dense: true,
          title: const Text('Reading progress was not saved.'),
          subtitle: const Text('Reconnect and retry.'),
          trailing: IconButton(
            key: const Key('retry-progress'),
            tooltip: 'Retry',
            icon: const Icon(Icons.refresh),
            onPressed: () => _readerController?.retryProgress(),
          ),
        ),
      ),
    );
  }

  Widget _buildAssetsReadError(BuildContext context) {
    return Positioned(
      left: 16,
      right: 16,
      bottom: 76,
      child: Material(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
        child: ListTile(
          key: const Key('reader-assets-error'),
          dense: true,
          title: const Text('Highlights could not be loaded.'),
          subtitle: const Text('The article is still available.'),
          trailing: IconButton(
            key: const Key('reader-assets-retry'),
            tooltip: 'Retry',
            icon: const Icon(Icons.refresh),
            onPressed: _retryAssetsRead,
          ),
        ),
      ),
    );
  }

  Widget _buildHighlightError(BuildContext context) {
    return Positioned(
      left: 16,
      right: 16,
      bottom: _assetsReadError == null ? 76 : 148,
      child: Material(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
        child: ListTile(
          key: const Key('reader-highlight-error'),
          dense: true,
          title: const Text('Highlight could not be saved.'),
          subtitle: const Text('Retry when the connection is available.'),
          trailing: IconButton(
            key: const Key('reader-highlight-retry'),
            tooltip: 'Retry',
            icon: const Icon(Icons.refresh),
            onPressed: _highlightInFlight ? null : _retryHighlight,
          ),
        ),
      ),
    );
  }

  Future<void> _loadArticle() async {
    if (mounted) {
      setState(() {
        _loadError = null;
        _anchorError = null;
        _article = null;
      });
    }
    try {
      final repository =
          widget.articleRepository ?? _defaultArticleRepository();
      final article = await repository.readArticle(widget.articleId);
      final anchorResolution = await _resolveRouteAnchor(article);
      final assetRepository =
          widget.readingAssetRepository ?? _defaultAssetRepository();
      final assetRead = await _readAssets(assetRepository, article.id);
      final savedProgress = anchorResolution.wasRequested
          ? null
          : await _readSavedProgress(article.id);
      if (!mounted) {
        return;
      }
      _readerController?.dispose();
      _readerController = ReaderController(
        articleId: article.id,
        repository: assetRepository,
        connectivity: widget.connectivity ?? const SocketReaderConnectivity(),
        debounceDuration: widget.progressDebounceDuration,
      )..addListener(_onControllerChanged);
      _blockKeys
        ..clear()
        ..addEntries(
          article.blocks.map((block) => MapEntry(block.id, GlobalKey())),
        );
      _selectionSession?.dispose();
      _selectionSession = widget.selectionAdapter.createSession(
        article: article,
        onSelectionChanged: _onSelectionChanged,
      );
      setState(() {
        _article = article;
        _lastViewportPosition = null;
        _initialPosition = restoreReaderPosition(
          routeAnchor: anchorResolution.position,
          savedProgress: savedProgress,
        );
        _routeAnchorId = anchorResolution.position == null
            ? null
            : widget.routeContext.anchorId;
        _anchorError = anchorResolution.errorMessage;
        _assetRepository = assetRepository;
        _assets = assetRead.assets;
        _assetsReadError = assetRead.error;
        _selection = null;
        _highlightError = null;
        _retryHighlightSelection = null;
        _retryHighlightRefreshOnly = false;
        _highlightInFlight = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_positionInitialReader());
      });
    } catch (error) {
      if (mounted) {
        setState(() => _loadError = error);
      }
    }
  }

  Future<_AssetRead> _readAssets(
    ReadingAssetRepository? repository,
    String articleId,
  ) async {
    if (repository == null) {
      return const _AssetRead.success([]);
    }
    try {
      return _AssetRead.success(
        await repository.readAssets(articleId: articleId),
      );
    } catch (error) {
      return _AssetRead.failure(error);
    }
  }

  void _onSelectionChanged(ReaderSelection? selection) {
    if (!mounted) {
      return;
    }
    setState(() => _selection = selection);
  }

  Widget _buildContextMenu(
    BuildContext context,
    ReaderSelection selection,
    TextSelectionToolbarAnchors anchors,
  ) {
    return ReaderContextMenu(
      selection: selection,
      anchors: anchors,
      onAction: (action) => _handleContextAction(action, selection),
    );
  }

  void _handleContextAction(
    ReaderContextAction action,
    ReaderSelection selection,
  ) {
    final article = _article;
    if (article == null) {
      return;
    }
    _clearSelection();
    switch (action) {
      case ReaderContextAction.highlight:
        _startHighlight(selection);
      case ReaderContextAction.openAssetCard:
        final request = ReaderAssetCardRequest(
          articleId: article.id,
          selection: selection,
        );
        final onOpenAssetCard = widget.onOpenAssetCard;
        if (onOpenAssetCard != null) {
          onOpenAssetCard(request);
        } else {
          unawaited(_presentAssetCard(request, article));
        }
      case ReaderContextAction.explainWithAi:
        widget.onExplainWithAi?.call(
          ReaderAiExplanationRequest(
            articleId: article.id,
            selection: selection,
          ),
        );
      case ReaderContextAction.copy:
        break;
    }
  }

  void _clearSelection() {
    ContextMenuController.removeAny();
    _selectionSession?.clearSelection();
    if (mounted && _selection != null) {
      setState(() => _selection = null);
    }
  }

  void _startHighlight(ReaderSelection selection) {
    if (_highlightInFlight) {
      return;
    }
    unawaited(_submitHighlight(selection));
  }

  Future<void> _submitHighlight(
    ReaderSelection selection, {
    bool refreshOnly = false,
  }) async {
    if (_highlightInFlight) {
      return;
    }
    final article = _article;
    final repository = _assetRepository ?? _defaultAssetRepository();
    if (article == null || repository == null) {
      if (mounted) {
        setState(() {
          _highlightError = StateError('Highlights are unavailable.');
          _retryHighlightSelection = selection;
          _retryHighlightRefreshOnly = refreshOnly;
        });
      }
      return;
    }
    if (mounted) {
      setState(() {
        _highlightInFlight = true;
        _highlightError = null;
      });
    }
    var created = refreshOnly;
    try {
      final controller = ReaderSelectionController(
        article: article,
        repository: repository,
      );
      if (!refreshOnly) {
        await controller.createHighlight(selection);
        created = true;
      }
      final assets = await controller.refreshAssets();
      if (!mounted) {
        return;
      }
      setState(() {
        _assets = assets;
        _highlightError = null;
        _retryHighlightSelection = null;
        _retryHighlightRefreshOnly = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _highlightError = error;
          _retryHighlightSelection = selection;
          _retryHighlightRefreshOnly = created;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _highlightInFlight = false);
      }
    }
  }

  Future<void> _retryHighlight() async {
    final selection = _retryHighlightSelection;
    if (selection == null) {
      return;
    }
    await _submitHighlight(selection, refreshOnly: _retryHighlightRefreshOnly);
  }

  Future<void> _retryAssetsRead() async {
    final article = _article;
    final repository = _assetRepository;
    if (article == null || repository == null) {
      return;
    }
    final result = await _readAssets(repository, article.id);
    if (!mounted) {
      return;
    }
    setState(() {
      _assets = result.assets;
      _assetsReadError = result.error;
    });
  }

  Future<void> _presentAssetCard(
    ReaderAssetCardRequest request,
    Article article,
  ) async {
    final repository = _assetRepository ?? _defaultAssetRepository();
    if (repository == null) {
      if (mounted) {
        setState(
          () => _highlightError = StateError('Reading assets are unavailable.'),
        );
      }
      return;
    }
    try {
      await ReadingAssetCardRequestPresenter(
        repository: repository,
      ).presentAssetRequest(
        context,
        request: request,
        article: article,
        onReaderAssetsRefresh: _refreshAssetsAfterCardDelete,
      );
    } catch (error) {
      if (mounted) {
        setState(() => _highlightError = error);
      }
    }
  }

  Future<void> _refreshAssetsAfterCardDelete(ReadingAsset deletedAsset) async {
    final article = _article;
    final repository = _assetRepository ?? _defaultAssetRepository();
    if (mounted) {
      setState(() {
        _assets = _assets
            .where((asset) => asset.id != deletedAsset.id)
            .toList(growable: false);
        _assetsReadError = null;
      });
    }
    if (article == null || repository == null) {
      return;
    }
    final result = await _readAssets(repository, article.id);
    if (!mounted) {
      return;
    }
    setState(() {
      if (result.error == null) {
        _assets = result.assets;
      }
      _assetsReadError = result.error;
    });
  }

  void _requestStandaloneNote() {
    final article = _article;
    if (article == null) {
      return;
    }
    final request = ReaderStandaloneNoteDraftRequest(articleId: article.id);
    final onStandaloneNoteRequested = widget.onStandaloneNoteRequested;
    if (onStandaloneNoteRequested != null) {
      onStandaloneNoteRequested(request);
      return;
    }
    final repository = _assetRepository ?? _defaultAssetRepository();
    if (repository == null) {
      return;
    }
    unawaited(
      ReadingAssetCardRequestPresenter(
        repository: repository,
      ).presentStandaloneNoteRequest(context, request: request),
    );
  }

  Future<_AnchorResolution> _resolveRouteAnchor(Article article) async {
    final anchorId = widget.routeContext.anchorId;
    if (anchorId == null) {
      return const _AnchorResolution.notRequested();
    }
    final repository =
        widget.readingAssetRepository ?? _defaultAssetRepository();
    if (repository == null) {
      return const _AnchorResolution.unavailable();
    }
    try {
      final assets = await repository.readAssets(articleId: article.id);
      for (final asset in assets) {
        final anchor = asset.anchor;
        if (anchor?.id == anchorId &&
            article.blocks.any((block) => block.id == anchor!.startBlockId)) {
          return _AnchorResolution.found(
            ProgressPosition(
              blockId: anchor!.startBlockId,
              utf16Offset: anchor.startUtf16Offset,
            ),
          );
        }
      }
    } catch (_) {
      return const _AnchorResolution.lookupFailed();
    }
    return const _AnchorResolution.unavailable();
  }

  Future<void> _retryAnchorResolution() async {
    final article = _article;
    if (article == null) {
      await _loadArticle();
      return;
    }
    final resolution = await _resolveRouteAnchor(article);
    if (!mounted) {
      return;
    }
    setState(() {
      _anchorError = resolution.errorMessage;
      if (resolution.position != null) {
        _initialPosition = resolution.position;
        _routeAnchorId = widget.routeContext.anchorId;
      }
    });
    if (resolution.position != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_positionInitialReader());
      });
    }
  }

  Future<ProgressPosition?> _readSavedProgress(String articleId) async {
    final reader = widget.progressReader ?? _defaultProgressReader();
    if (reader == null) {
      return null;
    }
    try {
      return await reader(articleId);
    } catch (_) {
      return null;
    }
  }

  Future<void> _positionInitialReader() async {
    final position = _initialPosition;
    if (!mounted || position == null) {
      return;
    }
    final blockContext = _blockKeys[position.blockId]?.currentContext;
    if (blockContext == null) {
      return;
    }
    final textDirection = Directionality.of(context);
    final textScaler = MediaQuery.textScalerOf(context);
    final textColor = Theme.of(context).colorScheme.onSurface;
    final blockRenderObject = blockContext.findRenderObject();
    await Scrollable.ensureVisible(
      blockContext,
      alignment: 0.16,
      duration: Duration.zero,
    );
    if (!mounted) {
      return;
    }
    final blockBox = blockRenderObject as RenderBox?;
    final viewportBox =
        _viewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (blockBox == null || viewportBox == null) {
      return;
    }
    final block = _article!.blocks.firstWhere(
      (candidate) => candidate.id == position.blockId,
    );
    final painter = TextPainter(
      text: TextSpan(
        text: block.content,
        style: TextStyle(
          fontSize: _fontSize.points,
          height: 1.45,
          color: textColor,
        ),
      ),
      textDirection: textDirection,
      textScaler: textScaler,
    )..layout(maxWidth: blockBox.size.width);
    final offset = position.utf16Offset.clamp(0, block.content.length);
    final caret = painter.getOffsetForCaret(
      TextPosition(offset: offset),
      Rect.zero,
    );
    final caretGlobal = blockBox.localToGlobal(caret);
    final desiredGlobal = viewportBox.localToGlobal(
      Offset(0, viewportBox.size.height * 0.16),
    );
    final target = _scrollController.offset + caretGlobal.dy - desiredGlobal.dy;
    _scrollController.jumpTo(
      target.clamp(
        _scrollController.position.minScrollExtent,
        _scrollController.position.maxScrollExtent,
      ),
    );
  }

  void _scheduleViewportProgress() {
    if (_hasViewportProgressScheduled) {
      return;
    }
    _hasViewportProgressScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _hasViewportProgressScheduled = false;
      _recordViewportProgress();
    });
  }

  void _recordViewportProgress() {
    final article = _article;
    final controller = _readerController;
    final viewportContext = _viewportKey.currentContext;
    if (article == null || controller == null || viewportContext == null) {
      return;
    }
    final viewportBox = viewportContext.findRenderObject() as RenderBox?;
    if (viewportBox == null) {
      return;
    }
    final focus = viewportBox.localToGlobal(
      Offset(viewportBox.size.width * 0.05, viewportBox.size.height * 0.16),
    );
    for (final block in article.blocks) {
      final blockBox =
          _blockKeys[block.id]?.currentContext?.findRenderObject()
              as RenderBox?;
      if (blockBox == null) {
        continue;
      }
      final blockOrigin = blockBox.localToGlobal(Offset.zero);
      final painter = _layoutBlockText(block, blockBox.size.width);
      final localY = focus.dy - blockOrigin.dy;
      if (localY < 0 || localY > painter.height) {
        continue;
      }
      final textPosition = painter.getPositionForOffset(
        Offset(
          (focus.dx - blockOrigin.dx).clamp(0, blockBox.size.width),
          localY.clamp(0, painter.height),
        ),
      );
      final position = ProgressPosition(
        blockId: block.id,
        utf16Offset: textPosition.offset,
      );
      if (position == _lastViewportPosition) {
        return;
      }
      _lastViewportPosition = position;
      controller.updateProgress(position.blockId, position.utf16Offset);
      return;
    }
  }

  TextPainter _layoutBlockText(ArticleBlock block, double maxWidth) {
    return TextPainter(
      text: TextSpan(
        text: block.content,
        style: TextStyle(
          fontSize: _fontSize.points,
          height: 1.45,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(maxWidth: maxWidth);
  }

  Future<void> _loadPreferences() async {
    try {
      final store = widget.preferenceStore ?? PreferenceStore();
      final savedFontSize = await store.readReaderFontSize();
      final savedTheme = await store.readReaderTheme();
      if (!mounted) {
        return;
      }
      setState(() {
        if (savedFontSize != null) {
          _fontSize = _fontFromPoints(savedFontSize);
        }
        if (savedTheme != null) {
          _themeMode = _themeFromValue(savedTheme);
        }
      });
    } catch (_) {
      // Preferences are non-critical; defaults remain active.
    }
  }

  Future<void> _showStyleSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) => ReaderStyleSheet(
        fontIndex: _fontSize.index,
        themeMode: _themeMode,
        onFontIndexChanged: (index) {
          final value = ReaderFontSize.values[index];
          setState(() => _fontSize = value);
          unawaited(
            (widget.preferenceStore ?? PreferenceStore()).saveReaderFontSize(
              value.points,
            ),
          );
        },
        onThemeModeChanged: (mode) {
          setState(() => _themeMode = mode);
          unawaited(
            (widget.preferenceStore ?? PreferenceStore()).saveReaderTheme(
              mode.name,
            ),
          );
        },
      ),
    );
  }

  void _onControllerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  ReaderFontSize _fontFromPoints(double points) {
    return ReaderFontSize.values.reduce(
      (a, b) => (a.points - points).abs() <= (b.points - points).abs() ? a : b,
    );
  }

  ReaderThemeMode _themeFromValue(String value) {
    return ReaderThemeMode.values.firstWhere(
      (mode) => mode.name == value,
      orElse: () => ReaderThemeMode.system,
    );
  }

  ArticleRepository _defaultArticleRepository() {
    try {
      return SupabaseArticleRepository(Supabase.instance.client);
    } catch (_) {
      throw const ReaderArticleUnavailableException();
    }
  }

  ReadingAssetRepository? _defaultAssetRepository() {
    try {
      return SupabaseReadingAssetRepository(Supabase.instance.client);
    } catch (_) {
      return null;
    }
  }

  Future<ProgressPosition?> Function(String articleId)?
  _defaultProgressReader() {
    try {
      final reader = SupabaseReaderProgressReader(Supabase.instance.client);
      return reader.read;
    } catch (_) {
      return null;
    }
  }
}

class ReaderArticleUnavailableException implements Exception {
  const ReaderArticleUnavailableException();

  @override
  String toString() => 'No article repository is available.';
}

class _HighlightRange {
  const _HighlightRange(this.start, this.end);

  final int start;
  final int end;
}

class _AnchorResolution {
  const _AnchorResolution.notRequested()
    : wasRequested = false,
      position = null,
      errorMessage = null;

  const _AnchorResolution.found(this.position)
    : wasRequested = true,
      errorMessage = null;

  const _AnchorResolution.unavailable()
    : wasRequested = true,
      position = null,
      errorMessage = 'Requested reading anchor is unavailable.';

  const _AnchorResolution.lookupFailed()
    : wasRequested = true,
      position = null,
      errorMessage = 'Unable to resolve the requested reading anchor.';

  final bool wasRequested;
  final ProgressPosition? position;
  final String? errorMessage;
}

class _AssetRead {
  const _AssetRead.success(this.assets) : error = null;

  const _AssetRead.failure(this.error) : assets = const [];

  final List<ReadingAsset> assets;
  final Object? error;
}
