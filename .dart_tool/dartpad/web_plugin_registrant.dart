// Flutter web plugin registrant file.
//
// Generated file. Do not edit.
//

// @dart = 2.13
// ignore_for_file: type=lint

import 'package:connectivity_plus/src/connectivity_plus_web.dart';
import 'package:device_info_plus/src/device_info_plus_web.dart';
import 'package:file_picker/_internal/file_picker_web.dart';
import 'package:firebase_analytics_web/firebase_analytics_web.dart';
import 'package:firebase_core_web/firebase_core_web.dart';
import 'package:firebase_database_web/firebase_database_web.dart';
import 'package:flutter_tts/flutter_tts_web.dart';
import 'package:share_plus/src/share_plus_web.dart';
import 'package:shared_preferences_web/shared_preferences_web.dart';
import 'package:url_launcher_web/url_launcher_web.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';

void registerPlugins([final Registrar? pluginRegistrar]) {
  final Registrar registrar = pluginRegistrar ?? webPluginRegistrar;
  ConnectivityPlusWebPlugin.registerWith(registrar);
  DeviceInfoPlusWebPlugin.registerWith(registrar);
  FilePickerWeb.registerWith(registrar);
  FirebaseAnalyticsWeb.registerWith(registrar);
  FirebaseCoreWeb.registerWith(registrar);
  FirebaseDatabaseWeb.registerWith(registrar);
  FlutterTtsPlugin.registerWith(registrar);
  SharePlusWebPlugin.registerWith(registrar);
  SharedPreferencesPlugin.registerWith(registrar);
  UrlLauncherPlugin.registerWith(registrar);
  registrar.registerMessageHandler();
}
