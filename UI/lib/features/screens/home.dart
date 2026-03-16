import 'package:base_station_v2/features/detection/detection_provider.dart';
import 'package:base_station_v2/features/hotspot_manager/presentation/wifi_card.dart';
import 'package:base_station_v2/features/screens/widgets/camera_grid.dart';
import 'package:base_station_v2/features/screens/widgets/stream_tile.dart';
import 'package:base_station_v2/features/stream_manager/StreamManager.dart';
import 'package:flutter/material.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // ── Estado ────────────────────────────────────────────────────────
  List<Widget> streams = [];
  String activeStreamsString = '';

  /// Provider de detecções: instanciado uma única vez aqui e passado
  /// para cada StreamTile. Só ele notifica, não a Home inteira.
  final DetectionProvider _detectionProvider = DetectionProvider();

  // ── Ciclo de vida ─────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    refresh();
  }

  @override
  void dispose() {
    _detectionProvider.dispose();
    super.dispose();
  }

  // ── Polling de streams ────────────────────────────────────────────
  Future<void> refresh() async {
    var tmp = await fetchConnections();

    final streamsNames =
        tmp.items.map((e) => '${e.id}-${e.path}-state:${e.state}').join(',');

    if (streamsNames == activeStreamsString ||
        streamsNames.contains('state:idle')) {
      await Future.delayed(const Duration(milliseconds: 1000));
      return refresh();
    }

    activeStreamsString = streamsNames;
    streams = [];
    setState(() {});

    await Future.delayed(const Duration(milliseconds: 500));

    streams = tmp.items
        .where((e) => e.path != '')
        .map(
          (e) => StreamTile(
            key: ValueKey(e.path), // chave estável por path
            path: e.path,
            state: e.state,
            detectionProvider: _detectionProvider,
          ),
        )
        .toList();

    // ── MOCK: injeta boxes de teste em todas as streams ──────────────
    // Remova ou comente este bloco quando integrar com o backend real.
    for (final e in tmp.items.where((e) => e.path != '')) {
      _detectionProvider.injectMock(
        path: e.path,
        frameWidth: 640,
        frameHeight: 480,
      );
    }
    // ────────────────────────────────────────────────────────────────

    setState(() {});

    await Future.delayed(const Duration(milliseconds: 1000));
    refresh();
  }

  // ── Build ─────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height,
            width: double.maxFinite,
            child: streams.length > 1
                ? Center(child: CameraGrid(streams: streams))
                : streams.isEmpty
                    ? const Center(
                        child: Text(
                          'Aguardando streams...',
                          style: TextStyle(color: Colors.white54),
                        ),
                      )
                    : streams[0],
          ),

          // Barra superior: WiFi card
          Row(
            children: [
              SizedBox(
                width: 125,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: WifiCard(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
