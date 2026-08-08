import 'package:app/features/reader/presentation/reader_screen.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

enum ReaderOrigin { feed, knowledge }

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

GoRouter createAppRouter({String initialLocation = '/', Object? initialExtra}) {
  return GoRouter(
    initialLocation: initialLocation,
    initialExtra: initialExtra,
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (context, state) {
          return const Scaffold(body: Center(child: Text('Deep Reading')));
        },
      ),
      GoRoute(
        path: '/reader/:articleId/summary',
        builder: (context, state) {
          return _ContractSurface(label: 'Article summary');
        },
      ),
      GoRoute(
        path: '/reader/:articleId',
        builder: (context, state) {
          final routeContext = ReaderRouteContext.fromRouteExtra(state.extra);
          return ReaderScreen(
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

class _ContractSurface extends StatelessWidget {
  const _ContractSurface({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Center(child: Text(label)));
  }
}
