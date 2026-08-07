import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class DeepReadingApp extends StatelessWidget {
  const DeepReadingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Deep Reading',
      routerConfig: GoRouter(
        routes: <RouteBase>[
          GoRoute(
            path: '/',
            builder: (BuildContext context, GoRouterState state) {
              return const Scaffold(body: Center(child: Text('Deep Reading')));
            },
          ),
        ],
      ),
    );
  }
}
