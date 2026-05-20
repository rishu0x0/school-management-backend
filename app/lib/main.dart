import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sendotp_flutter_sdk/sendotp_flutter_sdk.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';

const _msg91WidgetId = '3664716e6457393138393133';
const _msg91AuthToken = '509550TgxMsbOhd69e240dcP1';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  OTPWidget.initializeWidget(_msg91WidgetId, _msg91AuthToken);
  await Supabase.initialize(
    url: const String.fromEnvironment('SUPABASE_URL', defaultValue: ''),
    anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: ''),
  );
  runApp(const ProviderScope(child: App()));
}
