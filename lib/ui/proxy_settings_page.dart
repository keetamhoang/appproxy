import 'package:yeuproxy/data/common.dart'; // Giữ lại nếu AppSetings ở đây
import 'package:yeuproxy/ui/app_update.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart'; // Import để dùng trong showAboutDialog nếu cần
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:version/version.dart';

import '../generated/l10n.dart'; // Import S

class AppSettings extends StatefulWidget {
  const AppSettings({super.key});

  @override
  State<AppSettings> createState() => _AppSettingsState();
}

class _AppSettingsState extends State<AppSettings> {
  // --- State Variables (Giữ nguyên) ---
  String _version = "v0"; // Hiển thị phiên bản
  String _arch = "";     // Kiến trúc CPU
  bool _isCheckUpdate = true; // Trạng thái switch
  bool _isLoadingInfo = true; // Thêm state loading ban đầu
  // --- End State Variables ---

  // --- Logic Functions (Giữ nguyên, thêm xử lý loading) ---
  @override
  void initState() {
    super.initState();
    _loadInitialData(); // Gọi hàm load mới
  }

  Future<void> _loadInitialData() async {
    // Bắt đầu loading
    if (mounted) setState(() => _isLoadingInfo = true);
    try {
      await _initDeviceInfo(); // Lấy thông tin device và version
    } catch (e) {
      print("Error loading initial data: $e");
      // Có thể hiển thị lỗi nếu cần
    } finally {
      // Kết thúc loading dù thành công hay lỗi
      if (mounted) setState(() => _isLoadingInfo = false);
    }
  }


  Future<void> _initDeviceInfo() async { // Đổi thành async và trả về Future
    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    // Sử dụng try-catch để bắt lỗi nếu không lấy được thông tin
    try {
      AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
      _arch = androidInfo.supportedAbis.isNotEmpty ? androidInfo.supportedAbis[0] : "unknown";
    } catch (e) {
      print("Error getting device info: $e");
      _arch = "unknown";
    }

    try {
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      _version = packageInfo.version.isNotEmpty ? 'v${packageInfo.version}' : 'v?.?.?'; // Thêm 'v' và xử lý rỗng
    } catch (e) {
      print("Error getting package info: $e");
      _version = "v?.?.?";
    }

    try {
      _isCheckUpdate = await AppSetings.getCheckUpdate();
    } catch (e) {
      print("Error getting check update setting: $e");
      _isCheckUpdate = true; // Mặc định là true nếu lỗi
    }

    // Chỉ kiểm tra update nếu được bật và context còn tồn tại
    if (_isCheckUpdate && mounted) {
      // Không cần await ở đây, để nó chạy ngầm
      _triggerUpdateCheck();
    }
    // Không cần setState ở đây vì đã có trong _loadInitialData
  }

  // Hàm riêng để gọi kiểm tra update, tránh await trong initState/initDeviceInfo
  void _triggerUpdateCheck() {
    // Delay nhẹ để tránh gọi showDialog quá sớm
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted && _isCheckUpdate) { // Kiểm tra lại state và mounted
        print("Triggering update check...");
        showUpdateDialog(context, _version, _arch);
      }
    });
  }

  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      print('Could not launch $url');
      if(mounted){
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not launch URL: $url')),
        );
      }
      // Không throw Exception để tránh crash app
      // throw Exception('Could not launch $_url');
    }
  }
  // --- End Logic Functions ---


  @override
  Widget build(BuildContext context) {
    // --- Lấy Theme Data ---
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    const Color primaryOrange = Color(0xFFEA580C);
    final s = S.of(context); // Lấy localization
    // --- End Lấy Theme Data ---

    return Scaffold(
      backgroundColor: Colors.white,
      // --- AppBar đã được style từ theme ---
      appBar: AppBar(
        backgroundColor: Colors.white,
        // Không cần backgroundColor
        elevation: 0, // Cho phẳng hơn
        title: Text(s.text_settings, style: theme.appBarTheme.titleTextStyle),
      ),
      // --- Body ---
      body: _isLoadingInfo // Hiển thị loading nếu chưa lấy xong info
          ? Center(child: CircularProgressIndicator(color: colorScheme.primary))
          : ListView( // Sử dụng ListView thay Column để có thể cuộn nếu cần
        padding: const EdgeInsets.symmetric(vertical: 16.0), // Padding tổng thể
        children: [
          // --- Section: Version Update ---
          _buildSectionHeader(context, s.text_version_update),
          _buildSettingsTile(
            context: context,
            title: s.text_is_open_check_update,
            subtitle: '${s.text_current_version}: $_version', // Thêm version vào subtitle
            trailing: Switch(
              value: _isCheckUpdate,
              onChanged: (bool newValue) {
                setState(() {
                  _isCheckUpdate = newValue;
                });
                AppSetings.setCheckUpdate(newValue); // Lưu cài đặt
                // Nếu bật lại thì kiểm tra update ngay
                if (newValue) {
                  _triggerUpdateCheck();
                }
              },
              // Style Switch cho phù hợp theme
              activeColor: primaryOrange,
              activeTrackColor: primaryOrange.withOpacity(0.5),
              inactiveThumbColor: Colors.grey[400],
              inactiveTrackColor: Colors.grey[700],
            ),
            onTap: () {
              if (_isCheckUpdate) {
                print("Manual update check triggered.");
                showUpdateDialog(context, _version, _arch);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Update check is disabled.')),
                );
              }
            },
          ),
          const Divider(height: 1, thickness: 0.5), // Đường kẻ phân cách

          // --- Section: About ---
          _buildSectionHeader(context, s.text_about),
          _buildSettingsTile(
            context: context,
            title: '${s.text_about} YeuProxy', // Thay đổi title
            // subtitle: 'Version $_version', // Có thể thêm version ở đây nữa
            trailing: const Icon(Icons.info_outline), // Icon thông tin
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: 'YeuProxy', // Tên ứng dụng
                applicationVersion: _version, // Version đã lấy
                applicationIcon: Padding( // Icon ứng dụng (có thể dùng Image.asset nếu có logo)
                  padding: const EdgeInsets.all(8.0),
                  child: Icon(Icons.security, size: 40, color: colorScheme.primary),
                ),
                applicationLegalese: '© 2025 YeuProxy Team', // Copyright
                // Style cho dialog (lấy từ theme)
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
                    child: Text(s.text_describe, style: textTheme.bodyMedium),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Text('${s.text_update_time}：2025-04-15', style: textTheme.bodySmall?.copyWith(color: Colors.grey[500])), // Cập nhật ngày
                  ),
                ],
              );
            },
          ),
          const Divider(height: 1, thickness: 0.5),

          // Thêm các mục cài đặt khác nếu cần ở đây
          // Ví dụ:
          // _buildSectionHeader(context, "General"),
          // _buildSettingsTile(context: context, title: "Language", trailing: Icon(Icons.language), onTap: () { /* Mở cài đặt ngôn ngữ */ }),
          // const Divider(height: 1, thickness: 0.5),

        ],
      ),
    );
  }

  // --- Helper Widgets ---
  // Widget xây dựng tiêu đề cho mỗi section
  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 20.0, bottom: 8.0),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: Colors.grey[500], // Màu xám nhạt cho tiêu đề section
          fontWeight: FontWeight.bold,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  // Widget xây dựng một hàng cài đặt (ListTile)
  Widget _buildSettingsTile({
    required BuildContext context,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    return ListTile(
      title: Text(title, style: theme.textTheme.titleMedium),
      subtitle: subtitle != null ? Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[500])) : null,
      trailing: trailing,
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0), // Điều chỉnh padding
    );
  }
// --- End Helper Widgets ---
}


// --- Hàm showUpdateDialog (Giữ nguyên logic, chỉ sửa URL nguồn và bỏ retry phức tạp) ---
// Đặt hàm này bên ngoài class _AppSettingsState
Future<void> showUpdateDialog(BuildContext context, String version, String arch) async {
  // Chỉ dùng một nguồn update chính
  const String appproxyUpdateUrl = "https://yeuproxy.com/update.json"; // URL cố định
  String versionName = "0";
  String modifyContent = "";
  String downloadUrl = ""; // Sẽ được ghép arch sau

  final s = S.of(context); // Lấy S context

  try {
    var dio = Dio(BaseOptions(connectTimeout: Duration(seconds: 10))); // Thêm timeout
    print("Checking update from: $appproxyUpdateUrl");
    Response value = await dio.get(appproxyUpdateUrl);

    if (value.statusCode == 200 && value.data is Map) { // Kiểm tra kiểu dữ liệu
      final data = value.data;
      versionName = data['VersionName']?.toString() ?? "0"; // Xử lý null
      modifyContent = data['ModifyContent']?.toString() ?? "No update information."; // Xử lý null
      final baseUrl = data['DownloadUrl']?.toString(); // Xử lý null

      // Ghép arch vào URL nếu có base URL
      if (baseUrl != null && arch.isNotEmpty) {
        // Giả sử URL có dạng .../vX.Y.Z/app-ARCH-release.apk
        // Hoặc bạn có thể có cấu trúc URL khác trong JSON
        downloadUrl = '$baseUrl$versionName/app-$arch-release.apk';
        // Ví dụ khác nếu JSON trả về link đầy đủ cho từng arch:
        // downloadUrl = data['DownloadUrls']?[arch] ?? '';
      } else if (baseUrl != null) {
        // Trường hợp không phân biệt arch hoặc URL đã đầy đủ
        downloadUrl = baseUrl;
      }

      print("Update info: Version=$versionName, URL=$downloadUrl");

    } else {
      throw Exception('Invalid response format or status code: ${value.statusCode}');
    }

  } catch (e) {
    print("Error fetching update info: $e");
    // Hiển thị lỗi một lần duy nhất
    if (context.mounted) { // Kiểm tra context còn tồn tại không
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(s.text_get_version_info_check_networ),
        backgroundColor: Colors.orange,
      ));
    }
    return; // Dừng hàm nếu có lỗi
  }

  // --- So sánh phiên bản ---
  if (versionName == "0") {
    print("Invalid version name from server.");
    return; // Không hiển thị dialog nếu version name không hợp lệ
  }

  try {
    Version currentVer = Version.parse(version.replaceAll('v', ''));
    Version latestVer = Version.parse(versionName.replaceAll('v', ''));

    if (latestVer <= currentVer) {
      print('${s.text_current_latest}, current:$version, new:$versionName');
      if (context.mounted) { // Chỉ hiển thị SnackBar nếu không phải kiểm tra tự động ban đầu? (hoặc thêm flag)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(s.text_current_latest))
        );
      }
      return;
    }
  } catch (e) {
    print("Error parsing versions: $e");
    // Có thể hiển thị lỗi parse version nếu cần
    return;
  }


  // --- Hiển thị Dialog ---
  // Đảm bảo downloadUrl không rỗng
  if (downloadUrl.isEmpty) {
    print("Download URL is empty for version $versionName and arch $arch.");
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not find download link for your device.')),
      );
    }
    return;
  }

  // Tạo widget AppUpdate (đảm bảo widget này đã được style phù hợp theme tối)
  AppUpdate appUpdate = AppUpdate(
    version: version, // Phiên bản hiện tại
    versionName: versionName, // Phiên bản mới
    modifyContent: modifyContent, // Nội dung cập nhật
    downloadUrl: downloadUrl, // Link tải đã ghép arch
  );

  // Kiểm tra mounted trước khi showDialog
  if (context.mounted) {
    showDialog(
        context: context,
        barrierDismissible: false, // Không cho tắt dialog bằng cách chạm ra ngoài
        builder: (context) {
          return appUpdate; // Hiển thị dialog
        });
  }
}

// --- Hàm _launchUrl (giữ nguyên) ---
// Đặt hàm này bên ngoài class _AppSettingsState
Future<void> _launchUrl(String url) async {
  final Uri uri = Uri.parse(url);
  if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
    print('Could not launch $url');
    // Không throw Exception ở đây để tránh dừng app nếu không mở được link
  }
}