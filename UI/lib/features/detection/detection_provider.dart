import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'model/stream_detections.dart';
import 'model/detection_box.dart';

/// Camada de estado para detecções.
///
/// Mantém um Map<path, StreamDetections> e notifica listeners apenas
/// quando as detecções de uma stream específica mudam — evitando
/// rebuild global da Home.
///
/// Para trocar a ORIGEM dos dados (polling, WebSocket, SSE…) basta
/// substituir o método [startListening] sem mexer na UI.
class DetectionProvider extends ChangeNotifier {
  final Map<String, StreamDetections> _detections = {};

  /// Retorna as detecções de uma stream. Nunca retorna null.
  StreamDetections forStream(String path) {
    return _detections[path] ?? StreamDetections.empty(path);
  }

  // ── Atualização ──────────────────────────────────────────────────

  /// Atualiza as detecções de uma stream e notifica apenas se mudou.
  void update(StreamDetections incoming) {
    _detections[incoming.path] = incoming;
    notifyListeners();
  }

  /// Remove as detecções de uma stream (ex: stream desconectada).
  void clear(String path) {
    if (_detections.containsKey(path)) {
      _detections.remove(path);
      notifyListeners();
    }
  }

  /// Atualiza a partir de uma lista JSON (formato batch do backend).
  void updateFromJsonList(List<dynamic> jsonList) {
    for (final item in jsonList) {
      update(StreamDetections.fromJson(item as Map<String, dynamic>));
    }
  }

  // ── Mock para testes ─────────────────────────────────────────────

  /// Injeta dados simulados para validar renderização sem backend real.
  ///
  /// [path]        : identificador da stream alvo
  /// [frameWidth]  : largura original do frame (ex: 640)
  /// [frameHeight] : altura original do frame  (ex: 480)
  void injectMock({
    required String path,
    double frameWidth = 640,
    double frameHeight = 480,
  }) {
    update(StreamDetections(
      path: path,
      frameWidth: frameWidth,
      frameHeight: frameHeight,
      detections: [
        DetectionBox(
          x: frameWidth * 0.1,
          y: frameHeight * 0.1,
          width: frameWidth * 0.3,
          height: frameHeight * 0.4,
          label: 'person',
          confidence: 0.92,
        ),
        DetectionBox(
          x: frameWidth * 0.55,
          y: frameHeight * 0.2,
          width: frameWidth * 0.25,
          height: frameHeight * 0.3,
          label: 'vehicle',
          confidence: 0.81,
        ),
      ],
      timestamp: DateTime.now(),
    ));
  }

  // ── Integração com backend real (polling HTTP) ───────────────────
  //
  // Descomente e ajuste a URL quando o backend estiver disponível.
  //
  // Timer? _pollTimer;
  //
  // void startPolling(String url, {Duration interval = const Duration(seconds: 1)}) {
  //   _pollTimer?.cancel();
  //   _pollTimer = Timer.periodic(interval, (_) async {
  //     try {
  //       final resp = await http.get(Uri.parse(url));
  //       if (resp.statusCode == 200) {
  //         final list = jsonDecode(resp.body) as List<dynamic>;
  //         updateFromJsonList(list);
  //       }
  //     } catch (_) {}
  //   });
  // }
  //
  // void stopPolling() => _pollTimer?.cancel();
  //
  // @override
  // void dispose() {
  //   _pollTimer?.cancel();
  //   super.dispose();
  // }
}
