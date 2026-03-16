import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../../detection/detection_provider.dart';
import '../../detection/model/stream_detections.dart';
import 'bounding_box_painter.dart';

class StreamTile extends StatefulWidget {
  final String path;
  final String state;
  final DetectionProvider detectionProvider;

  const StreamTile({
    super.key,
    required this.path,
    required this.state,
    required this.detectionProvider,
  });

  @override
  State<StreamTile> createState() => _StreamTileState();
}

class _StreamTileState extends State<StreamTile> {
  bool _showBoxes = true;

  Color _statusColor() {
    switch (widget.state.toLowerCase()) {
      case 'publishing':
      case 'active':
        return Colors.greenAccent;
      case 'idle':
        return Colors.amber;
      default:
        return Colors.redAccent;
    }
  }

  String _statusLabel() {
    switch (widget.state.toLowerCase()) {
      case 'publishing':
      case 'active':
        return 'Ativo';
      case 'idle':
        return 'Idle';
      default:
        return 'Erro';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // ── Camada 1: Stream de vídeo ────────────────────────────────
        InAppWebView(
          initialUrlRequest: URLRequest(
            url: WebUri('http:/localhost:8889/${widget.path}'),
          ),
        ),

        // ── Camada 2: Bounding boxes ─────────────────────────────────
        // IgnorePointer garante que o overlay não bloqueie eventos da WebView
        IgnorePointer(
          child: ListenableBuilder(
            listenable: widget.detectionProvider,
            builder: (context, _) {
              final sd = widget.detectionProvider.forStream(widget.path);
              return LayoutBuilder(
                builder: (context, constraints) {
                  return CustomPaint(
                    size: Size(constraints.maxWidth, constraints.maxHeight),
                    painter: BoundingBoxPainter(
                      detections: _showBoxes ? sd.detections : [],
                      frameWidth: sd.frameWidth,
                      frameHeight: sd.frameHeight,
                      showLabels: _showBoxes,
                    ),
                  );
                },
              );
            },
          ),
        ),

        // ── Camada 3: Overlay de info (path + status + toggle) ───────
        Positioned(
          bottom: 8,
          left: 8,
          right: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.55),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                // Indicador de status
                AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _statusColor(),
                    boxShadow: [
                      BoxShadow(
                        color: _statusColor().withOpacity(0.7),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Nome do stream
                Expanded(
                  child: Text(
                    widget.path,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      overflow: TextOverflow.ellipsis,
                    ),
                    maxLines: 1,
                  ),
                ),

                const SizedBox(width: 8),

                // Rótulo do estado
                Text(
                  _statusLabel(),
                  style: TextStyle(
                    color: _statusColor(),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(width: 8),

                // Toggle bounding boxes
                GestureDetector(
                  onTap: () => setState(() => _showBoxes = !_showBoxes),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      _showBoxes
                          ? Icons.grid_on_rounded
                          : Icons.grid_off_rounded,
                      key: ValueKey(_showBoxes),
                      color: _showBoxes ? Colors.cyanAccent : Colors.white54,
                      size: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
