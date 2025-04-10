import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart'; // Import iyueMainPage
import '../ui/login_page.dart'; // Import LoginPage

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  Future<bool> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    // Mặc định là false nếu chưa từng đăng nhập/lưu
    return prefs.getBool('isLoggedIn') ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _checkLoginStatus(),
      builder: (context, snapshot) {
        // Đang chờ kiểm tra trạng thái
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              // Hiển thị màn hình chờ đơn giản
              child: CircularProgressIndicator(),
            ),
          );
        }

        // Đã kiểm tra xong
        if (snapshot.hasData) {
          final bool isLoggedIn = snapshot.data!;
          if (isLoggedIn) {
            // Nếu đã đăng nhập -> vào màn hình chính
            return const iyueMainPage();
          } else {
            // Nếu chưa đăng nhập -> vào màn hình login
            return const LoginPage();
          }
        }

        // Nếu có lỗi trong quá trình kiểm tra (hiếm khi xảy ra với SharedPreferences đơn giản)
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Text('Lỗi kiểm tra đăng nhập: ${snapshot.error}'),
            ),
          );
        }

        // Trường hợp khác (mặc định về login để an toàn)
        return const LoginPage();
      },
    );
  }
}