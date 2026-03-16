class StreamItem {
  final String id;
  final DateTime created;
  final String remoteAddr;
  final String state;
  final String path;
  final String query;
  final int bytesReceived;
  final int bytesSent;

  StreamItem({
    required this.id,
    required this.created,
    required this.remoteAddr,
    required this.state,
    required this.path,
    required this.query,
    required this.bytesReceived,
    required this.bytesSent,
  });

  factory StreamItem.fromJson(Map<String, dynamic> json) {
    return StreamItem(
      id: json['id'] as String,
      created: DateTime.parse(json['created'] as String),
      remoteAddr: json['remoteAddr'] as String,
      state: json['state'] as String,
      path: json['path'] as String,
      query: json['query'] as String,
      bytesReceived: json['bytesReceived'] as int,
      bytesSent: json['bytesSent'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'created': created.toIso8601String(),
      'remoteAddr': remoteAddr,
      'state': state,
      'path': path,
      'query': query,
      'bytesReceived': bytesReceived,
      'bytesSent': bytesSent,
    };
  }
}