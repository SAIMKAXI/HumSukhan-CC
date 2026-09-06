import 'package:integration_test/integration_test.dart';

import '../test/journeys/journey_scenarios.dart';

/// The three journeys, on a physical device.
///
/// Identical to the headless suite except for the binding: here the app runs
/// against the real platform, which is the only place a microphone permission,
/// a speech engine or a foreground service can actually be exercised.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  registerJourneyTests();
}
