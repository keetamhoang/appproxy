import 'package:appproxy/generated/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:markdown/markdown.dart' as md;

class AppUpdate extends StatefulWidget {
  AppUpdate(
      {super.key,
      required this.version,
      required this.versionName,
      required this.modifyContent,
      required this.downloadUrl});

  String version;
  String versionName;
  String modifyContent;
  String downloadUrl;

  @override
  State<AppUpdate> createState() => _AppUpdateState();
}

class _AppUpdateState extends State<AppUpdate> {
  static const platform = MethodChannel('cn.ys1231/appproxy/appupdate');

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final maxWidth = MediaQuery.of(context).size.width * 0.8; // 设置为屏幕宽度的80%
    final maxHeight = MediaQuery.of(context).size.height * 0.3; // 设置为屏幕高度的80%
    return AlertDialog(
        backgroundColor: Colors.grey[50],
        title: Text(
          S.of(context).text_update_tips,
          style: GoogleFonts.afacad(),
        ),
        content: Column(
            mainAxisSize: MainAxisSize.min, // 仅占用必要高度
            crossAxisAlignment: CrossAxisAlignment.start, // 左对齐
            children: [
              Align(
                  alignment: Alignment.centerLeft,
                  child: RichText(
                    text: TextSpan(
                      style: GoogleFonts.afacad(color: Colors.black),
                      children: [
                        TextSpan(
                          text: '${S.of(context).text_current_version}: ',
                        ),
                        TextSpan(
                          text: 'v${widget.version}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  )),
              Align(
                  alignment: Alignment.centerLeft,
                  child: RichText(
                    text: TextSpan(
                      style: GoogleFonts.afacad(color: Colors.black),
                      children: [
                        TextSpan(
                          text: '${S.of(context).text_latest_version}: ',
                        ),
                        TextSpan(
                          text: '${widget.versionName}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  )),
              Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    S.of(context).text_update_content,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 10,
                    style: GoogleFonts.afacad(fontSize: 14),
                  )),
              // child: Text('更新内容:${widget.modifyContent}',overflow: TextOverflow.ellipsis,maxLines: 10,)),
              const SizedBox(
                height: 4,
              ),
              SizedBox(
                  width: maxWidth,
                  height: maxHeight,
                  child: Markdown(
                    padding: const EdgeInsets.all(0.0),
                    selectable: true,
                    data: widget.modifyContent,
                    extensionSet: md.ExtensionSet(
                      md.ExtensionSet.gitHubFlavored.blockSyntaxes,
                      <md.InlineSyntax>[
                        md.EmojiSyntax(),
                        ...md.ExtensionSet.gitHubFlavored.inlineSyntaxes
                      ],
                    ),
                  )),
            ]),
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                child: Text(
                  S.of(context).text_cancel,
                  textAlign: TextAlign.end,
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
              SizedBox(
                width: maxWidth * 0.2,
              ),
              TextButton(
                child: Text(
                  S.of(context).text_download,
                  textAlign: TextAlign.end,
                ),
                onPressed: () {
                  debugPrint('download url: ${widget.downloadUrl}');
                  platform.invokeMethod("startDownload", widget.downloadUrl);
                  Navigator.of(context).pop();
                },
              ),
            ],
          )
        ]);
  }
}
