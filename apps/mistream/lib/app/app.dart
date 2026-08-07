import 'package:flutter/material.dart';
import 'package:mistream/app/router.dart';

/// 应用根 widget：装配主题、路由与全局 overlay。
class MiStreamApp extends StatelessWidget {
  const MiStreamApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'MiStream',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: const Color(0xFF0D0F14),
      ),
      routerConfig: appRouter,
    );
  }
}
