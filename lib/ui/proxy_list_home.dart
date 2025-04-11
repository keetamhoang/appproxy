import 'dart:async';
import 'dart:convert';
import 'package:appproxy/ui/proxy_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/proxy_item.dart';
import '../../core/api/api_client.dart';

class ProxyListHome extends StatefulWidget {
  const ProxyListHome({super.key});

  @override
  State<ProxyListHome> createState() => _ProxyListHomeState();
}

class _ProxyListHomeState extends State<ProxyListHome> {
  bool _isLoading = true;
  String? _errorMessage;
  List<ProxyItem> _proxyList = [];
  String? _runningProxyToken;
  String? _startingProxyToken;
  Timer? _rotationTimer;
  bool _currentRotationEnabled = false;
  int? _currentRotateTimerSeconds;
  Map<String, dynamic>? _runningProxyDetails;

  static const platform = MethodChannel("cn.ys1231/appproxy/vpn");

  @override
  void initState() {
    super.initState();
    _fetchProxyList();
    platform.setMethodCallHandler((call) async {
      debugPrint("Native call received: ${call.method}");
      if (call.method == 'stopVpn') {
        if (mounted) {
          setState(() {
            print("stopVpn called from native, clearing running/starting token.");
            _runningProxyToken = null;
            _startingProxyToken = null;
            _runningProxyDetails = null;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _stopRotationTimer();
    super.dispose();
  }

  Future<String> _getSavedCountryForSettings(String token) async {
    final storageKey = 'proxy_settings_$token';
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? settingsJson = prefs.getString(storageKey);
      if (settingsJson != null) {
        final Map<String, dynamic> savedSettings = jsonDecode(settingsJson);
        return savedSettings['country'] ?? 'all';
      }
    } catch (e) {
      print("Error loading country setting for $storageKey: $e");
    }
    return 'all';
  }

  Future<Map<String, dynamic>> _getRotationSettings(String token) async {
    final storageKey = 'proxy_settings_$token';
    bool enabled = false; // Mặc định
    int? timerSeconds; // Mặc định null

    try {
      final prefs = await SharedPreferences.getInstance();
      final String? settingsJson = prefs.getString(storageKey);
      if (settingsJson != null) {
        final Map<String, dynamic> savedSettings = jsonDecode(settingsJson);
        enabled = savedSettings['rotateEnabled'] ?? false;
        // Đọc timer, đảm bảo là int nếu không null
        final dynamic savedTimer = savedSettings['rotateTimer'];
        if (savedTimer is int) {
          timerSeconds = savedTimer > 0 ? savedTimer : null; // Chỉ lấy số dương
        } else if (savedTimer is String) {
          final parsedTimer = int.tryParse(savedTimer);
          timerSeconds = (parsedTimer != null && parsedTimer > 0) ? parsedTimer : null;
        }
        print('Loaded rotation settings for $storageKey: enabled=$enabled, timer=$timerSeconds');
      } else {
        print('No saved rotation settings found for $storageKey, using defaults.');
      }
    } catch (e) {
      print("Error loading rotation settings for $storageKey: $e");
    }
    return {'enabled': enabled, 'timer': timerSeconds};
  }

  Future<void> _performRotation(String token) async {
    // Kiểm tra xem proxy này có còn đang chạy không và widget còn tồn tại không
    if (!mounted || _runningProxyToken != token || !_currentRotationEnabled || _currentRotateTimerSeconds == null) {
      print("Rotation stopped: Conditions not met (mounted=$mounted, running=$_runningProxyToken, expected=$token, enabled=$_currentRotationEnabled)");
      _rotationTimer?.cancel(); // Dừng timer nếu điều kiện không còn đúng
      _rotationTimer = null;
      return;
    }

    print("Performing periodic rotation for token: $token");
    final apiClient = ApiClient.instance;
    try {
      final String country = await _getSavedCountryForSettings(token); // Lấy country mới nhất
      final Map<String, dynamic> rotateApiBody = {
        "token": token,
        "type": "rotate",
        "country": country,
      };

      print("Calling periodic /api/proxy/rotate with body: $rotateApiBody");
      final response = await apiClient.post('/api/proxy/rotate', data: rotateApiBody);

      if (!mounted) return;

      if (response.statusCode == 200 && response.data['success'] == true) {
        final apiData = response.data['data'];
        final String? proxyString = apiData['proxy'];
        final String? username = apiData['username'];
        final String? password = apiData['password'];
        String? host;
        int? port;
        if (proxyString != null && proxyString.contains(':')) {
          final parts = proxyString.split(':');
          if (parts.length == 2) {
            host = parts[0];
            port = int.tryParse(parts[1]);
          }
        }

        if (host != null && port != null && username != null && password != null) {
          print("Periodic Rotate API successful. Extracted: host=$host, port=$port, user=$username");
          // Tìm lại ProxyItem gốc để lấy type (hoặc lưu type vào state)
          final originalItem = _proxyList.firstWhere((p) => p.token == token, orElse: () => ProxyItem(token: token, expiredAt: '', status: 0, createdAt: '', type: 'http')); // Cần type gốc

          // Gọi lại hàm Native Start VPN với thông tin MỚI
          // Lưu ý: Không set _startingProxyToken ở đây vì đây là update ngầm
          await _startProxyViaNative(originalItem, host, port, username, password, apiData, isPeriodicUpdate: true);
        } else {
          print("Periodic Rotate API Error: Missing or invalid connection details.");
          // Lỗi lấy thông tin mới -> Dừng proxy và timer? Hay để chạy tiếp với thông tin cũ?
          // Quyết định: Dừng proxy và timer để đảm bảo an toàn/tránh lỗi.
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to get new proxy details during rotation. Stopping proxy.'), backgroundColor: Colors.orange),
          );
          await _stopProxy(); // Dừng proxy
        }
      } else {
        print("Periodic Rotate API failed: Status ${response.statusCode}, Data: ${response.data}");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Rotation failed: ${response.data['message'] ?? 'Server error'}'), backgroundColor: Colors.orange),
        );
        // Lỗi API -> Dừng proxy và timer?
        await _stopProxy();
      }
    } on DioException catch (e) {
      print("Periodic Rotate API DioException: ${e.message}");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Rotation network error: ${_getDioErrorMessage(e)}'), backgroundColor: Colors.orange));
      }
      // Lỗi mạng -> Dừng proxy và timer?
      await _stopProxy();
    } catch (e) {
      print("Unexpected error during periodic rotation: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error during rotation: $e'), backgroundColor: Colors.red));
      }
      // Lỗi khác -> Dừng proxy và timer?
      await _stopProxy();
    }
  }

  Future<void> _fetchProxyList() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final apiClient = ApiClient.instance;
    try {
      final response = await apiClient.get('/api/proxy/list');
      if (!mounted) return;
      if (response.statusCode == 200 && response.data['success'] == true) {
        final List<dynamic> data = response.data['data'];
        setState(() {
          _proxyList = data.map((item) => ProxyItem.fromJson(item)).toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = response.data['message'] ?? 'Failed to load proxy list.';
          _isLoading = false;
        });
      }
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = _getDioErrorMessage(e);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'An unexpected error occurred: $e';
        _isLoading = false;
      });
    }
  }

  String _getDioErrorMessage(DioException e) {
    String defaultMessage = 'Network or server error occurred.';
    if (e.response != null && e.response?.data is Map) {
      return e.response?.data['message'] ?? defaultMessage;
    } else if (e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.sendTimeout || e.type == DioExceptionType.receiveTimeout) {
      return 'Connection timeout. Please check your network.';
    } else if (e.type == DioExceptionType.cancel) {
      return 'Request cancelled.';
    }
    return e.message ?? defaultMessage;
  }

  Future<void> _startProxyViaNative(ProxyItem item, String host, int port, String username, String password, Map<String, dynamic> apiData, {bool isPeriodicUpdate = false}) async {
    List<String> allowedAppPackages = [];
    final Map<String, dynamic> proxyDataToSend = {
      'proxyName': item.token,
      'proxyType': 'http',
      'proxyHost': host,
      'proxyPort': port,
      'proxyUser': username,
      'proxyPass': password,
      'appProxyPackageList': allowedAppPackages,
    };

    try {
      print("${isPeriodicUpdate ? 'Updating' : 'Invoking'} startVpn with data: $proxyDataToSend");
      final bool? result = await platform.invokeMethod<bool>('startVpn', proxyDataToSend);

      if (!mounted) return;

      if (result == true) {
        print("---- ProxyListHome startVpn for ${item.token} ${isPeriodicUpdate ? 'update' : 'initial start'} success");
        if (_runningProxyToken != item.token || isPeriodicUpdate) {
          setState(() {
            _runningProxyToken = item.token;
            _runningProxyDetails = apiData;
            // Reset starting token nếu đây là lần khởi động đầu tiên thành công
            if (!isPeriodicUpdate) {
              _startingProxyToken = null;
            }
          });
        }
        // --- Bắt đầu Timer sau khi Native xác nhận thành công ---
        await _startRotationTimerIfNeeded(item);
      } else {
        print("---- ProxyListHome startVpn for ${item.token} failed (result is not true)");
        if(mounted){
          setState(() {
            _runningProxyToken = null;
            _runningProxyDetails = null;
            if (!isPeriodicUpdate) _startingProxyToken = null;
          });
          _stopRotationTimer(); // Dừng timer nếu có lỗi
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to start proxy via native method.'), backgroundColor: Colors.orange),
          );
        }
      }
    } on PlatformException catch (e) {
      print("---- Failed to invoke startVpn: '${e.message}'.");
      if (mounted) {
        setState(() {
          _runningProxyToken = null;
          _runningProxyDetails = null;
          if (!isPeriodicUpdate) _startingProxyToken = null;
        });
        _stopRotationTimer();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start proxy: ${e.message}')),
        );
      }
    } catch (e) {
      print("---- Unexpected error invoking startVpn: $e");
      if (mounted) {
        setState(() {
          _runningProxyToken = null;
          _runningProxyDetails = null;
          if (!isPeriodicUpdate) _startingProxyToken = null;
        });
        _stopRotationTimer();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('An error occurred: $e')),
        );
      }
    } finally {
      if (!isPeriodicUpdate && mounted && _startingProxyToken == item.token) {
        setState(() { _startingProxyToken = null; });
      }
    }
  }

  Future<void> _startRotationTimerIfNeeded(ProxyItem item) async {
    // Dừng timer cũ trước khi bắt đầu cái mới
    _stopRotationTimer();

    // Lấy cài đặt rotation
    final rotationSettings = await _getRotationSettings(item.token);
    _currentRotationEnabled = rotationSettings['enabled'] as bool;
    _currentRotateTimerSeconds = rotationSettings['timer'] as int?;

    // Nếu bật rotation và có thời gian hợp lệ
    if (_currentRotationEnabled && _currentRotateTimerSeconds != null && _currentRotateTimerSeconds! > 0) {
      print("Starting rotation timer for ${item.token} with interval $_currentRotateTimerSeconds seconds.");
      _rotationTimer = Timer.periodic(
        Duration(seconds: _currentRotateTimerSeconds!),
            (timer) {
          // Gọi hàm thực hiện rotation khi timer kích hoạt
          _performRotation(item.token);
        },
      );
    } else {
      print("Rotation timer not started for ${item.token} (enabled=$_currentRotationEnabled, timer=$_currentRotateTimerSeconds).");
    }
  }

// --- Hàm dừng Timer ---
  void _stopRotationTimer() {
    if (_rotationTimer != null) {
      print("Cancelling existing rotation timer.");
      _rotationTimer!.cancel();
      _rotationTimer = null;
      // Reset luôn các biến liên quan đến timer hiện tại
      _currentRotationEnabled = false;
      _currentRotateTimerSeconds = null;
    }
  }

  Future<void> _stopProxy() async {
    final String? tokenToStop = _runningProxyToken ?? _startingProxyToken;
    if (tokenToStop == null) return;

    print("Stopping proxy and rotation timer (if any) for $tokenToStop");
    // --- Dừng Timer trước ---
    _stopRotationTimer();
    // -----------------------

    if (mounted) {
      setState(() {
        _runningProxyToken = null;
        _startingProxyToken = null;
        _runningProxyDetails = null;
      });
    }

    try {
      print("Invoking stopVpn");
      final bool? result = await platform.invokeMethod<bool>('stopVpn');
      if (!mounted) return;
      if (result == true) {
        print("---- ProxyListHome stopVpn success");
      } else {
        print("---- ProxyListHome stopVpn failed (result is not true)");
        if(mounted){
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to stop proxy properly.'), backgroundColor: Colors.orange),
          );
        }
      }
    } on PlatformException catch (e) {
      print("---- Failed to invoke stopVpn: '${e.message}'.");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to stop proxy: ${e.message}')));
      }
    } catch (e) {
      print("---- Unexpected error invoking stopVpn: $e");
      if(mounted){
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('An error occurred: $e')));
      }
    }
  }

  Future<void> _handleProxyToggle(ProxyItem item) async {
    if (_startingProxyToken != null && _startingProxyToken != item.token) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Another proxy is currently starting...'), duration: Duration(seconds: 2)),
      );
      return;
    }
    if (_startingProxyToken == item.token) {
      return;
    }

    final bool isCurrentlyRunning = _runningProxyToken == item.token;

    if (isCurrentlyRunning) {
      await _stopProxy();
    } else {
      if (mounted) {
        setState(() {
          _startingProxyToken = item.token;
          if (_runningProxyToken != null) {
            _runningProxyToken = null;
          }
          _runningProxyDetails = null;
        });
      }

      final apiClient = ApiClient.instance;
      try {
        final String country = await _getSavedCountryForSettings(item.token);
        print("Using country '$country' for rotate API call.");

        final Map<String, dynamic> rotateApiBody = {
          "token": item.token,
          "type": "rotate",
          "country": country,
        };

        print("Calling /api/proxy/rotate with body: $rotateApiBody");
        final response = await apiClient.post('/api/proxy/rotate', data: rotateApiBody);

        if (!mounted) return;

        if (response.statusCode == 200 && response.data['success'] == true) {
          final apiData = response.data['data'];
          final String? proxyString = apiData['proxy'];
          final String? username = apiData['username'];
          final String? password = apiData['password'];

          String? host;
          int? port;
          if (proxyString != null && proxyString.contains(':')) {
            final parts = proxyString.split(':');
            if (parts.length == 2) {
              host = parts[0];
              port = int.tryParse(parts[1]);
            }
          }

          if (host != null && port != null && username != null && password != null) {
            print("Rotate API successful. Extracted: host=$host, port=$port, user=$username");
            await _startProxyViaNative(item, host, port, username, password, apiData);
          } else {
            print("Rotate API Error: Missing or invalid connection details in response data.");
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Failed to get valid connection details from server.')),
              );
              if (_startingProxyToken == item.token) {
                setState(() { _startingProxyToken = null; });
              }
            }
          }
        } else {
          print("Rotate API failed: Status ${response.statusCode}, Data: ${response.data}");
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(response.data['message'] ?? 'Failed to rotate proxy.')),
            );
            if (_startingProxyToken == item.token) {
              setState(() { _startingProxyToken = null; });
            }
          }
        }
      } on DioException catch (e) {
        print("Rotate API DioException: ${e.message}");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_getDioErrorMessage(e))),
          );
          if (_startingProxyToken == item.token) {
            setState(() { _startingProxyToken = null; });
          }
        }
      } catch (e) {
        print("Unexpected error during rotate/start process: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('An unexpected error occurred: $e')),
          );
          if (_startingProxyToken == item.token) {
            setState(() { _startingProxyToken = null; });
          }
        }
      }
    }
  }

  void _navigateToRotateSetting(ProxyItem item) {
    Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ProxyDetailPage(proxyItem: item),
        )
    ).then((result) {
      if (result == true && mounted) { // Nếu trang detail trả về true (đã save)
        _fetchProxyList(); // Làm mới danh sách để cập nhật thông tin (nếu cần)
      }
    });
  }

  void _navigateToSubscription() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Navigate to Subscription (Not Implemented)')),
    );
  }

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
    return ListView.builder(
      padding: const EdgeInsets.only(top: 12.0, bottom: 12.0),
      itemCount: _proxyList.length,
      itemBuilder: (context, index) {
        final proxyItem = _proxyList[index];
        return _buildProxyListItem(proxyItem);
      },
    );
  }

  Widget _buildProxyListItem(ProxyItem item) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final bool isStarting = _startingProxyToken == item.token;
    final bool isRunning = _runningProxyToken == item.token;

    final IconData statusIcon = isRunning ? FontAwesomeIcons.solidCircleStop : FontAwesomeIcons.solidCirclePlay;
    final Color statusColor = isRunning ? Colors.redAccent[400]! : const Color(0xFF10BA59);

    String formattedExpiry = item.expiredAt;
    final expiryDate = item.expiredDateTime;
    if (expiryDate != null) {
      formattedExpiry = DateFormat('dd/MM/yyyy, HH:mm', Localizations.localeOf(context).languageCode).format(expiryDate);
    }

    final details = (isRunning && _runningProxyDetails != null) ? _runningProxyDetails : null;
    final String? currentIp = details?['currentIp'] as String?;
    final String? city = details?['city'] as String?;
    final String? countryDisplay = details?['country'] as String?;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: InkWell(
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
                Padding(
                  padding: const EdgeInsets.only(right: 12.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.asset(
                      'assets/images/internet.png',
                      width: 45,
                      height: 45,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          Container(width: 45, height: 45, color: Colors.grey[700], child: Icon(Icons.public_off, color: Colors.white54)),
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4.0),
                        child: Text(
                          item.token.length > 15 ? '${item.token.substring(0, 8)}...${item.token.substring(item.token.length - 4)}' : item.token,
                          style: textTheme.titleMedium?.copyWith(
                            fontFamily: GoogleFonts.afacad().fontFamily,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.0,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4.0),
                        child: AutoSizeText(
                          item.type.toUpperCase(),
                          style: textTheme.bodySmall?.copyWith(
                            fontFamily: GoogleFonts.afacad().fontFamily,
                            letterSpacing: 0.0,
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                        ),
                      ),
                      Text(
                        'Expires: $formattedExpiry',
                        style: textTheme.labelSmall?.copyWith(
                          color: Colors.grey[500],
                          fontFamily: GoogleFonts.afacad().fontFamily,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (isRunning && details != null) ...[
                        const SizedBox(height: 5), // Khoảng cách nhỏ
                        if (currentIp != null)
                          Row(
                            children: [
                              Icon(Icons.my_location, size: 14, color: Colors.cyan[300]),
                              const SizedBox(width: 4),
                              Expanded( // Cho phép IP dài có thể wrap hoặc ellipsis
                                child: Text(
                                  currentIp,
                                  style: textTheme.labelSmall?.copyWith(color: Colors.cyan[300]),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        if (city != null || countryDisplay != null)
                          Row(
                            children: [
                              Icon(Icons.location_on_outlined, size: 14, color: Colors.grey[500]),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  '${city ?? ''}${city != null && countryDisplay != null ? ', ' : ''}${countryDisplay ?? ''}',
                                  style: textTheme.labelSmall?.copyWith(color: Colors.grey[500]),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ],
                  ),
                ),
                InkWell(
                  onTap: isStarting ? null : () => _handleProxyToggle(item),
                  borderRadius: BorderRadius.circular(30),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: isStarting
                        ? SizedBox(
                      width: 45,
                      height: 45,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
                      ),
                    )
                        : FaIcon(
                      statusIcon,
                      color: statusColor,
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
        Expanded(
            child: RefreshIndicator(
              onRefresh: _fetchProxyList,
              color: primaryOrange,
              backgroundColor: theme.cardColor,
              child: _buildContent(),
            )
        ),
      ],
    );
  }
}