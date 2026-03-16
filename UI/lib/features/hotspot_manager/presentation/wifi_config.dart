import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';


class WifiPrefs {
  static const _kSsid = 'accessPointSsid';
  static const _kPass = 'accessPointPassword';

  static Future<void> save({required String ssid, required String password}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kSsid, ssid);
    await prefs.setString(_kPass, password);
  }

  static Future<({String ssid, String password})> load() async {
    final prefs = await SharedPreferences.getInstance();
    return (
    ssid: prefs.getString(_kSsid) ?? '',
    password: prefs.getString(_kPass) ?? '',
    );
  }
}

Future<bool?> showWifiConfigDialog(BuildContext context) async {
  // Carrega valores salvos antes de abrir o diálogo
  final saved = await WifiPrefs.load();

  final formKey = GlobalKey<FormState>();
  final ssidCtrl = TextEditingController(text: saved.ssid);
  final passCtrl = TextEditingController(text: saved.password);
  bool obscure = true;

  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Configurar Wi-Fi'),
          content: Form(
            key: formKey,
            child: SizedBox(
              width: 420, // ajuda no Windows
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: ssidCtrl,
                    decoration: const InputDecoration(
                      labelText: 'SSID',
                      hintText: 'Nome da rede',
                      border: OutlineInputBorder(),
                    ),
                    textInputAction: TextInputAction.next,
                    validator: (v) {
                      final s = v?.trim() ?? '';
                      if (s.isEmpty) return 'Informe o SSID';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: passCtrl,
                    decoration: InputDecoration(
                      labelText: 'Senha',
                      hintText: 'Mínimo 8 caracteres',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(obscure ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setState(() => obscure = !obscure),
                        tooltip: obscure ? 'Mostrar senha' : 'Ocultar senha',
                      ),
                    ),
                    obscureText: obscure,
                    validator: (v) {
                      final s = v ?? '';
                      if (s.isEmpty) return 'Informe a senha';
                      if (s.trim().length < 8) return 'A senha deve ter pelo menos 8 caracteres';
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final ssid = ssidCtrl.text.trim();
                final pass = passCtrl.text; // não dar trim na senha se você quiser manter espaços
                await WifiPrefs.save(ssid: ssid, password: pass);
                // Fechar retornando true (salvou)
                // ignore: use_build_context_synchronously
                Navigator.of(ctx).pop(true);
              },
              child: const Text('Confirmar'),
            ),
          ],
        ),
      );
    },
  );
}