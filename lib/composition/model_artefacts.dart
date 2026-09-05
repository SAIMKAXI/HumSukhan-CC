import 'package:humsukhan/infrastructure/model/model_repository.dart';

/// The artefacts that ship in the bundle, with the digests a good copy has.
///
/// The values are produced by `tool/verify_model_assets.sh` and asserted by
/// `test/composition/model_artefacts_test.dart` against the real files, so a
/// swapped or truncated asset fails the build rather than the device.
abstract final class ModelArtefacts {
  /// CED-Tiny INT8, the audio tagger.
  static const ModelArtefact cedTinyModel = ModelArtefact(
    assetPath: 'assets/models/ced-tiny-int8.onnx',
    fileName: 'ced-tiny-int8.onnx',
    sha256: '73aa22e783115f6a4ae169b36089907e07d0fd44795595eddea9c1bfc74cc945',
    sizeBytes: 6133417,
  );

  /// The 527 AudioSet class labels.
  static const ModelArtefact cedTinyLabels = ModelArtefact(
    assetPath: 'assets/models/ced-tiny-labels.csv',
    fileName: 'ced-tiny-labels.csv',
    sha256: 'cdd1049833c4b86127c2773ac0d14a2754b6a6d0d1798002ed5c66e699708429',
    sizeBytes: 14675,
  );
}
