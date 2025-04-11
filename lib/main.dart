import 'package:appproxy/ui/app_config_proxy.dart';
import 'package:appproxy/ui/proxy_list_home.dart';
import 'package:appproxy/ui/proxy_settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

import 'generated/l10n.dart';
// Import mới
import 'widgets/auth_wrapper.dart';

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
    const Color primaryOrange = Color(0xFFEA580C);
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
          seedColor: Colors.white,
          primary: Color(0xFFEA580C),
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
            Colors.black, // Để null để nó tự lấy màu từ theme
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
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          // Nền có thể là màu đen mờ hoặc cùng màu với Scaffold
          backgroundColor: Colors.black.withOpacity(0.9), // Đen đậm hơn chút?
          // backgroundColor: Colors.grey[900], // Hoặc cùng màu Scaffold

          selectedItemColor: primaryOrange,       // Màu cam cho item được chọn (Đã ổn)
          unselectedItemColor: Colors.grey[600],  // Màu xám cho item không được chọn (Đã ổn)

          // Có thể ẩn label của item không được chọn nếu muốn gọn hơn
          // showUnselectedLabels: false,
          showSelectedLabels: true,
          showUnselectedLabels: true, // Giữ lại label để người dùng biết rõ các tab

          elevation: 0, // Không có shadow (Đã ổn)

          // Style cho label (Đã ổn với font Afacad)
          selectedLabelStyle: GoogleFonts.afacad(fontWeight: FontWeight.w600, fontSize: 12),
          unselectedLabelStyle: GoogleFonts.afacad(fontWeight: FontWeight.w500, fontSize: 12),

          // Icon theme: Đồng nhất kích thước icon
          selectedIconTheme: const IconThemeData(size: 24), // Kích thước khi chọn
          unselectedIconTheme: const IconThemeData(size: 24), // Kích thước khi không chọn

          // Kiểu thanh bar (fixed là mặc định khi < 4 item và ổn)
          // type: BottomNavigationBarType.fixed,
        ),
      ),
      themeMode: ThemeMode.dark,
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

  // Khai báo danh sách các trang con
  final List<Widget> _children = <Widget>[
    const ProxyListHome(), // Trang mới đã cập nhật
    const AppConfigList(),
    const AppSettings(),
  ];

  // --- Hàm xây dựng AppBar động ---
  AppBar? _buildAppBar(BuildContext context, S s) {
    // Chỉ hiển thị AppBar cho tab đầu tiên (index = 0)
    if (_currentIndex == 0) {
      final theme = Theme.of(context); // Lấy theme
      return AppBar(
        backgroundColor: Colors.white, // Màu nền giống Scaffold
        automaticallyImplyLeading: false, // Không có nút back tự động
        title: Text(
          'YeuProxy.com', // Tiêu đề
          // Sử dụng style từ theme, đảm bảo font và màu đúng
          style: theme.textTheme.displaySmall?.copyWith(
            fontFamily: GoogleFonts.afacad().fontFamily,
            color: theme.colorScheme.onBackground, // Màu chữ dựa trên theme
          ),
        ),
        // actions: [ // Nút hành động bên phải
          // IconButton(
          //   icon: FaIcon( // Icon dấu cộng
          //     FontAwesomeIcons.plus,
          //     color: theme.colorScheme.onBackground, // Màu icon dựa trên theme
          //     size: 22, // Điều chỉnh size icon
          //   ),
          //   tooltip: 'Add Proxy', // Tooltip cho accessibility
          //   onPressed: () {
          //     // TODO: Implement Add Proxy action (mở dialog, trang mới,...)
          //     ScaffoldMessenger.of(context).showSnackBar(
          //       const SnackBar(content: Text('Add Proxy Tapped! (Not Implemented)')),
          //     );
          //   },
          //   padding: const EdgeInsets.only(right: 15.0), // Padding bên phải
          // ),
        // ],
        centerTitle: false, // Tiêu đề căn trái
        elevation: 0, // Không có shadow
      );
    }
    // Trả về null nếu không phải tab đầu tiên (không hiển thị AppBar)
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context); // Lấy localization strings
    // final theme = Theme.of(context); // Không cần lấy theme ở đây nữa

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(context, s),
      body: IndexedStack(
        index: _currentIndex,
        children: _children,
      ),
      // BottomNavigationBar sẽ lấy style từ ThemeData
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        // --- Sử dụng FontAwesomeIcons cho các items ---
        items: <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            // Icon danh sách proxy (regular khi không chọn, solid khi chọn)
            icon: const FaIcon(FontAwesomeIcons.list), // Hoặc networkWired
            activeIcon: const FaIcon(FontAwesomeIcons.listCheck), // Hoặc networkWired
            label: s.text_proxy,
          ),
          BottomNavigationBarItem(
            // Icon cấu hình ứng dụng (vuông vắn hơn)
            icon: const FaIcon(FontAwesomeIcons.cubesStacked), // Hoặc squareCog, mobileScreenButton
            activeIcon: const FaIcon(FontAwesomeIcons.cubesStacked),
            label: s.text_configure,
          ),
          BottomNavigationBarItem(
            // Icon cài đặt (bánh răng)
            icon: const FaIcon(FontAwesomeIcons.gear), // Hoặc sliders
            activeIcon: const FaIcon(FontAwesomeIcons.gear),
            label: s.text_settings,
          ),
        ],
        // Các thuộc tính style đã được định nghĩa trong theme.bottomNavigationBarTheme
      ),
    );
  }
}

// Các class ProxyListHome, AppConfigList, AppSettings giữ nguyên
// (Bạn cần đảm bảo chúng tồn tại và được import đúng)