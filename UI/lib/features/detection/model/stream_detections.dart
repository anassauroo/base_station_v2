import 'detection_box.dart';

/// Agrupa as detecções de uma stream específica num dado instante.
class StreamDetections {
  /// Identificador estável da stream (mesmo valor de `path`).
  final String path;

  /// Dimensões do frame original em que as coordenadas foram geradas.
  final double frameWidth;
  final double frameHeight;

  final List<DetectionBox> detections;
  final DateTime? timestamp;

  const StreamDetections({
    required this.path,
    required this.frameWidth,
    required this.frameHeight,
    required this.detections,
    this.timestamp,
  });

  factory StreamDetections.fromJson(Map<String, dynamic> json) {
    return StreamDetections(
      path: json['path'] as String,
      frameWidth: (json['frameWidth'] as num).toDouble(),
      frameHeight: (json['frameHeight'] as num).toDouble(),
      detections: (json['detections'] as List<dynamic>)
          .map((e) => DetectionBox.fromJson(e as Map<String, dynamic>))
          .toList(),
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : null,
    );
  }

  /// Cria uma cópia vazia (sem detecções) para uma stream — útil como
  /// estado inicial antes de receber dados reais.
  factory StreamDetections.empty(String path) {
    return StreamDetections(
      path: path,
      frameWidth: 640,
      frameHeight: 480,
      detections: [],
    );
  }
}
