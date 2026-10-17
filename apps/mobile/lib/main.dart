import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/env.dart';

void main() {
  runApp(
    ProviderScope(
      overrides: [envProvider.overrideWithValue(Env.fromDefines())],
      child: const LouangesApp(),
    ),
  );
}
