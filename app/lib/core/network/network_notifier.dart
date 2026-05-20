import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'network_notifier.g.dart';

@riverpod
class NetworkNotifier extends _$NetworkNotifier {
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  @override
  bool build() {
    _subscription = Connectivity().onConnectivityChanged.listen((results) {
      final hasNetwork = results.any((r) => r != ConnectivityResult.none);
      if (state != hasNetwork) state = hasNetwork;
    });
    ref.onDispose(() => _subscription?.cancel());
    return true; // assume connected on init; stream will correct if offline
  }
}
