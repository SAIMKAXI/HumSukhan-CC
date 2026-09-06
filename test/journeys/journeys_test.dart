import 'journey_scenarios.dart';

/// The three journeys, headless.
///
/// Same scenarios the device suite runs, so CI catches a broken flow without
/// waiting for hardware. The device run in `integration_test/` adds the real
/// microphone, engine and storage plugins on top.
void main() {
  registerJourneyTests();
}
