import 'package:appproxy/ui/proxy_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:dio/dio.dart'; // Import DioException
import 'package:intl/intl.dart'; // Import intl để format ngày giờ (nếu cần)

// Import model và API client
import '../../models/proxy_item.dart';
import '../../core/api/api_client.dart';

// Đổi tên lại thành ProxyListHome (nếu bạn đã đổi tên trước đó)
class ProxyListHome extends StatefulWidget {
  const ProxyListHome({super.key});

  @override
  State<ProxyListHome> createState() => _ProxyListHomeState();
}

class _ProxyListHomeState extends State<ProxyListHome> {
  // State variables
  bool _isLoading = true; // Bắt đầu ở trạng thái loading
  String? _errorMessage;
  List<ProxyItem> _proxyList = []; // Danh sách proxy lấy từ API

  @override
  void initState() {
    super.initState();
    // Gọi API khi widget được khởi tạo lần đầu
    _fetchProxyList();
  }

  @override
  void dispose() {
    super.dispose();
  }

  // --- Hàm gọi API để lấy danh sách proxy ---
  Future<void> _fetchProxyList() async {
    // Reset state trước khi fetch
    if (!mounted) return; // Kiểm tra trước khi gọi setState
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final apiClient = ApiClient.instance;

    try {
      final response = await apiClient.get('/api/proxy/list');

      if (!mounted) return; // Kiểm tra sau khi await

      if (response.statusCode == 200 && response.data['success'] == true) {
        // Parse dữ liệu từ response
        final List<dynamic> data = response.data['data'];
        setState(() {
          // Chuyển đổi list dynamic thành list ProxyItem
          _proxyList = data.map((item) => ProxyItem.fromJson(item)).toList();
          _isLoading = false;
        });
      } else {
        // Xử lý lỗi từ API (success = false hoặc status code khác 200)
        setState(() {
          _errorMessage = response.data['message'] ?? 'Failed to load proxy list.';
          _isLoading = false;
        });
      }
    } on DioException catch (e) {
      if (!mounted) return;
      // Xử lý lỗi Dio (network, server, etc.)
      setState(() {
        _errorMessage = _getDioErrorMessage(e); // Hàm helper lấy thông báo lỗi
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      // Xử lý lỗi khác
      setState(() {
        _errorMessage = 'An unexpected error occurred: $e';
        _isLoading = false;
      });
    }
  }

  // --- Hàm helper để lấy thông báo lỗi từ DioException ---
  String _getDioErrorMessage(DioException e) {
    String defaultMessage = 'Network or server error occurred.';
    if (e.response != null && e.response?.data is Map) {
      return e.response?.data['message'] ?? defaultMessage;
    } else if (e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.sendTimeout || e.type == DioExceptionType.receiveTimeout) {
      return 'Connection timeout. Please check your network.';
    } else if (e.type == DioExceptionType.cancel) {
      return 'Request cancelled.';
    }
    // Thêm các loại lỗi khác nếu cần
    return e.message ?? defaultMessage; // Lấy message gốc từ Dio nếu có
  }

  // --- Placeholder Navigation Functions (giữ nguyên) ---
  void _navigateToRotateSetting(ProxyItem item) { // Có thể truyền item vào nếu cần
    Navigator.push(
      context,
      MaterialPageRoute(
        // Builder tạo instance của ProxyDetailPage và truyền proxyItem vào
        builder: (context) => ProxyDetailPage(proxyItem: item),
      ),
      // (Tùy chọn) Bạn có thể await kết quả trả về từ trang detail nếu cần
      // .then((result) {
      //   if (result == true) { // Ví dụ: nếu trang detail trả về true khi có thay đổi
      //     _fetchProxyList(); // Làm mới danh sách
      //   }
      // });
    );
  }

  void _navigateToListProxyRunning(ProxyItem item) { // Có thể truyền item vào nếu cần
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Tapped play for proxy: ${item.token} (Status: ${item.status})')),
    );
    // TODO: Implement start/stop proxy logic and navigation
  }

  void _navigateToSubscription() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Navigate to Subscription (Not Implemented)')),
    );
    // TODO: Implement navigation
  }
  // --- End Placeholder Navigation Functions ---


  // --- Hàm build nội dung chính (Loading, Error, List) ---
  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: Colors.redAccent, size: 40),
              const SizedBox(height: 10),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.redAccent),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: Icon(Icons.refresh),
                label: Text('Retry'),
                onPressed: _fetchProxyList,
              )
            ],
          ),
        ),
      );
    }

    if (_proxyList.isEmpty) {
      return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.list_alt_outlined, size: 40, color: Colors.grey),
              const SizedBox(height: 10),
              const Text('No proxies found.'),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: Icon(Icons.refresh),
                label: Text('Refresh'),
                onPressed: _fetchProxyList,
              )
            ],
          )
      );
    }

    // --- Hiển thị ListView nếu có dữ liệu ---
    return ListView.builder(
      padding: const EdgeInsets.only(top: 12.0, bottom: 12.0), // Padding trên và dưới ListView
      itemCount: _proxyList.length,
      // Không cần shrinkWrap và primary=false khi nó nằm trong Expanded
      itemBuilder: (context, index) {
        final proxyItem = _proxyList[index];
        // Gọi hàm build item cho từng proxy
        return _buildProxyListItem(proxyItem);
      },
    );
  }

  // --- Hàm build một item trong danh sách ---
  Widget _buildProxyListItem(ProxyItem item) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    // (Tùy chọn) Format ngày hết hạn
    String formattedExpiry = item.expiredAt; // Mặc định
    final expiryDate = item.expiredDateTime;
    if (expiryDate != null) {
      // Ví dụ format: 02 Apr 2025, 19:54
      formattedExpiry = DateFormat('dd/MM/yyyy, HH:mm', Localizations.localeOf(context).languageCode).format(expiryDate);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: InkWell(
        splashColor: Colors.transparent,
        focusColor: Colors.transparent,
        hoverColor: Colors.transparent,
        highlightColor: Colors.transparent,
        onTap: () => _navigateToRotateSetting(item),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: theme.cardColor,
            boxShadow: [
              BoxShadow(
                blurRadius: 3,
                color: Colors.black.withOpacity(0.2),
                offset: const Offset(0.0, 1),
              )
            ],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisSize: MainAxisSize.max,
              children: [
                // --- Ảnh Icon ---
                Padding(
                  padding: const EdgeInsets.only(right: 12.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.asset(
                      'assets/images/internet.png', // Đảm bảo có ảnh này
                      width: 45,
                      height: 45,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          Container(width: 45, height: 45, color: Colors.grey[700], child: Icon(Icons.public_off, color: Colors.white54)),
                    ),
                  ),
                ),
                // --- Cột Text (Token, Type, Expired) ---
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min, // Co lại theo nội dung
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4.0),
                        child: Text(
                          // Hiển thị một phần token cho gọn
                          item.token.length > 15 ? '${item.token.substring(0, 8)}...${item.token.substring(item.token.length - 4)}' : item.token,
                          style: textTheme.titleMedium?.copyWith( // Dùng titleMedium thay vì headlineSmall
                            fontFamily: GoogleFonts.afacad().fontFamily,
                            fontWeight: FontWeight.w500,
                            // fontSize: 18, // Size có thể đã ổn từ theme
                            letterSpacing: 0.0,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4.0),
                        child: AutoSizeText(
                          item.type.toUpperCase(), // Hiển thị loại proxy (viết hoa)
                          style: textTheme.bodySmall?.copyWith( // Dùng bodySmall cho đỡ chiếm chỗ
                            fontFamily: GoogleFonts.afacad().fontFamily,
                            letterSpacing: 0.0,
                            color: colorScheme.primary, // Màu cam
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                        ),
                      ),
                      // (Tùy chọn) Hiển thị ngày hết hạn đã format
                      Text(
                        'Expires: $formattedExpiry',
                        style: textTheme.labelSmall?.copyWith( // Dùng labelSmall
                          color: Colors.grey[500], // Màu xám nhạt hơn
                          fontFamily: GoogleFonts.afacad().fontFamily,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      )
                    ],
                  ),
                ),
                // --- Nút Play/Pause dựa trên Status ---
                InkWell(
                  onTap: () => _navigateToListProxyRunning(item),
                  borderRadius: BorderRadius.circular(30),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: FaIcon(
                      item.statusIcon, // Lấy icon từ model (Play hoặc Pause)
                      color: item.statusColor, // Lấy màu từ model (Xanh lá hoặc Xám)
                      size: 45,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const Color primaryOrange = Color(0xFFEA580C);

    return Column(
      mainAxisSize: MainAxisSize.max,
      children: [
        // --- Phần Nội dung chính (Loading/Error/List) ---
        Expanded(
          // Sử dụng RefreshIndicator để cho phép kéo làm mới
            child: RefreshIndicator(
              onRefresh: _fetchProxyList, // Gọi lại hàm fetch khi kéo
              color: primaryOrange, // Màu của indicator
              backgroundColor: theme.cardColor, // Màu nền indicator
              child: _buildContent(), // Hàm build nội dung
            )
        ),

        // // --- Ad Banner Placeholder ---
        // Container(
        //   width: MediaQuery.sizeOf(context).width,
        //   height: 50,
        //   color: Colors.grey[800],
        //   margin: const EdgeInsets.only(bottom: 15, top: 10),
        //   child: const Center(
        //     child: Text( 'Ad Placeholder', style: TextStyle(color: Colors.white54)),
        //   ),
        // ),
        //
        // // --- Nút Upgrade to Pro ---
        // Padding(
        //   padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        //   child: ElevatedButton(
        //     onPressed: _navigateToSubscription,
        //     style: ElevatedButton.styleFrom(
        //       minimumSize: const Size(double.infinity, 56),
        //       padding: const EdgeInsets.all(8),
        //       backgroundColor: primaryOrange,
        //       foregroundColor: Colors.white,
        //       elevation: 3,
        //       shape: RoundedRectangleBorder(
        //         borderRadius: BorderRadius.circular(28),
        //       ),
        //       textStyle: theme.textTheme.headlineSmall?.copyWith(
        //         fontFamily: GoogleFonts.afacad().fontFamily,
        //         color: Colors.white,
        //         letterSpacing: 0.0,
        //       ),
        //     ),
        //     child: const Text('Upgrade to Pro'),
        //   ),
        // ),
      ],
    );
  }
}