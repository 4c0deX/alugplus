import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Salva a foto ORIGINAL do item no armazenamento do app (disco) e gera uma
/// miniatura pequena (160px) que é a única mantida em memória RAM.
/// - Ícones/listas: usam a miniatura (leve, rápida).
/// - Janela de zoom: abre o arquivo original em tamanho completo.
class ItemImageService {
  ItemImageService._();

  static final ItemImageService instance = ItemImageService._();

  static const int thumbSize = 160;

  /// Cache RAM apenas de miniaturas (poucos KB cada).
  final Map<String, Uint8List> _thumbCache = {};
  final Set<String> _generating = {};

  Directory? _imagesDir;

  Future<Directory> getImagesDirectory() async {
    if (_imagesDir != null && await _imagesDir!.exists()) return _imagesDir!;
    Directory baseDir;
    try {
      baseDir = await getApplicationDocumentsDirectory();
    } catch (_) {
      baseDir = Directory.systemTemp;
    }
    final target =
        Directory(p.join(baseDir.path, 'alugplus_data', 'item_images'));
    if (!await target.exists()) await target.create(recursive: true);
    _imagesDir = target;
    return target;
  }

  bool _isNetwork(String path) {
    final uri = Uri.tryParse(path);
    return uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
  }

  String _thumbPath(String originalPath) {
    final dir = p.dirname(originalPath);
    final name = p.basenameWithoutExtension(originalPath);
    return p.join(dir, '${name}_thumb.png');
  }

  /// Copia a imagem original (sem recomprimir) e gera a miniatura.
  /// Retorna o caminho do arquivo original salvo no app.
  Future<String> saveImageToAppStorage(String sourcePath) async {
    final clean = sourcePath.trim();
    if (clean.isEmpty || _isNetwork(clean)) return clean;

    try {
      final source = File(clean);
      if (!await source.exists()) return clean;

      final dir = await getImagesDirectory();
      if (p.isWithin(p.normalize(dir.path), p.normalize(clean))) {
        await ensureThumbnail(clean);
        return clean;
      }

      final ext = p.extension(clean).isNotEmpty
          ? p.extension(clean).toLowerCase()
          : '.jpg';
      final dest = p.join(
        dir.path,
        'item_${DateTime.now().millisecondsSinceEpoch}_${clean.hashCode.abs()}$ext',
      );
      await source.copy(dest);
      await ensureThumbnail(dest);
      return dest;
    } catch (e) {
      debugPrint('ItemImageService save warning: $e');
      return clean;
    }
  }

  /// Gera (se necessário) a miniatura em disco e a coloca no cache RAM.
  Future<void> ensureThumbnail(String? originalPath) async {
    if (originalPath == null) return;
    final clean = originalPath.trim();
    if (clean.isEmpty || _isNetwork(clean)) return;
    if (_thumbCache.containsKey(clean)) return;

    try {
      final thumbFile = File(_thumbPath(clean));
      if (await thumbFile.exists()) {
        _thumbCache[clean] = await thumbFile.readAsBytes();
        return;
      }

      final original = File(clean);
      if (!await original.exists()) return;

      final bytes = await original.readAsBytes();
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: thumbSize,
      );
      final frame = await codec.getNextFrame();
      final data =
          await frame.image.toByteData(format: ui.ImageByteFormat.png);
      frame.image.dispose();
      codec.dispose();
      if (data == null) return;

      final thumbBytes = data.buffer.asUint8List();
      await thumbFile.writeAsBytes(thumbBytes, flush: true);
      _thumbCache[clean] = thumbBytes;
    } catch (e) {
      debugPrint('ItemImageService thumbnail warning: $e');
    }
  }

  /// Compatível com chamadas anteriores.
  Future<void> preloadFileIntoMemory(String? filePath) =>
      ensureThumbnail(filePath);

  /// Bytes da MINIATURA (RAM). Nunca carrega a imagem original na memória.
  Uint8List? getBytesSync(String? filePath) {
    if (filePath == null) return null;
    final clean = filePath.trim();
    if (clean.isEmpty || _isNetwork(clean)) return null;

    final cached = _thumbCache[clean];
    if (cached != null) return cached;

    try {
      final thumbFile = File(_thumbPath(clean));
      if (thumbFile.existsSync()) {
        final b = thumbFile.readAsBytesSync();
        _thumbCache[clean] = b;
        return b;
      }
    } catch (_) {}

    if (_generating.add(clean)) {
      ensureThumbnail(clean).whenComplete(() => _generating.remove(clean));
    }
    return null;
  }

  /// Arquivo original em tamanho completo (para a janela de zoom).
  File? originalFile(String? filePath) {
    if (filePath == null) return null;
    final clean = filePath.trim();
    if (clean.isEmpty || _isNetwork(clean)) return null;
    final f = File(clean);
    return f.existsSync() ? f : null;
  }
}
