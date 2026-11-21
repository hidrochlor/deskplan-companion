import 'dart:async';

import 'package:flutter/widgets.dart';

import 'app_services.dart';
import 'ui/companion_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final services = await AppServices.create();
  runApp(CompanionApp(services: services));
  // Setting every reminder again talks to Android once per task, which takes
  // seconds with many tasks. It runs after the first frame, so the app opens
  // at once (Android often closes an app left in the background, and coming
  // back to it starts it from here).
  unawaited(services.start());
}
