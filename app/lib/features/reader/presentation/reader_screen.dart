import 'dart:async';

import 'package:app/core/router/app_router.dart';
import 'package:app/core/storage/preference_store.dart';
import 'package:app/features/reader/data/article_repository.dart';
import 'package:app/features/reader/domain/article.dart';
import 'package:app/features/reader/presentation/reader_controller.dart';
import 'package:app/features/reader/presentation/reader_style_sheet.dart';
import 'package:app/features/reading_assets/data/reading_asset_repository.dart';
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
    super.key,
  });

  final String articleId;
  final ReaderRouteContext routeContext;
  final ArticleRepository? articleRepository;
  final ReadingAssetRepository? readingAssetRepository;
  final PreferenceStore? preferenceStore;
  final Future<ProgressPosition?> Function(String articleId)? progressReader;
  final ReaderConnectivityPort? connectivity;

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
  String? _routeAnchorId;
  bool _controlsVisible = true;
  ReaderFontSize _fontSize = ReaderFontSize.defaultSize;
  ReaderThemeMode _themeMode = ReaderThemeMode.system;

  @override
  void initState() {
    super.initState();
    unawaited(_loadPreferences());
    unawaited(_loadArticle());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _readerController?.dispose();
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

    return NotificationListener<UserScrollNotification>(
      onNotification: (notification) {
        if (notification.direction == ScrollDirection.forward &&
            !_controlsVisible) {
          setState(() => _controlsVisible = true);
        } else if (notification.direction == ScrollDirection.reverse &&
            _controlsVisible) {
          setState(() => _controlsVisible = false);
        }
        return false;
      },
      child: CustomScrollView(
        key: _viewportKey,
        controller: _scrollController,
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.only(
              top: 84,
              left: 20,
              right: 20,
              bottom: 112,
            ),
            sliver: SliverList.builder(
              itemCount: article.blocks.length,
              itemBuilder: (context, index) {
                final block = article.blocks[index];
                final content = Padding(
                  key: _blockKeys[block.id],
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    block.content,
                    style: TextStyle(
                      fontSize: _fontSize.points,
                      height: 1.45,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                );
                final isRouteAnchor = block.id == _routeAnchorBlockId;
                return KeyedSubtree(
                  key: Key('reader-block-${block.id}'),
                  child: isRouteAnchor
                      ? KeyedSubtree(
                          key: Key('reader-anchor-${_routeAnchorId!}'),
                          child: content,
                        )
                      : content,
                );
              },
            ),
          ),
          if (_anchorError != null)
            SliverToBoxAdapter(child: _buildAnchorError(context)),
        ],
      ),
    );
  }

  String? get _routeAnchorBlockId {
    if (_routeAnchorId == null) {
      return null;
    }
    return _initialPosition?.blockId;
  }

  Widget _buildAnchorError(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Material(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
        child: ListTile(
          key: const Key('reader-anchor-error'),
          title: const Text('Requested reading anchor is unavailable.'),
          trailing: IconButton(
            key: const Key('reader-anchor-retry'),
            tooltip: 'Retry',
            icon: const Icon(Icons.refresh),
            onPressed: _loadArticle,
          ),
        ),
      ),
    );
  }

  Widget _buildToolbar(BuildContext context) {
    return IgnorePointer(
      ignoring: !_controlsVisible,
      child: AnimatedOpacity(
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
      final anchorRequested = widget.routeContext.anchorId != null;
      final routeAnchor = await _readRouteAnchor(article);
      final savedProgress = anchorRequested
          ? null
          : await _readSavedProgress(article.id);
      if (!mounted) {
        return;
      }
      _readerController?.dispose();
      final assetRepository =
          widget.readingAssetRepository ?? _defaultAssetRepository();
      _readerController = ReaderController(
        articleId: article.id,
        repository: assetRepository,
        connectivity: widget.connectivity ?? const SocketReaderConnectivity(),
      )..addListener(_onControllerChanged);
      _blockKeys
        ..clear()
        ..addEntries(
          article.blocks.map((block) => MapEntry(block.id, GlobalKey())),
        );
      setState(() {
        _article = article;
        _initialPosition = restoreReaderPosition(
          routeAnchor: routeAnchor,
          savedProgress: savedProgress,
        );
        _routeAnchorId = routeAnchor == null
            ? null
            : widget.routeContext.anchorId;
        if (anchorRequested && routeAnchor == null) {
          _anchorError = 'Requested reading anchor is unavailable.';
        }
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

  Future<ProgressPosition?> _readRouteAnchor(Article article) async {
    final anchorId = widget.routeContext.anchorId;
    if (anchorId == null) {
      return null;
    }
    final repository =
        widget.readingAssetRepository ?? _defaultAssetRepository();
    if (repository == null) {
      return null;
    }
    final assets = await repository.readAssets(articleId: article.id);
    for (final asset in assets) {
      final anchor = asset.anchor;
      if (anchor?.id == anchorId &&
          article.blocks.any((block) => block.id == anchor!.startBlockId)) {
        return ProgressPosition(
          blockId: anchor!.startBlockId,
          utf16Offset: anchor.startUtf16Offset,
        );
      }
    }
    return null;
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
