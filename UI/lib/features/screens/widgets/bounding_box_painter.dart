import 'package:flutter/material.dart';
import '../detection/model/detection_box.dart';

/// Paleta de cores por classe detectada.
/// Adicione mais entradas conforme necessário.
const Map<String, Color> _labelColors = {
  'person': Color(0xFF00E676),
  'vehicle': Color(0xFF2979FF),
  'car': Color(0xFF2979FF),
  'truck': Color(0xFF651FFF),
  'bike': Color(0xFFFF6D00),
  'animal': Color(0xFFFFD600),
};

Color _colorForLabel(String label) {
  final key = label.toLowerCase();
  return _labelColors[key] ?? const Color(0xFFFF1744); // vermelho = desconhecido
}

/// Converte coordenadas do frame original para o espaço visual do widget,
/// respeitando letterboxing (contain): calcula a área real onde o vídeo
/// está sendo desenhado dentro do widget e aplica offsets corretos.
Rect _scaleBox({
  required DetectionBox box,
  required double frameWidth,
  required double frameHeight,
  required double displayWidth,
  required double displayHeight,
}) {
  // Escala "contain": mantém aspect ratio do frame dentro do widget
  final frameAspect = frameWidth / frameHeight;
  final displayAspect = displayWidth / displayHeight;

  double videoW, videoH, offsetX, offsetY;

  if (frameAspect > displayAspect) {
    // Barras pretas em cima e embaixo (letterbox vertical)
    videoW = displayWidth;
    videoH = displayWidth / frameAspect;
    offsetX = 0;
    offsetY = (displayHeight - videoH) / 2;
  } else {
    // Barras pretas nas laterais (pillarbox horizontal)
    videoH = displayHeight;
    videoW = displayHeight * frameAspect;
    offsetX = (displayWidth - videoW) / 2;
    offsetY = 0;
  }

  final scaleX = videoW / frameWidth;
  final scaleY = videoH / frameHeight;

  return Rect.fromLTWH(
    offsetX + box.x * scaleX,
    offsetY + box.y * scaleY,
    box.width * scaleX,
    box.height * scaleY,
  );
}

class BoundingBoxPainter extends CustomPainter {
  final List<DetectionBox> detections;
  final double frameWidth;
  final double frameHeight;
  final bool showLabels;

  const BoundingBoxPainter({
    required this.detections,
    required this.frameWidth,
    required this.frameHeight,
    this.showLabels = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (detections.isEmpty) return;

    for (final box in detections) {
      final color = _colorForLabel(box.label);
      final rect = _scaleBox(
        box: box,
        frameWidth: frameWidth,
        frameHeight: frameHeight,
        displayWidth: size.width,
        displayHeight: size.height,
      );

      // ── Retângulo ────────────────────────────────────────────────
      final borderPaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      canvas.drawRect(rect, borderPaint);

      // ── Fundo semitransparente do rótulo ─────────────────────────
      if (!showLabels) continue;

      final label =
          '${box.label} ${(box.confidence * 100).toStringAsFixed(0)}%';

      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            shadows: const [
              Shadow(blurRadius: 2, color: Colors.black),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final tagRect = Rect.fromLTWH(
        rect.left,
        rect.top - tp.height - 4,
        tp.width + 8,
        tp.height + 4,
      );

      canvas.drawRect(
        tagRect,
        Paint()..color = color.withOpacity(0.85),
      );

      tp.paint(canvas, Offset(tagRect.left + 4, tagRect.top + 2));
    }
  }

  @override
  bool shouldRepaint(BoundingBoxPainter oldDelegate) {
    return oldDelegate.detections != detections ||
        oldDelegate.frameWidth != frameWidth ||
        oldDelegate.frameHeight != frameHeight ||
        oldDelegate.showLabels != showLabels;
  }
}
