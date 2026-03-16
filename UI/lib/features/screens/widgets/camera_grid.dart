import 'dart:math';
import 'package:flutter/material.dart';

class CameraGrid extends StatelessWidget {
  final List<Widget> streams;
  const CameraGrid({super.key, required this.streams});

  @override
  Widget build(BuildContext context) {
    final count = streams.length;

    // Calcula nº de colunas de forma inteligente (raiz quadrada arredondada)
    final columns = max(1, (sqrt(count)).ceil());

    return GridView.count(
      crossAxisCount: columns,
      childAspectRatio: 16 / 9, // mantém proporção de vídeo
      children: streams,
      shrinkWrap: true,
    );
  }
}