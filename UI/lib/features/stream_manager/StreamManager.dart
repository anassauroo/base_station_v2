import 'dart:convert';

import 'model/StreamInfos.dart';
import 'package:http/http.dart' as http;

Future<StreamInfos> fetchConnections() async {
  final uri = Uri.parse('http://localhost:9997/v3/rtmpconns/list');
  final resp = await http.Client()
      .get(uri, headers: {'Accept': 'application/json'})
      .timeout(const Duration(seconds: 10));

  if (resp.statusCode != 200) {
    throw Exception('Falha ${resp.statusCode}: ${resp.reasonPhrase}');
  }

  final map = jsonDecode(resp.body) as Map<String, dynamic>;
  return StreamInfos.fromJson(map);
}