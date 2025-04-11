import 'package:yeuproxy/data/common.dart';
import 'package:yeuproxy/ui/app_update.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:version/version.dart';

import '../generated/l10n.dart';

class AppSettingsBk extends StatefulWidget {
  const AppSettingsBk({super.key});

  @override
  State<AppSettingsBk> createState() => _AppSettingsState();
}

class _AppSettingsState extends State<AppSettingsBk> {
  var _version = "v0";
  String _arch = "";
  bool _isCheckUpdate = true;

  void initDeviceInfo() async {
    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
    _arch = androidInfo.supportedAbis[0];
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    // 获取是否需要检测更新
    _isCheckUpdate = await AppSetings.getCheckUpdate();
    _version = packageInfo.version;
    if (_isCheckUpdate) {
      showUpdateDialog(context, _version, _arch);
    }
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    initDeviceInfo();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(S.current.text_settings),
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: Column(
        children: [
          Container(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.only(left: 10.0, top: 10.0),
            child: Text(S.of(context).text_version_update,
                style: const TextStyle(color: Colors.lightBlue)),
          ),
          GestureDetector(
            child: Card(
              child: Container(
                padding: const EdgeInsets.only(left: 10.0),
                width: MediaQuery.of(context).size.width,
                height: 50.0,
                child: Row(
                  children: [
                    Align(
                        alignment: Alignment.centerLeft,
                        child: Text(S.of(context).text_is_open_check_update)),
                    const Spacer(),
                    Switch(
                        value: _isCheckUpdate,
                        onChanged: (bool newValue) {
                          debugPrint(
                              '${S.of(context).text_check_update}:$newValue');
                          setState(() {
                            _isCheckUpdate = newValue;
                            AppSetings.setCheckUpdate(newValue);
                          });
                        })
                  ],
                ),
              ),
            ),
            onTap: () {
              // const AppUpdate();
              if (_isCheckUpdate) {
                // 开启更新检测
                showUpdateDialog(context, _version, _arch);
              }
            },
          ),
          Container(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.only(left: 10.0, top: 10.0),
            child: Text(S.of(context).text_about,
                style: const TextStyle(color: Colors.lightBlue)),
          ),
          const SizedBox(height: 10.0),
          GestureDetector(
            child: Card(
                child: Container(
              padding: const EdgeInsets.only(left: 10.0),
              width: MediaQuery.of(context).size.width,
              height: 50.0,
              child: Center(child: Text('${S.current.text_about} appproxy')),
            )),
            onTap: () {
              // 显示当前app的信息
              showAboutDialog(
                context: context,
                applicationName: 'appproxy',
                applicationVersion: _version,
                applicationIcon: const Icon(Icons.app_registration),
                applicationLegalese: 'Copyright © 2024 ...',
                children: [
                  Text(S.of(context).text_describe),
                  Text(S.of(context).text_author),
                  Text('${S.of(context).text_update_time}：2025-03-15'),
                  Row(
                    children: [
                      const Text('github:'),
                      TextButton(
                          onPressed: () {
                            _launchUrl('https://github.com/ys1231/appproxy');
                          },
                          child: const Text('appproxy')),
                    ],
                  ),
                ],
              );
            },
          )
        ],
      ),
    );
  }
}

Future<void> _launchUrl(_url) async {
  if (!await launchUrl(Uri.parse(_url), mode: LaunchMode.externalApplication)) {
    throw Exception('Could not launch $_url');
  }
}

/**
 * 显示更新对话框
 */
void showUpdateDialog(BuildContext context, String version, String arch,
    {url = '', retryCount = 0}) async {
  // 获取版本信息
  String appproxyUpdateUrl = url != ""
      ? url : "https://yeuproxy.com/update.json";
  // 使用dio获取版本信息
  String versionName = "0";
  String modifyContent = "";
  String DownloadUrl = "";
  try {
    var dio = Dio();
    Response value = await dio.get(appproxyUpdateUrl);
    var data = value.data;
    versionName = data['VersionName'];
    modifyContent = data['ModifyContent'];
    DownloadUrl = data['DownloadUrl'];
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(S.of(context).text_get_version_info_check_networ)));
    return;
  }

  Version ver1 = Version.parse(versionName.replaceAll('v', ''));
  Version ver2 = Version.parse(version.replaceAll('v', ''));
  if (ver1 <= ver2 || versionName == "0") {
    if (versionName == "0") {
      return;
    }
    debugPrint(
        '${S.of(context).text_current_latest},current:$version,new:$versionName');
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.of(context).text_current_latest)));
    return;
  }
  // 显示更新对话框
  AppUpdate appUpdate = AppUpdate(
    version: version,
    versionName: versionName,
    modifyContent: modifyContent,
    downloadUrl: DownloadUrl,
  );
  showDialog(
      context: context,
      builder: (context) {
        return appUpdate;
      });
}
