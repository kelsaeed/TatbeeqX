import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/providers.dart';
import 'core/storage/secure_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final storage = await TokenStorage.open();
  runApp(
    ProviderScope(
      overrides: [tokenStorageProvider.overrideWithValue(storage)],
      child: const TatbeeqXApp(),
    ),
  );
}
