/// Reports what the Quick Settings tile asked for.
///
/// The tile never touches the microphone: it hands the request here, so there
/// stays exactly one owner of monitoring and one place that can explain a
/// failure to start.
abstract interface class QuickTilePort {
  /// Whether the app was launched by the tile asking to toggle monitoring.
  ///
  /// Consumed once: a rebuild must not toggle again.
  Future<bool> consumePendingRequest();

  /// Requests raised while the app was already running.
  Stream<void> get requests;

  /// Publishes whether monitoring is running, so the tile can show it.
  Future<void> publishActive({required bool active});
}
