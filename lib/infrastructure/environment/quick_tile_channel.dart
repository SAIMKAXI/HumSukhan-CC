import 'dart:async';

import 'package:flutter/services.dart';
import 'package:humsukhan/core/logging/app_logger.dart';
import 'package:humsukhan/domain/environment/quick_tile_port.dart';

/// [QuickTilePort] over the platform channel `MainActivity` installs.
final class QuickTileChannel implements QuickTilePort {
  /// Creates a channel.
  QuickTileChannel({
    MethodChannel? channel,
    AppLogger logger = const SilentLogger(),
  }) : _channel = channel ?? const MethodChannel('pk.humsukhan/quick_tile'),
       _logger = logger {
    _channel.setMethodCallHandler((MethodCall call) async {
      if (call.method == 'tileRequested' && !_requests.isClosed) {
        _requests.add(null);
      }
      return null;
    });
  }

  final MethodChannel _channel;
  final AppLogger _logger;
  final StreamController<void> _requests = StreamController<void>.broadcast();

  @override
  Stream<void> get requests => _requests.stream;

  @override
  Future<bool> consumePendingRequest() async {
    try {
      final bool? requested = await _channel.invokeMethod<bool>(
        'consumeTileRequest',
      );
      return requested ?? false;
    } on MissingPluginException {
      // iOS and tests have no tile. Not a failure, and not silent either.
      _logger.log(LogLevel.debug, 'tile', 'no quick tile on this platform');
      return false;
    } on PlatformException catch (error) {
      _logger.log(
        LogLevel.warning,
        'tile',
        'could not read the tile request',
        error: error,
      );
      return false;
    }
  }

  @override
  Future<void> publishActive({required bool active}) async {
    // Written through the same channel the tile reads from, rather than through
    // shared_preferences: the two sides would otherwise have to agree on a
    // storage backend and a value encoding, and a tile that always reads "off"
    // is worse than no tile.
    try {
      await _channel.invokeMethod<void>('publishActive', active);
    } on MissingPluginException {
      _logger.log(LogLevel.debug, 'tile', 'no quick tile on this platform');
    } on PlatformException catch (error) {
      _logger.log(
        LogLevel.warning,
        'tile',
        'could not publish the monitoring state',
        error: error,
      );
    }
  }

  /// Closes the request stream.
  Future<void> dispose() => _requests.close();
}
