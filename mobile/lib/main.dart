import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'sync/background_sync.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await BackgroundSyncScheduler.initialize();
  } catch (_) {
    // Background scheduling is an enhancement; never block app startup.
  }
  runApp(const ProviderScope(child: BuddyWizeApp()));
}
