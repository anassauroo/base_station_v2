import 'package:base_station_v2/features/stream_manager/model/StreamItem.dart';

class StreamInfos {
  final int itemCount;
  final int pageCount;
  final List<StreamItem> items; // cuidado: pode conflitar com dart:async::Stream

  StreamInfos({
    required this.itemCount,
    required this.pageCount,
    required this.items,
  });

  factory StreamInfos.fromJson(Map<String, dynamic> json) {
    return StreamInfos(
      itemCount: json['itemCount'] as int,
      pageCount: json['pageCount'] as int,
      items: (json['items'] as List<dynamic>)
          .map((e) => StreamItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'itemCount': itemCount,
      'pageCount': pageCount,
      'items': items.map((e) => e.toJson()).toList(),
    };
  }
}