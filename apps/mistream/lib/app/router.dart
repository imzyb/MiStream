import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:mistream/features/home/home_page.dart';
import 'package:mistream/features/search/search_page.dart';

final GlobalKey<NavigatorState> _rootKey = GlobalKey<NavigatorState>();

final GoRouter appRouter = GoRouter(
  navigatorKey: _rootKey,
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      name: 'home',
      builder: (context, state) => const HomePage(),
    ),
    GoRoute(
      path: '/search',
      name: 'search',
      builder: (context, state) => const SearchPage(),
    ),
    GoRoute(
      path: '/detail/:vodId',
      name: 'detail',
      builder: (context, state) => const Placeholder(),
    ),
    GoRoute(
      path: '/player/:vodId/:flag',
      name: 'player',
      builder: (context, state) => const Placeholder(),
    ),
  ],
);
