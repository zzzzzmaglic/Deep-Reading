import 'dart:async';

import 'package:app/core/router/app_router.dart';
import 'package:app/core/storage/preference_store.dart';
import 'package:app/features/reader/data/article_repository.dart';
import 'package:app/features/reader/domain/article.dart';
import 'package:app/features/reader/presentation/reader_controller.dart';
import 'package:app/features/reader/presentation/reader_style_sheet.dart';
import 'package:app/features/reading_assets/data/reading_asset_repository.dart';
import 'package:flutter/material.dart';
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
    this.isOnline,
    super.key,
  });

  final String articleId;
  final ReaderRouteContext routeContext;
  final ArticleRepository? articleRepository;
  final ReadingAssetRepository? readingAssetRepository;
  final PreferenceStore? preferenceStore;
  final Future<ProgressPosition?> Function(String articleId)? progressReader;
  final bool Function()? isOnline;

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _anchorKey = GlobalKey();

  Article? _article;
  ReaderController? _readerController;
  Object? _loadError;
  bool _controlsVisible = true;
  ReaderFontSize _fontSize = ReaderFontSize.defaultSize;
  ReaderThemeMode _themeMode = ReaderThemeMode.system;
  String? _anchorBlockId;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_recordApproximateProgress);
    unawaited(_loadPreferences());
    unawaited(_loadArticle());
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_recordApproximateProgress)
      ..dispose();
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
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        theme.scaffoldBackgroundColor.withValues(alpha: 0.72),
                        Colors.transparent,
                        Colors.transparent,
                        theme.scaffoldBackgroundColor.withValues(alpha: 0.8),
                      ],
                      stops: const [0, 0.13, 0.82, 1],
                    ),
                  ),
                ),
              ),
            ),
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
    final anchorId = widget.routeContext.anchorId;
    if (article == null) {
      if (_loadError != null) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('文章暂时无法打开：$_loadError'),
              const SizedBox(height: 12),
              TextButton(onPressed: _loadArticle, child: const Text('重试')),
              if (anchorId != null)
                SizedBox(key: Key('reader-anchor-$anchorId')),
            ],
          ),
        );
      }
      return Center(
        child: anchorId == null
            ? const CircularProgressIndicator()
            : SizedBox(key: Key('reader-anchor-$anchorId')),
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _controlsVisible = !_controlsVisible),
      child: NotificationListener<UserScrollNotification>(
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
                  final isAnchor = block.id == _anchorBlockId;
                  return KeyedSubtree(
                    key: Key('reader-block-${block.id}'),
                    child: Padding(
                      key: isAnchor ? _anchorKey : null,
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        block.content,
                        style: TextStyle(
                          fontSize: _fontSize.points,
                          height: 1.45,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
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
                  tooltip: '返回',
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ),
              Positioned(
                bottom: 12,
                left: 16,
                child: IconButton(
                  key: const Key('reader-style-settings'),
                  tooltip: '阅读器样式设置',
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
          title: const Text('阅读进度未保存'),
          subtitle: const Text('网络恢复后可重试。'),
          trailing: IconButton(
            key: const Key('retry-progress'),
            tooltip: '重试',
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _readerController?.retryProgress();
              setState(() {});
            },
          ),
        ),
      ),
    );
  }

  Future<void> _loadArticle() async {
    setState(() => _loadError = null);
    try {
      final repository = widget.articleRepository ?? _defaultArticleRepository();
      final article = await repository.readArticle(widget.articleId);
      final targetBlockId = await _resolveAnchorBlockId(article);
      final savedProgress = targetBlockId == null
          ? await _readSavedProgress(article.id)
          : null;
      if (!mounted) {
        return;
      }
      _readerController?.dispose();
      _readerController = ReaderController(
        articleId: article.id,
        repository: widget.readingAssetRepository ?? _defaultAssetRepository(),
        isOnline: widget.isOnline ?? _defaultIsOnline,
      )..addListener(_onControllerChanged);
      setState(() {
        _article = article;
        _anchorBlockId = targetBlockId ??
            (article.blocks.any((block) => block.id == savedProgress?.blockId)
                ? savedProgress?.blockId
                : null);
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _positionAnchor());
    } catch (error) {
      if (mounted) {
        setState(() => _loadError = error);
      }
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

  Future<String?> _resolveAnchorBlockId(Article article) async {
    final anchorId = widget.routeContext.anchorId;
    if (anchorId == null) {
      return null;
    }
    final repository = widget.readingAssetRepository ?? _defaultAssetRepository();
    if (repository != null) {
      try {
        final assets = await repository.readAssets(articleId: article.id);
        for (final asset in assets) {
          if (asset.anchor?.id == anchorId) {
            return asset.anchor!.startBlockId;
          }
        }
      } catch (_) {
        // A cached article can still be read when the private asset read is unavailable.
      }
    }
    return article.blocks.any((block) => block.id == anchorId)
        ? anchorId
        : repository == null
        ? article.blocks.firstOrNull?.id
        : null;
  }

  void _positionAnchor() {
    if (!mounted || _anchorBlockId == null) {
      return;
    }
    final target = _anchorKey.currentContext;
    if (target != null) {
      unawaited(
        Scrollable.ensureVisible(
          target,
          alignment: 0.16,
          duration: Duration.zero,
        ),
      );
    }
  }

  void _recordApproximateProgress() {
    final article = _article;
    final controller = _readerController;
    if (article == null || controller == null || article.blocks.isEmpty) {
      return;
    }
    final index = (_scrollController.offset / 120).floor().clamp(
      0,
      article.blocks.length - 1,
    );
    controller.updateProgress(article.blocks[index].id, 0);
  }

  Future<void> _loadPreferences() async {
    final store = widget.preferenceStore ?? PreferenceStore();
    try {
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
      // Preferences are non-critical; the frozen defaults remain active.
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
      return const DemoArticleRepository();
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

  bool _defaultIsOnline() {
    try {
      return Supabase.instance.client.auth.currentSession != null;
    } catch (_) {
      return false;
    }
  }
}

extension on Iterable<ArticleBlock> {
  ArticleBlock? get firstOrNull => isEmpty ? null : first;
}
