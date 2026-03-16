import 'dart:io';

import 'package:base_station_v2/features/hotspot_manager/presentation/wifi_config.dart';
import 'package:base_station_v2/features/hotspot_manager/windows_scripts/script_manager.dart';
import 'package:base_station_v2/features/hotspot_manager/windows_scripts/script_repo.dart';
import 'package:flutter/material.dart';
import 'package:process_run/process_run.dart';
import 'package:process_run/shell.dart' as shellTerm;
import 'package:shared_preferences/shared_preferences.dart';

class WifiCard extends StatefulWidget {
  const WifiCard({super.key});

  @override
  State<WifiCard> createState() => _WifiCardState();
}

class _WifiCardState extends State<WifiCard> {
  bool isOn = false;
  bool isLoading = false;
  bool isRunning = false;

  Color get color => isOn ? Theme.of(context).colorScheme.primary : Theme.of(context).disabledColor;

  @override
  void initState() {
    super.initState();
    updateHotSpotStatus();
    isRunning = true;
    autoRefresh();
  }


  @override
  void dispose() {
    isRunning = false;
    super.dispose();
  }

  Future<void> autoRefresh() async {
    updateHotSpotStatus();
    await Future.delayed(const Duration(seconds: 10));
    if (isRunning) {
      autoRefresh();
    }
  }


  Future<void> updateHotSpotStatus() async {
    //create windows script
    File file = await AppFiles.writeStringToAppDir("status.ps1", PSScriptRepo.accessPointStatus);
    var res = await shellTerm.run('powershell.exe -windowstyle hidden -file ${file.path}').catchError((e) => print(e));
    print(res.last.stdout);

    if (res.last.stdout.isNotEmpty) {
      setState(() {
        isOn = res.last.stdout.contains("True");
        isLoading = false;
      });
    }

  }

  Future<void> enableHotSpot({operation=true}) async {
    isLoading = true;
    setState(() {

    });
    String enableScript = PSScriptRepo.hotspotActivate;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String ssid = prefs.getString('accessPointSsid') ?? 'transpetro';
    final String password = prefs.getString('accessPointPassword') ?? 'transpetro';

    enableScript = enableScript.replaceAll("<YOUR SSID HERE>", '"$ssid"');
    enableScript = enableScript.replaceAll("<PASSWORD HERE>", '"$password"');
    if (!operation) enableScript = enableScript.replaceAll("StartTetheringAsync", "StopTetheringAsync");

    File file = await AppFiles.writeStringToAppDir("enable.ps1", enableScript);
    var res = await shellTerm.run('powershell.exe -windowstyle hidden -file ${file.path}').catchError((e) => print(e));
    updateHotSpotStatus();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      height: 100,
      child: Card(
        child: Stack(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  Icons.wifi,size: 70,color: color,),
                if (!isLoading)...[Switch(value: isOn, onChanged: (value){
                  isLoading = true;
                  setState(() {});
                  enableHotSpot(operation: value);


                }),
        ],
                if (isLoading)...[
                  Center(child: const CircularProgressIndicator()),
                ]
              ]
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
        
                Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(onPressed: ()async{
                      final saved = await showWifiConfigDialog(context);
                      if (saved == true && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Configurações salvas reiniciando hotspot.')),
                        );
                        enableHotSpot();
                      }

                    }, icon: Icon(Icons.settings)),
                  ],
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
