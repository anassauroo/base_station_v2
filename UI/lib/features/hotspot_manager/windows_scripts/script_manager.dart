import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';


class AppFiles {
  /// Retorna a pasta do app (Support\AppVersion) e garante que exista
  static Future<Directory> ensureAppDir() async {
    final support = await getApplicationSupportDirectory(); // Roaming
    final info = await PackageInfo.fromPlatform();
    final dir = Directory(p.join(support.path, info.version));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static Future<File> writeStringToAppDir(
      String fileName,
      String content, {
        bool overwrite = true,
      }) async {
    final dir = await ensureAppDir();
    final dest = File(p.join(dir.path, fileName));

    if (!overwrite && await dest.exists()) {
      return dest; // mantém o existente
    }

    await dest.writeAsString(
      content,
      encoding: utf8,
      flush: true,
    );

    return dest;
  }
}
