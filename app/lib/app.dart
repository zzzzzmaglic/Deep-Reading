import 'package:app/features/auth/data/anonymous_auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/router/app_router.dart';

class DeepReadingApp extends ConsumerWidget {
  const DeepReadingApp({super.key, this.router});

  DeepReadingApp.routerForTest(
    String initialLocation, {
    super.key,
    String? anchorId,
  }) : router = createAppRouter(
         initialLocation: initialLocation,
         initialExtra: ReaderRouteContext(
           origin: ReaderOrigin.feed,
           anchorId: anchorId,
         ),
       );

  final GoRouter? router;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bootstrap = ref.watch(anonymousAuthBootstrapProvider);

    return bootstrap.when(
      loading: () => const MaterialApp(
        home: Scaffold(body: SizedBox(key: Key('app-bootstrap-loading'))),
      ),
      error: (error, stackTrace) => const MaterialApp(
        home: Scaffold(
          body: Center(child: Text('Unable to start Deep Reading')),
        ),
      ),
      data: (_) => MaterialApp.router(
        title: 'Deep Reading',
        routerConfig: router ?? createAppRouter(),
      ),
    );
  }
}
