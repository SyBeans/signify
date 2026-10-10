import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'theme.dart';
import 'providers/app_state.dart';
import 'screens/main_shell.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState(),
      child: const SignifyApp(),
    ),
  );
}

class SignifyApp extends StatelessWidget {
  const SignifyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Signify',
      debugShowCheckedModeBanner: false,
      theme: buildSignifyTheme(),
      home: const MainShell(),
    );
  }
}
