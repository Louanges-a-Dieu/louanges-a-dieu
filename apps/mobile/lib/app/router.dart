import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/account/account_screen.dart';
import '../features/favorites/favorites_screen.dart';
import '../features/home/home_screen.dart';
import '../features/hymn/hymn_screen.dart';
import '../features/hymnal/hymnal_screen.dart';
import '../features/lists/lists.dart';
import '../features/more/more_screen.dart';
import '../features/reader/reader_screen.dart';
import '../features/search/search_screen.dart';
import '../features/shell/app_shell.dart';

final _rootKey = GlobalKey<NavigatorState>();

/// Routes de l'application : quatre onglets (état conservé) et des écrans
/// plein écran (recherche, fiche, lecture).
final routerProvider = Provider<GoRouter>(
  (ref) => GoRouter(
    navigatorKey: _rootKey,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [GoRoute(path: '/', builder: (_, _) => const HomeScreen())],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/recueil',
                builder: (_, _) => const HymnalScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/favoris',
                builder: (_, _) => const FavoritesScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/plus',
                builder: (_, _) => const MoreScreen(),
                routes: [
                  GoRoute(
                    path: 'hors-connexion',
                    parentNavigatorKey: _rootKey,
                    builder: (_, _) => const OfflineScreen(),
                  ),
                  GoRoute(
                    path: 'a-propos',
                    parentNavigatorKey: _rootKey,
                    builder: (_, _) => const AboutScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/compte',
        parentNavigatorKey: _rootKey,
        builder: (_, _) => const AccountScreen(),
      ),
      GoRoute(
        path: '/listes/:id',
        parentNavigatorKey: _rootKey,
        builder: (_, state) =>
            PlaylistScreen(playlistId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/recherche',
        parentNavigatorKey: _rootKey,
        builder: (_, _) => const SearchScreen(),
      ),
      GoRoute(
        path: '/cantique/:id',
        parentNavigatorKey: _rootKey,
        builder: (_, state) => HymnScreen(hymnId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/lecture/:id',
        parentNavigatorKey: _rootKey,
        builder: (_, state) =>
            ReaderScreen(hymnId: state.pathParameters['id']!),
      ),
    ],
  ),
);
