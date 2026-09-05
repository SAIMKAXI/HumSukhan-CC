import 'package:humsukhan/domain/environment/sound_event.dart';
import 'package:humsukhan/domain/settings/app_settings.dart';

/// Delivers an alert through whichever channels the user has enabled.
///
/// Every channel is non-auditory: the primary user cannot rely on sound
/// (design.md §7).
abstract interface class AlertPresenterPort {
  /// Raises [event] through the enabled [channels].
  Future<void> present(SoundEvent event, AlertChannels channels);
}
