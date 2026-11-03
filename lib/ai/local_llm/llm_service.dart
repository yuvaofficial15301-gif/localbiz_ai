import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/services/settings_service.dart';

enum LlmState { notInstalled, installed, incompatible, loaded, runtimeMissing }

class LlmStatus {
  final LlmState state;
  final String? path;
  final int? bytes;
  final int? deviceRamKb;
  final String message;
  const LlmStatus(this.state, this.message,
      {this.path, this.bytes, this.deviceRamKb});
}

/// Contract for an on-device inference runtime (e.g. llama.cpp via FFI).
/// The runtime must only ever produce *structured intent JSON*; it never
/// executes actions and never computes business numbers.
abstract class LlmEngine {
  bool get isLoaded;
  Future<void> load(String modelPath);
  Future<String?> extractIntentJson(String prompt);
  Future<void> unload();
}

/// Default engine: no native runtime is bundled in this build.
class UnavailableLlmEngine implements LlmEngine {
  @override
  bool get isLoaded => false;
  @override
  Future<void> load(String modelPath) async {
    throw UnsupportedError(
        'No on-device inference runtime is bundled in this build.');
  }

  @override
  Future<String?> extractIntentJson(String prompt) async => null;
  @override
  Future<void> unload() async {}
}

/// Model file management: import, compatibility check, replacement.
class LocalLlmService {
  static const recommendedModel =
      'Qwen2.5-1.5B-Instruct Q4_K_M (GGUF, about 1.1 GB, needs about 2 GB free RAM)';
  static const smallerModel =
      'Llama-3.2-1B-Instruct Q4_K_M (GGUF, about 0.8 GB, needs about 1.5 GB free RAM)';

  final SettingsService settings;
  LlmEngine engine;
  LocalLlmService(this.settings, {LlmEngine? engine})
      : engine = engine ?? UnavailableLlmEngine();

  Future<Directory> modelDir() async {
    final base = await getApplicationSupportDirectory();
    final d = Directory(p.join(base.path, 'models'));
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  static Future<int?> deviceTotalRamKb() async {
    try {
      final lines = await File('/proc/meminfo').readAsLines();
      for (final l in lines) {
        if (l.startsWith('MemTotal:')) {
          final m = RegExp(r'(\d+)').firstMatch(l);
          return m == null ? null : int.parse(m.group(1)!);
        }
      }
    } catch (_) {}
    return null;
  }

  static Future<bool> hasGgufHeader(String path) async {
    final raf = await File(path).open();
    try {
      final head = await raf.read(4);
      return head.length == 4 &&
          head[0] == 0x47 && head[1] == 0x47 && head[2] == 0x55 && head[3] == 0x46;
    } finally {
      await raf.close();
    }
  }

  Future<LlmStatus> status() async {
    final path = await settings.get('llm_model_path');
    if (path == null || !await File(path).exists()) {
      return const LlmStatus(LlmState.notInstalled,
          'No model installed. The built-in command engine is handling everything.');
    }
    final bytes = await File(path).length();
    final ram = await deviceTotalRamKb();
    if (ram != null && bytes * 1.5 > ram * 1024) {
      return LlmStatus(LlmState.incompatible,
          'This model is too large for this phone\'s memory.',
          path: path, bytes: bytes, deviceRamKb: ram);
    }
    if (engine.isLoaded) {
      return LlmStatus(LlmState.loaded, 'Model loaded.',
          path: path, bytes: bytes, deviceRamKb: ram);
    }
    if (engine is UnavailableLlmEngine) {
      return LlmStatus(LlmState.runtimeMissing,
          'Model file is installed, but this build has no inference runtime. The built-in command engine is used.',
          path: path, bytes: bytes, deviceRamKb: ram);
    }
    return LlmStatus(LlmState.installed, 'Model installed, not loaded.',
        path: path, bytes: bytes, deviceRamKb: ram);
  }

  /// Copies a user-selected .gguf into app storage after validating it.
  Future<String> importModel(String sourcePath,
      {void Function(double)? onProgress}) async {
    final src = File(sourcePath);
    if (!await src.exists()) throw StateError('File not found');
    if (!await hasGgufHeader(sourcePath)) {
      throw StateError('This is not a valid GGUF model file');
    }
    final total = await src.length();
    final dir = await modelDir();
    final dest = File(p.join(dir.path, p.basename(sourcePath)));
    final free = await _freeSpaceOk(dir, total);
    if (!free) throw StateError('Not enough free storage for this model');
    final sink = dest.openWrite();
    var done = 0;
    await for (final chunk in src.openRead()) {
      sink.add(chunk);
      done += chunk.length;
      onProgress?.call(total == 0 ? 1 : done / total);
    }
    await sink.flush();
    await sink.close();
    final old = await settings.get('llm_model_path');
    await settings.set('llm_model_path', dest.path);
    if (old != null && old != dest.path) {
      try {
        await File(old).delete();
      } catch (_) {}
    }
    return dest.path;
  }

  Future<bool> _freeSpaceOk(Directory dir, int needed) async {
    // dart:io has no free-space API; attempt is guarded by write errors.
    return needed >= 0;
  }

  Future<void> removeModel() async {
    final path = await settings.get('llm_model_path');
    await engine.unload();
    if (path != null) {
      try {
        await File(path).delete();
      } catch (_) {}
    }
    await settings.set('llm_model_path', '');
  }

  Future<void> load() async {
    final path = await settings.get('llm_model_path');
    if (path == null || path.isEmpty) throw StateError('No model installed');
    await engine.load(path);
  }

  Future<void> unload() => engine.unload();
}
