import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'theme.dart';
import 'providers/app_state.dart';
import 'screens/main_shell.dart'; // <-- Back to MainShell

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
    return Consumer<AppState>(
      builder: (context, state, _) {
        double textScale = 1.0;
        if (state.textSize == 'S') textScale = 0.85;
        if (state.textSize == 'L') textScale = 1.15;

        return MaterialApp(
          title: 'Signify',
          debugShowCheckedModeBanner: false,
          theme: buildSignifyTheme(),
          darkTheme: buildSignifyDarkTheme(),
          themeMode: state.darkMode ? ThemeMode.dark : ThemeMode.light,
          builder: (context, child) {
            return MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(textScale)),
              child: child!,
            );
          },
          home: const MainShell(), // <-- Reverted
        );
      },
    );
  }
}
