import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart' show ByteData, rootBundle;
import 'package:humsukhan/core/failure/failure.dart';
import 'package:humsukhan/core/logging/app_logger.dart';
import 'package:humsukhan/domain/environment/model_state.dart';

/// Describes one shipped artefact and how to recognise a good copy of it.
final class ModelArtefact {
  /// Creates an artefact description.
  const ModelArtefact({
    required this.assetPath,
    required this.fileName,
    required this.sha256,
    required this.sizeBytes,
  });

  /// Where the bundled copy lives.
  final String assetPath;

  /// The installed file's name.
  final String fileName;

  /// The expected digest of a good copy, lower-case hex.
  final String sha256;

  /// The expected size in bytes.
  final int sizeBytes;
}

/// Verifies that a loaded artefact actually works.
///
/// "Ready" means the tagger loaded it at least once — not that two files exist
/// on disk. The existence-only check is what turned a truncated download into a
/// permanent trap (B6).
typedef ModelLoadProbe = Future<bool> Function(
  String modelPath,
  String labelsPath,
);

/// Installs, verifies, heals and reports the on-device sound model.
final class BundledModelRepository implements ModelRepositoryPort {
  /// Creates a repository.
  BundledModelRepository({
    required Directory installDirectory,
    required ModelArtefact model,
    required ModelArtefact labels,
    required ModelLoadProbe probe,
    AppLogger logger = const SilentLogger(),
  }) : _directory = installDirectory,
       _model = model,
       _labels = labels,
       _probe = probe,
       _logger = logger;

  final Directory _directory;
  final ModelArtefact _model;
  final ModelArtefact _labels;
  final ModelLoadProbe _probe;
  final AppLogger _logger;

  final StreamController<ModelState> _states =
      StreamController<ModelState>.broadcast();

  ModelState _current = const ModelAbsent();
  Future<ModelState>? _inFlight;
  bool _disposed = false;

  @override
  ModelState get current => _current;

  @override
  Stream<ModelState> get state => _states.stream;

  @override
  Future<ModelState> ensureReady() {
    // One preparation at a time; concurrent callers share the same work rather
    // than racing to write the same files.
    return _inFlight ??= _prepare().whenComplete(() => _inFlight = null);
  }

  @override
  Future<void> quarantine() async {
    for (final ModelArtefact artefact in <ModelArtefact>[_model, _labels]) {
      final File file = File('${_directory.path}/${artefact.fileName}');
      if (file.existsSync()) {
        try {
          await file.delete();
        } on FileSystemException catch (error) {
          _logger.log(
            LogLevel.warning,
            'model',
            'could not remove ${artefact.fileName}',
            error: error,
          );
        }
      }
    }
    _emit(const ModelAbsent());
  }

  /// Releases the state stream.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _states.close();
  }

  Future<ModelState> _prepare() async {
    try {
      if (!_directory.existsSync()) {
        await _directory.create(recursive: true);
      }

      _emit(const ModelVerifying());

      File modelFile = File('${_directory.path}/${_model.fileName}');
      File labelsFile = File('${_directory.path}/${_labels.fileName}');

      if (!await _isIntact(modelFile, _model) ||
          !await _isIntact(labelsFile, _labels)) {
        // Anything unusable is discarded and re-installed from the bundle. No
        // failure here may be permanent.
        await quarantine();
        _emit(const ModelDownloading(null));
        final bool installed =
            await _installFromBundle(_model) &&
            await _installFromBundle(_labels);
        if (!installed) {
          return _fail(const ModelFailure(FailureCode.modelDownloadFailed));
        }
        modelFile = File('${_directory.path}/${_model.fileName}');
        labelsFile = File('${_directory.path}/${_labels.fileName}');
      }

      _emit(const ModelVerifying());
      if (!await _isIntact(modelFile, _model)) {
        return _fail(const ModelFailure(FailureCode.modelCorrupt));
      }

      // The decisive check: does it actually load?
      final bool loads = await _probe(modelFile.path, labelsFile.path);
      if (!loads) {
        await quarantine();
        return _fail(const ModelFailure(FailureCode.modelLoadFailed));
      }

      return _emit(ModelReady(modelFile.path));
    } on Object catch (error, stackTrace) {
      _logger.log(
        LogLevel.error,
        'model',
        'preparation failed',
        error: error,
        stackTrace: stackTrace,
      );
      return _fail(ModelFailure(FailureCode.modelLoadFailed, detail: '$error'));
    }
  }

  Future<bool> _installFromBundle(ModelArtefact artefact) async {
    try {
      final ByteData data = await rootBundle.load(artefact.assetPath);
      final File target = File('${_directory.path}/${artefact.fileName}');
      await target.writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        flush: true,
      );
      return true;
    } on Object catch (error, stackTrace) {
      _logger.log(
        LogLevel.error,
        'model',
        'could not install ${artefact.fileName} from the bundle',
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  /// Whether [file] is present, the expected length, and the expected digest.
  ///
  /// Length alone is what let a truncated download install as complete.
  Future<bool> _isIntact(File file, ModelArtefact artefact) async {
    if (!file.existsSync()) return false;
    final int length = await file.length();
    if (length != artefact.sizeBytes) {
      _logger.log(
        LogLevel.warning,
        'model',
        '${artefact.fileName} is $length bytes, expected ${artefact.sizeBytes}',
      );
      return false;
    }
    final Digest digest = sha256.convert(await file.readAsBytes());
    if (digest.toString() != artefact.sha256) {
      _logger.log(
        LogLevel.warning,
        'model',
        '${artefact.fileName} failed its checksum',
      );
      return false;
    }
    return true;
  }

  ModelState _fail(ModelFailure failure) => _emit(ModelFailed(failure));

  ModelState _emit(ModelState next) {
    _current = next;
    if (!_disposed && !_states.isClosed) _states.add(next);
    return next;
  }
}
