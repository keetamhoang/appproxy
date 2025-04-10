import 'package:appproxy/ui/app_config_list.dart';
import 'package:appproxy/ui/proxy_config_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';

// Import mới
import 'widgets/auth_wrapper.dart';
import 'ui/login_page.dart'; // Có thể không cần trực tiếp ở đây nhưng để rõ ràng

import 'generated/l10n.dart';
import 'ui/settings.dart';

// Thêm async và ensureInitialized
void main() async {
  // Đảm bảo Flutter bindings đã được khởi tạo trước khi dùng plugins
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final baseTextTheme = Theme.of(context).textTheme;
    final afacadTextTheme = GoogleFonts.afacadTextTheme(baseTextTheme);
    return MaterialApp(
      title: "Yêu Proxy",
      debugShowCheckedModeBanner: false,
      localeResolutionCallback: (Locale? locale, Iterable<Locale> supportedLocales) {
        var result =
        supportedLocales.where((element) => element.languageCode == locale?.languageCode);
        if (result.isNotEmpty) {
          debugPrint("Detected language: ${locale?.languageCode}");
          // Đơn giản hóa logic chọn ngôn ngữ
          if (locale?.languageCode == 'zh') {
            return const Locale('zh', 'CN');
          } else if (locale?.languageCode == 'en') {
            return const Locale('en', 'US');
          }
          // Thêm ngôn ngữ khác nếu cần, ví dụ tiếng Việt
          // else if (locale?.languageCode == 'vi') {
          //    return const Locale('vi', 'VN');
          // }
        }
        // Ngôn ngữ mặc định nếu không tìm thấy hoặc không hỗ trợ
        // Có thể chọn en hoặc zh tùy theo đối tượng người dùng chính
        debugPrint("Using default language: en_US");
        return const Locale('en', 'US');
      },
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: S.delegate.supportedLocales,
      theme: ThemeData(
        // --- Cân nhắc sử dụng Material 3 ---
        useMaterial3: true, // Bật Material 3 để có UI/UX hiện đại hơn
        colorScheme: ColorScheme.fromSeed(
          // Dùng màu seed để tạo bảng màu nhất quán theo Material 3
          seedColor: const Color.fromRGBO(149, 0, 255, 1.0),
          // primary: const Color.fromRGBO(149, 0, 255, 1.0), // Seed color sẽ tự tạo primary
          // secondary: Colors.amber, // Có thể tùy chỉnh secondary nếu muốn
          brightness: Brightness.light, // Chọn theme sáng hoặc tối
        ),
        textTheme: afacadTextTheme,
        appBarTheme: AppBarTheme(
          centerTitle: true,
          titleTextStyle: GoogleFonts.afacad(
            fontSize: 20, // Điều chỉnh size nếu cần
            fontWeight: FontWeight.w500, // Điều chỉnh weight nếu cần
            color: // Chọn màu phù hợp với AppBar của bạn (ví dụ: colorScheme.onPrimary)
            null, // Để null để nó tự lấy màu từ theme
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              textStyle: GoogleFonts.afacad( // Áp dụng cho ElevatedButton mặc định
                  fontWeight: FontWeight.w600,
                  fontSize: 16 // Size mặc định cho nút
              ),
            )
        ),
        // --- Tùy chỉnh thêm cho BottomNavigationBar nếu muốn ---
        // bottomNavigationBarTheme: BottomNavigationBarThemeData(
        //   selectedItemColor: Color.fromRGBO(149, 0, 255, 1.0),
        //   unselectedItemColor: Colors.grey,
        //   showUnselectedLabels: true, // Hiển thị label cho item không được chọn
        //   type: BottomNavigationBarType.fixed, // hoặc shifting
        // ),
      ),
      // --- Thay đổi home thành AuthWrapper ---
      home: const AuthWrapper(),
    );
  }
}

// --- Lớp iyueMainPage giữ nguyên logic cũ ---
class iyueMainPage extends StatefulWidget {
  const iyueMainPage({super.key});

  @override
  State<iyueMainPage> createState() => _iyueMainPageState();
}

class _iyueMainPageState extends State<iyueMainPage> {
  int _currentIndex = 0;

  // Không cần khởi tạo _children trong initState nữa nếu chúng không thay đổi
  // Khai báo trực tiếp để dễ quản lý hơn
  final List<Widget> _children = <Widget>[
    const ProxyListHome(),
    const AppConfigList(),
    const AppSettings(),
  ];

  // Bỏ initState nếu không có logic phức tạp nào khác cần chạy lúc khởi tạo

  @override
  Widget build(BuildContext context) {
    // Lấy S context ở đây để sử dụng trong BottomNavigationBarItem
    final s = S.of(context);

    return Scaffold(
      // Sử dụng IndexedStack để giữ state của các trang khi chuyển tab
      body: IndexedStack(
        index: _currentIndex,
        children: _children,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        // --- Cập nhật để dùng S.of(context) hoặc biến s đã lấy ---
        items: <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: const Icon(Icons.home_outlined), // Icon khác biệt hơn
            activeIcon: const Icon(Icons.home), // Icon khi được chọn
            label: s.text_proxy, // Sử dụng biến s
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.apps_outlined), // Icon khác biệt hơn
            activeIcon: const Icon(Icons.apps),
            label: s.text_configure, // Sử dụng biến s
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.settings_outlined), // Icon khác biệt hơn
            activeIcon: const Icon(Icons.settings),
            label: s.text_settings, // Sử dụng biến s
          ),
        ],
        // Thêm các tùy chỉnh style nếu muốn (hoặc đặt trong ThemeData)
        // selectedItemColor: Theme.of(context).colorScheme.primary,
        // unselectedItemColor: Colors.grey,
        // showUnselectedLabels: true,
      ),
    );
  }
}

// Các class ProxyListHome, AppConfigList, AppSettings giữ nguyên
// (Bạn cần đảm bảo chúng tồn tại và được import đúng)