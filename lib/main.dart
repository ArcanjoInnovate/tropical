// lib/main.dart
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:tclub/app.dart';
import 'package:tclub/core/providers/block_provider.dart';
import 'package:tclub/core/widgets/inline_video_card.dart';
import 'package:tclub/features/auth/controller/auth_controller.dart';
import 'package:tclub/firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Status bar transparente desde o início
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor:           Colors.transparent,
    statusBarIconBrightness:  Brightness.dark,
    systemNavigationBarColor: Colors.transparent,
  ));

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Carrega a preferência de áudio (mute) salva
  await VideoMuteState.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => BlockProvider()),
        ChangeNotifierProvider(create: (_) => AuthController()),
      ],
      child: const MyApp(),
    ),
  );
}

