import 'dart:convert'; // Import để dùng jsonEncode
import 'package:dio/dio.dart'; // Import để bắt DioException
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../main.dart';
import '../core/api/api_client.dart'; // Import main.dart để có thể điều hướng đến iyueMainPage

// Đổi tên class thành LoginPage
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

// Đổi tên State thành _LoginPageState
class _LoginPageState extends State<LoginPage> {
  // Controller cho các trường nhập liệu
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  // State quản lý trạng thái loading của nút đăng nhập
  bool _isLoading = false;

  // GlobalKey cho Form để validate
  final _formKey = GlobalKey<FormState>();

  // GlobalKey cho Scaffold (ít khi cần nhưng giữ lại từ code gốc)
  final scaffoldKey = GlobalKey<ScaffoldState>();

  // Recognizer để xử lý nhấn vào link "Đăng ký"
  late TapGestureRecognizer _signUpRecognizer;

  @override
  void initState() {
    super.initState();
    // Khởi tạo Recognizer và gán hàm xử lý khi nhấn
    _signUpRecognizer = TapGestureRecognizer()..onTap = _navigateToSignUp;
  }

  @override
  void dispose() {
    // Dispose các controller và recognizer để tránh rò rỉ bộ nhớ
    _usernameController.dispose();
    _passwordController.dispose();
    _signUpRecognizer.dispose();
    super.dispose();
  }

  // --- Hàm xử lý logic đăng nhập bằng username/password ---
  Future<void> _performLogin() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _isLoading = true;
    });

    // Lấy instance của ApiClient
    final apiClient = ApiClient.instance;
    // Chuẩn bị dữ liệu gửi đi
    // !!! Đảm bảo key 'email' và 'password' khớp với yêu cầu của API
    final loginData = {
      'email': _usernameController.text, // Sử dụng controller phù hợp
      'password': _passwordController.text,
    };

    try {
      // Gọi API POST /api/login
      final response = await apiClient.post('/api/login', data: loginData);

      // Kiểm tra response thành công (theo yêu cầu: status 200 và status: 'success')
      if (response.statusCode == 200 && response.data['success'] == true) {
        // Lấy dữ liệu người dùng từ response
        // !!! Kiểm tra cấu trúc response.data['data']['user'] có đúng không
        final userData = response.data['data']?['user'];

        if (userData != null) {
          // Lưu trạng thái đăng nhập và dữ liệu người dùng vào SharedPreferences
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('isLoggedIn', true);
          // Mã hóa userData (Map) thành chuỗi JSON để lưu
          await prefs.setString('userData', jsonEncode(userData));

          // Log dữ liệu user đã lưu (để debug)
          debugPrint(
              "Login successful. User data saved: ${jsonEncode(userData)}");

          // Điều hướng đến trang chính
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const iyueMainPage()),
            );
          }
        } else {
          // Trường hợp API trả về 200 và success nhưng không có user data
          debugPrint("Login API success but user data is missing.");
          if (mounted) {
            _showErrorSnackbar(
                'Đăng nhập thành công nhưng thiếu dữ liệu người dùng.');
          }
        }
      } else {
        // Trường hợp API trả về 200 nhưng status không phải 'success' hoặc lỗi khác từ API
        String errorMessage =
            response.data['message'] ?? 'Thông tin đăng nhập không chính xác.';
        debugPrint(
            "Login API failed: Status ${response.statusCode}, Data: ${response.data}");
        if (mounted) {
          _showErrorSnackbar(errorMessage);
        }
      }
    } on DioException catch (e) {
      // Xử lý lỗi từ Dio (Network, Timeout, Server Error 4xx/5xx, ...)
      debugPrint("Login DioException: ${e.message}");
      String errorMessage = 'Đã xảy ra lỗi mạng hoặc máy chủ.';
      if (e.response != null) {
        // Cố gắng lấy thông báo lỗi từ server nếu có
        errorMessage = e.response?.data?['message'] ?? errorMessage;
      } else if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        errorMessage =
            'Không thể kết nối đến máy chủ, vui lòng kiểm tra lại mạng.';
      }
      if (mounted) {
        _showErrorSnackbar(errorMessage);
      }
    } catch (e) {
      // Xử lý các lỗi không mong muốn khác
      debugPrint("Login unexpected error: $e");
      if (mounted) {
        _showErrorSnackbar('Đã xảy ra lỗi không mong muốn.');
      }
    } finally {
      // Luôn tắt trạng thái loading sau khi hoàn tất (trừ khi đã điều hướng)
      if (mounted) {
        // Kiểm tra mounted lần nữa vì hàm có thể chạy xong sau khi widget bị hủy
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  // --- Hàm xử lý khi nhấn vào link "Đăng ký" ---
  Future<void> _navigateToSignUp() async {
    // URL của trang đăng ký
    final Uri url = Uri.parse('https://yeuproxy.com/console/register');
    // Cố gắng mở URL bằng trình duyệt bên ngoài
    if (!await launchUrl(
      url,
      mode: LaunchMode.externalApplication, // Ưu tiên mở bằng trình duyệt ngoài
    )) {
      // Xử lý lỗi nếu không thể mở URL
      debugPrint('Could not launch $url');
      // Kiểm tra widget còn tồn tại không trước khi hiển thị SnackBar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể mở liên kết: $url')),
        );
      }
    }
  }

  // --- Kết thúc hàm _navigateToSignUp ---

  @override
  Widget build(BuildContext context) {
    // Lấy kích thước màn hình
    final screenWidth = MediaQuery.sizeOf(context).width;
    final screenHeight = MediaQuery.sizeOf(context).height;
    // Định nghĩa màu cam để tái sử dụng
    const Color orangeColor = Color(0xFFEA580C);

    return GestureDetector(
      // Cho phép unfocus TextField khi chạm ra ngoài
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        key: scaffoldKey,
        // Màu nền chính của trang
        backgroundColor: Colors.black,
        body: Container(
          // Container chiếm toàn bộ màn hình
          width: screenWidth,
          height: screenHeight,
          child: Stack(
            children: [
              // --- Lớp ảnh nền ---
              Image.network(
                // URL ảnh nền
                'https://images.unsplash.com/photo-1625908921739-4e27cca88859?w=800&h=1200&fit=crop',
                width: screenWidth,
                height: screenHeight,
                fit: BoxFit.cover,
                // Đảm bảo ảnh che phủ toàn bộ không gian
                // Hiệu ứng mờ dần khi ảnh đang tải
                frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                  if (wasSynchronouslyLoaded) {
                    return child;
                  }
                  return AnimatedOpacity(
                    opacity: frame == null ? 0 : 1,
                    duration: const Duration(seconds: 1),
                    curve: Curves.easeOut,
                    child: child,
                  );
                },
                // Hiển thị widget thay thế nếu có lỗi tải ảnh
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey[800], // Màu nền xám tối
                    child: const Center(
                        child: Icon(Icons.error_outline,
                            color: Colors.white54, size: 40)),
                  );
                },
              ),
              // --- Lớp Gradient mờ phủ lên ảnh nền ---
              Container(
                width: screenWidth,
                height: screenHeight,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withOpacity(0.85), // Đậm hơn ở trên cùng
                      Colors.black.withOpacity(0.6), // Mờ dần
                      Colors.transparent // Trong suốt ở dưới cùng
                    ],
                    stops: const [0, 0.4, 1], // Vị trí chuyển màu
                    begin: Alignment.topCenter, // Bắt đầu từ trên
                    end: Alignment.bottomCenter, // Kết thúc ở dưới
                  ),
                ),
              ),
              // --- Lớp nội dung chính (Logo, Form, Nút) ---
              SafeArea(
                // Đảm bảo nội dung không bị che bởi tai thỏ, status bar
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  // Padding hai bên
                  child: Center(
                    // Căn giữa nội dung theo chiều dọc
                    child: SingleChildScrollView(
                      // Cho phép cuộn nếu nội dung quá dài (ví dụ khi bàn phím hiện)
                      child: Form(
                        // Bọc các trường nhập liệu bằng Form để validate
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          // Column chỉ chiếm chiều cao cần thiết
                          mainAxisAlignment: MainAxisAlignment.center,
                          // Căn giữa các thành phần trong Column
                          crossAxisAlignment: CrossAxisAlignment.center,
                          // Căn giữa các thành phần theo chiều ngang
                          children: [
                            // --- Logo ---
                            Image.asset(
                              'assets/images/logo.png',
                              // Đường dẫn đến file logo trong assets
                              width: screenWidth * 0.6,
                              // Chiều rộng logo bằng 60% chiều rộng màn hình
                              height: 150,
                              // Chiều cao cố định
                              fit: BoxFit.contain, // Đảm bảo logo không bị méo
                            ),
                            const SizedBox(height: 48),
                            // Khoảng cách dưới logo

                            // --- Trường nhập Tên đăng nhập ---
                            TextFormField(
                              controller: _usernameController,
                              keyboardType: TextInputType.text,
                              // Kiểu bàn phím
                              style: GoogleFonts.afacad(color: Colors.white),
                              // Font và màu chữ khi nhập
                              decoration: InputDecoration(
                                labelText: 'Tên đăng nhập',
                                // Nhãn hiển thị phía trên
                                labelStyle:
                                    GoogleFonts.afacad(color: Colors.white70),
                                // Font và màu nhãn
                                hintText: 'Nhập tên đăng nhập của bạn',
                                // Text gợi ý khi trường rỗng
                                hintStyle:
                                    GoogleFonts.afacad(color: Colors.white54),
                                // Font và màu gợi ý
                                prefixIcon: const Icon(Icons.person_outline,
                                    color: Colors.white70),
                                // Icon đầu dòng
                                filled: true,
                                // Bật nền cho trường
                                fillColor: Colors.white.withOpacity(0.1),
                                // Màu nền trắng mờ
                                border: OutlineInputBorder(
                                  // Viền mặc định (không hiển thị)
                                  borderRadius: BorderRadius.circular(28),
                                  borderSide: BorderSide.none,
                                ),
                                focusedBorder: OutlineInputBorder(
                                  // Viền khi trường được focus
                                  borderRadius: BorderRadius.circular(28),
                                  borderSide: const BorderSide(
                                      color: orangeColor, width: 1.5),
                                ),
                                errorBorder: OutlineInputBorder(
                                  // Viền khi có lỗi validation
                                  borderRadius: BorderRadius.circular(28),
                                  borderSide: const BorderSide(
                                      color: Colors.redAccent, width: 1),
                                ),
                                focusedErrorBorder: OutlineInputBorder(
                                  // Viền khi có lỗi và đang focus
                                  borderRadius: BorderRadius.circular(28),
                                  borderSide: const BorderSide(
                                      color: Colors.redAccent, width: 1.5),
                                ),
                              ),
                              validator: (value) {
                                // Hàm kiểm tra tính hợp lệ
                                if (value == null || value.isEmpty) {
                                  return 'Vui lòng nhập tên đăng nhập'; // Thông báo lỗi
                                }
                                return null; // Hợp lệ
                              },
                            ),
                            const SizedBox(height: 20),
                            // Khoảng cách giữa 2 trường

                            // --- Trường nhập Mật khẩu ---
                            TextFormField(
                              controller: _passwordController,
                              obscureText: true,
                              // Ẩn ký tự nhập (hiển thị dấu •••)
                              style: GoogleFonts.afacad(color: Colors.white),
                              // Font và màu chữ khi nhập
                              decoration: InputDecoration(
                                labelText: 'Mật khẩu',
                                labelStyle:
                                    GoogleFonts.afacad(color: Colors.white70),
                                hintText: 'Nhập mật khẩu của bạn',
                                hintStyle:
                                    GoogleFonts.afacad(color: Colors.white54),
                                prefixIcon: const Icon(Icons.lock_outline,
                                    color: Colors.white70),
                                filled: true,
                                fillColor: Colors.white.withOpacity(0.1),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(28),
                                  borderSide: BorderSide.none,
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(28),
                                  borderSide: const BorderSide(
                                      color: orangeColor, width: 1.5),
                                ),
                                errorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(28),
                                  borderSide: const BorderSide(
                                      color: Colors.redAccent, width: 1),
                                ),
                                focusedErrorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(28),
                                  borderSide: const BorderSide(
                                      color: Colors.redAccent, width: 1.5),
                                ),
                              ),
                              validator: (value) {
                                // Hàm kiểm tra tính hợp lệ
                                if (value == null || value.isEmpty) {
                                  return 'Vui lòng nhập mật khẩu';
                                }
                                // Có thể thêm các validation khác (ví dụ: độ dài tối thiểu)
                                return null; // Hợp lệ
                              },
                            ),
                            const SizedBox(height: 35),
                            // Khoảng cách dưới trường mật khẩu

                            // --- Nút Đăng nhập ---
                            // Hiển thị nút hoặc vòng xoay loading tùy theo state _isLoading
                            _isLoading
                                ? const CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        orangeColor), // Màu vòng xoay
                                  )
                                : ElevatedButton(
                                    onPressed: _performLogin,
                                    // Gọi hàm xử lý đăng nhập khi nhấn
                                    style: ElevatedButton.styleFrom(
                                      minimumSize:
                                          const Size(double.infinity, 56),
                                      // Nút rộng hết cỡ, cao 56
                                      padding: const EdgeInsets.all(8),
                                      // Padding bên trong nút
                                      backgroundColor: orangeColor,
                                      // Màu nền nút (cam)
                                      foregroundColor: Colors.white,
                                      // Màu chữ/icon (trắng)
                                      elevation: 3,
                                      // Độ nổi của nút
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                            28), // Bo tròn góc nút
                                      ),
                                      textStyle: GoogleFonts.afacad(
                                        // Font chữ cho nút
                                        fontSize: 20,
                                        fontWeight: FontWeight.w600, // Độ đậm
                                        letterSpacing: 0.0,
                                      ),
                                    ),
                                    child: const Text(
                                        'Đăng nhập'), // Chữ hiển thị trên nút
                                  ),

                            // --- Link Đăng ký (Sử dụng RichText) ---
                            const SizedBox(height: 20.0),
                            // Khoảng cách trên link đăng ký
                            RichText(
                              textAlign: TextAlign.center, // Căn giữa đoạn text
                              text: TextSpan(
                                // Style mặc định cho toàn bộ RichText (áp dụng cho phần text thường)
                                style: GoogleFonts.afacad(
                                  fontSize: 15,
                                  color: Colors.white70, // Màu trắng mờ
                                ),
                                children: <TextSpan>[
                                  // Phần text tĩnh "Chưa có tài khoản? "
                                  const TextSpan(
                                      text: 'Chưa có tài khoản? ',
                                      style: TextStyle(
                                        fontWeight: FontWeight
                                            .w400, // Độ đậm bình thường
                                      )),
                                  // Phần text link "Đăng ký"
                                  TextSpan(
                                    text: 'Đăng ký',
                                    style: const TextStyle(
                                      color: orangeColor,
                                      // Màu cam
                                      fontWeight: FontWeight.w600,
                                      // Đậm hơn
                                      decoration: TextDecoration.underline,
                                      // Có gạch chân
                                      decorationColor:
                                          orangeColor, // Màu gạch chân cũng là cam
                                    ),
                                    // Gán recognizer để làm cho phần text này có thể nhấn được
                                    recognizer: _signUpRecognizer,
                                  ),
                                ],
                              ),
                            ),
                            // --- Kết thúc Link Đăng ký ---

                            const SizedBox(height: 20),
                            // Khoảng trống dưới cùng màn hình
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
