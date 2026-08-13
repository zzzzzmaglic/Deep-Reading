import 'package:app/features/reader/presentation/article_asset_summary_screen.dart';
import 'package:app/features/reader/presentation/reader_screen.dart';
import 'package:app/features/reading_assets/data/reading_asset_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum ReaderOrigin { feed, knowledge }

typedef ReaderScreenBuilder =
    Widget Function({
      required String articleId,
      required ReaderRouteContext routeContext,
    });

class ReaderRouteContext {
  const ReaderRouteContext({required this.origin, this.anchorId});

  final ReaderOrigin origin;
  final String? anchorId;

  static ReaderRouteContext fromRouteExtra(Object? extra) {
    if (extra is ReaderRouteContext) {
      return extra;
    }
    throw ArgumentError.value(
      extra,
      'extra',
      'Reader routes require a ReaderRouteContext.',
    );
  }
}

void replaceSummaryWithReader(
  BuildContext context, {
  required String articleId,
  String? anchorId,
}) {
  context.pushReplacement(
    '/reader/${Uri.encodeComponent(articleId)}',
    extra: ReaderRouteContext(origin: ReaderOrigin.feed, anchorId: anchorId),
  );
}

void replaceTagDetailWithReader(
  BuildContext context, {
  required String articleId,
  String? anchorId,
}) {
  context.pushReplacement(
    '/reader/${Uri.encodeComponent(articleId)}',
    extra: ReaderRouteContext(
      origin: ReaderOrigin.knowledge,
      anchorId: anchorId,
    ),
  );
}

GoRouter createAppRouter({
  String initialLocation = '/',
  Object? initialExtra,
  ReaderScreenBuilder? readerScreenBuilder,
  ReadingAssetRepository? readingAssetRepository,
  bool enableDebugQaEntry = kDebugMode,
}) {
  return GoRouter(
    initialLocation: initialLocation,
    initialExtra: initialExtra,
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (context, state) {
          if (enableDebugQaEntry) {
            return const _DebugQaLaunchScreen();
          }
          return const Scaffold(body: Center(child: Text('Deep Reading')));
        },
      ),
      GoRoute(
        path: '/reader/:articleId/summary',
        builder: (context, state) {
          final repository =
              readingAssetRepository ?? _tryDefaultAssetRepository();
          if (repository == null) {
            return _ContractSurface(label: 'Article summary');
          }
          return ArticleAssetSummaryScreen(
            articleId: state.pathParameters['articleId']!,
            repository: repository,
          );
        },
      ),
      GoRoute(
        path: '/reader/:articleId',
        builder: (context, state) {
          final routeContext = ReaderRouteContext.fromRouteExtra(state.extra);
          return readerScreenBuilder?.call(
                articleId: state.pathParameters['articleId']!,
                routeContext: routeContext,
              ) ??
              ReaderScreen(
                articleId: state.pathParameters['articleId']!,
                routeContext: routeContext,
              );
        },
      ),
      GoRoute(
        path: '/knowledge',
        builder: (context, state) => _ContractSurface(label: 'Knowledge'),
      ),
      GoRoute(
        path: '/knowledge/collections/:collectionId',
        builder: (context, state) => _ContractSurface(label: 'Collection'),
      ),
      GoRoute(
        path: '/knowledge/tags/:tagId',
        builder: (context, state) => _ContractSurface(label: 'Tag'),
      ),
    ],
  );
}

class _DebugQaLaunchScreen extends StatelessWidget {
  const _DebugQaLaunchScreen();

  static const _articleId = '10000000-0000-0000-0000-000000000001';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Deep Reading QA')),
      body: Center(
        child: FilledButton(
          key: const Key('debug-qa-open-reader'),
          onPressed: () => context.push(
            '/reader/$_articleId',
            extra: const ReaderRouteContext(origin: ReaderOrigin.feed),
          ),
          child: const Text('Open seed article'),
        ),
      ),
    );
  }
}

ReadingAssetRepository? _tryDefaultAssetRepository() {
  try {
    return SupabaseReadingAssetRepository(Supabase.instance.client);
  } catch (_) {
    return null;
  }
}

class _ContractSurface extends StatelessWidget {
  const _ContractSurface({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Center(child: Text(label)));
  }
}
