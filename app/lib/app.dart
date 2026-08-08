import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'core/router/app_router.dart';

class DeepReadingApp extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Deep Reading',
      routerConfig: router ?? createAppRouter(),
    );
  }
}
