import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'game/game_controller.dart';
import 'screens/loading_screen.dart';
import 'theme/palette.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Orientation is intentionally left free at boot: the loading screen is
  // allowed to be shown in portrait OR landscape. Screens further down the
  // flow lock themselves to portrait once they mount.
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Palette.nightPurple,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const JokerStreetApp());
}

class JokerStreetApp extends StatelessWidget {
  const JokerStreetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => GameController(),
      child: MaterialApp(
        title: 'Joker Street',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: Palette.nightPurple,
          fontFamily: 'Baloo2',
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Palette.gold,
            brightness: Brightness.dark,
          ),
        ),
        home: const LoadingScreen(),
      ),
    );
  }
}
