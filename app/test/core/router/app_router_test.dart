import 'package:app/app.dart';
import 'package:app/core/router/app_router.dart';
import 'package:app/features/auth/data/anonymous_auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('reader route preserves an anchor in its route context', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [_completedAnonymousBootstrapOverride],
        child: DeepReadingApp.routerForTest(
          '/reader/a-1',
          anchorId: 'anchor-1',
        ),
      ),
    );

    await tester.pump();

    expect(find.byKey(const Key('reader-anchor-anchor-1')), findsOneWidget);
  });

  test('reader route context records its origin and optional anchor', () {
    const context = ReaderRouteContext(
      origin: ReaderOrigin.knowledge,
      anchorId: 'anchor-1',
    );

    expect(context.origin, ReaderOrigin.knowledge);
    expect(context.anchorId, 'anchor-1');
  });

  testWidgets('reader route rejects missing extras', (tester) async {
    final router = createAppRouter(initialLocation: '/reader/a-1');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [_completedAnonymousBootstrapOverride],
        child: DeepReadingApp(router: router),
      ),
    );

    await tester.pump();

    final error = tester.takeException();
    expect(error, isA<ArgumentError>());
    expect(
      error.toString(),
      contains('Reader routes require a ReaderRouteContext.'),
    );
  });

  testWidgets('reader route rejects invalid extras', (tester) async {
    final router = createAppRouter(
      initialLocation: '/reader/a-1',
      initialExtra: 'not-a-reader-route-context',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [_completedAnonymousBootstrapOverride],
        child: DeepReadingApp(router: router),
      ),
    );

    await tester.pump();

    final error = tester.takeException();
    expect(error, isA<ArgumentError>());
    expect(
      error.toString(),
      contains('Reader routes require a ReaderRouteContext.'),
    );
  });

  testWidgets('declared knowledge and summary URLs resolve', (tester) async {
    for (final route in <String, String>{
      '/reader/a-1/summary': 'Article summary',
      '/knowledge': 'Knowledge',
      '/knowledge/collections/c-1': 'Collection',
      '/knowledge/tags/t-1': 'Tag',
    }.entries) {
      final router = createAppRouter(initialLocation: route.key);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [_completedAnonymousBootstrapOverride],
          child: DeepReadingApp(router: router),
        ),
      );
      await tester.pump();

      expect(find.text(route.value), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('replacement helpers preserve path and reader origins', (
    tester,
  ) async {
    ReaderRouteContext? receivedContext;
    String? receivedArticleId;
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: Builder(
              builder: (context) => Column(
                children: [
                  TextButton(
                    key: const Key('summary-replace'),
                    onPressed: () => replaceSummaryWithReader(
                      context,
                      articleId: 'article-1',
                      anchorId: 'anchor-1',
                    ),
                    child: const Text('Summary'),
                  ),
                  TextButton(
                    key: const Key('tag-replace'),
                    onPressed: () => replaceTagDetailWithReader(
                      context,
                      articleId: 'article-2',
                      anchorId: 'anchor-2',
                    ),
                    child: const Text('Tag'),
                  ),
                ],
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/reader/:articleId',
          builder: (context, state) {
            receivedContext = state.extra! as ReaderRouteContext;
            receivedArticleId = state.pathParameters['articleId'];
            return const SizedBox.shrink();
          },
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.byKey(const Key('summary-replace')));
    await tester.pumpAndSettle();

    expect(receivedArticleId, 'article-1');
    expect(receivedContext?.origin, ReaderOrigin.feed);
    expect(receivedContext?.anchorId, 'anchor-1');
  });

  testWidgets('tag replacement helper preserves the knowledge origin', (
    tester,
  ) async {
    ReaderRouteContext? receivedContext;
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => replaceTagDetailWithReader(
                  context,
                  articleId: 'article-2',
                  anchorId: 'anchor-2',
                ),
                child: const Text('Tag'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/reader/:articleId',
          builder: (context, state) {
            receivedContext = state.extra! as ReaderRouteContext;
            return const SizedBox.shrink();
          },
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.text('Tag'));
    await tester.pumpAndSettle();

    expect(receivedContext?.origin, ReaderOrigin.knowledge);
    expect(receivedContext?.anchorId, 'anchor-2');
  });
}

final _completedAnonymousBootstrapOverride = anonymousAuthBootstrapProvider
    .overrideWith((ref) async {});
