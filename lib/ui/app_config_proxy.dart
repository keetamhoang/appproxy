import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data'; // Import để dùng Uint8List

import 'package:yeuproxy/data/app_proxy_config_data.dart';
import 'package:yeuproxy/events/app_events.dart';
import 'package:yeuproxy/generated/l10n.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lpinyin/lpinyin.dart';

class AppConfigList extends StatefulWidget {
  const AppConfigList({super.key});

  @override
  State<AppConfigList> createState() => AppConfigState();
}

enum AppOption {
  selectAll,
  showUserApp,
  showSystemApp,
}

// --- Các hàm Isolate (Giữ nguyên) ---
Future<List> invokeGetAppList(token) async {
  BackgroundIsolateBinaryMessenger.ensureInitialized(token);
  const platform = MethodChannel('cn.ys1231/appproxy');
  final appListString = await platform.invokeMethod('getAppList');
  // Thêm kiểm tra null hoặc rỗng trước khi decode
  if (appListString == null || (appListString is String && appListString.isEmpty)) {
    return [];
  }
  List<dynamic> rawList = jsonDecode(appListString);

  List<Map<String, dynamic>> processedList = rawList.map((item) {
    Map<String, dynamic> processedItem = Map<String, dynamic>.from(item);
    if (processedItem.containsKey("iconBytes") && processedItem["iconBytes"] is String) { // Check kiểu String
      try {
        Uint8List iconData = base64Decode(processedItem["iconBytes"]);
        processedItem["iconBytes"] = iconData;
      } catch (e) {
        debugPrint("Error decoding iconBytes for app: ${processedItem["packageName"]}: $e");
        processedItem["iconBytes"] = null;
      }
    } else if (!processedItem.containsKey("iconBytes")) {
      // Nếu không có key "iconBytes", gán là null
      processedItem["iconBytes"] = null;
    }
    // Nếu đã là Uint8List hoặc null thì giữ nguyên
    return processedItem;
  }).toList();

  return processedList;
}

Future<List> getAppListInIsolate() async {
  RootIsolateToken rootIsolateToken = RootIsolateToken.instance!;
  return Isolate.run(() => invokeGetAppList(rootIsolateToken));
}
// --- Kết thúc các hàm Isolate ---

class AppConfigState extends State<AppConfigList> {
  // --- State Variables (Giữ nguyên) ---
  var _itemCount = 0;
  List _jsonAppListInfo = [];
  List _cachedAppListInfo = [];
  List _userAppListInfo = [];
  List _systemAppListInfo = [];
  List _searchAppListInfo = [];
  bool _isShowUserApp = true;
  bool _isShowSystemApp = false;
  bool _useCached = false; // Bắt đầu là false để fetch lần đầu
  bool _showUserAppSelected = true;
  bool _showSystemAppSelected = false;
  bool _selectAll = false;
  bool _showSearch = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  late Map<String, bool> _selectedItemsMap = {}; // Khởi tạo map rỗng
  final AppProxyConfigData _appfile = AppProxyConfigData("proxyconfig.json");
  final platform = const MethodChannel('cn.ys1231/appproxy');
  List<GlobalKey<CardCheckboxState>> _cardKeys = [];
  bool _isFetchingList = false; // Thêm cờ để tránh gọi getAppList liên tục
  // --- End State Variables ---

  @override
  void initState() {
    super.initState();
    debugPrint("iyue-> AppConfigList initState");
    _initData(); // Load config đã lưu
    // Gọi getAppList sau khi _initData hoàn tất và widget đã build xong frame đầu tiên
    WidgetsBinding.instance.addPostFrameCallback((_) => getAppList());

    platform.setMethodCallHandler((call) async {
      if (call.method == 'onRefresh') {
        debugPrint("iyue-> AppConfigList Received onRefresh from native");
        // Reset cache và fetch lại
        setState(() {
          _useCached = false;
          _isFetchingList = false; // Cho phép fetch lại
        });
        getAppList();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  // --- Logic Functions (Cập nhật một chút) ---
  Future<void> _initData() async {
    // Khởi tạo map trước khi đọc
    _selectedItemsMap = await _appfile.readAppConfig();
    // Đồng bộ vào AppEvents (giữ nguyên logic này)
    appProxyPackageList.clear(); // Xóa list cũ trước khi đồng bộ
    for (var key in _selectedItemsMap.keys) {
      if (_selectedItemsMap[key] == true) {
        appProxyPackageList.add(key);
      }
    }
    debugPrint("iyue-> AppConfigList _initData done. Selected items: ${_selectedItemsMap.length}");
  }

  void updateShowUserApp(isShowUserApp) {
    if (_isShowUserApp == isShowUserApp) return; // Không thay đổi thì thôi
    _isShowUserApp = isShowUserApp;
    _showUserAppSelected = isShowUserApp; // Cập nhật trạng thái menu
    _filterAndSortAppList(); // Chỉ lọc và sắp xếp lại, không fetch lại
    _selectAll = false; // Reset select all
  }

  void updateShowSystemApp(isShowSystemApp) {
    if (_isShowSystemApp == isShowSystemApp) return;
    _isShowSystemApp = isShowSystemApp;
    _showSystemAppSelected = isShowSystemApp; // Cập nhật trạng thái menu
    _filterAndSortAppList(); // Chỉ lọc và sắp xếp lại
    _selectAll = false;
  }

  void updateSelectAll(isSelectAll) {
    _selectAll = isSelectAll; // Cập nhật trạng thái menu trước
    setState(() {
      debugPrint("updateSelectAll:$isSelectAll");
      List listToModify = _showSearch ? _searchAppListInfo : _jsonAppListInfo;
      for (var app in listToModify) { // Chỉ select/deselect các app đang hiển thị
        final packageName = app["packageName"];
        _selectedItemsMap[packageName] = isSelectAll;
        if (isSelectAll) {
          appProxyPackageList.add(packageName); // Dùng addIfNotExists
        } else {
          appProxyPackageList.remove(packageName);
        }
      }
      _appfile.saveAppConfig(_selectedItemsMap); // Lưu thay đổi
      // Không cần gọi getAppList, chỉ cần setState để cập nhật UI checkbox
    });
  }

  // Tách logic lọc và sắp xếp ra hàm riêng
  void _filterAndSortAppList() {
    if (!_useCached) return; // Chỉ lọc khi đã có cache

    _jsonAppListInfo.clear(); // Xóa danh sách hiện tại
    if (_isShowSystemApp) _jsonAppListInfo.addAll(_systemAppListInfo);
    if (_isShowUserApp) _jsonAppListInfo.addAll(_userAppListInfo);

    // Sắp xếp: Đưa mục đã chọn lên đầu, còn lại giữ nguyên hoặc sắp xếp theo tên
    _jsonAppListInfo.sort((a, b) {
      bool? itemASelected = _selectedItemsMap[a["packageName"]] ?? false;
      bool? itemBSelected = _selectedItemsMap[b["packageName"]] ?? false;
      if (itemASelected && !itemBSelected) return -1; // A lên trước
      if (!itemASelected && itemBSelected) return 1;  // B lên trước
      // Cả hai cùng trạng thái -> sắp xếp theo tên app (label)
      String labelA = a['label']?.toString().toLowerCase() ?? '';
      String labelB = b['label']?.toString().toLowerCase() ?? '';
      return labelA.compareTo(labelB);
    });

    _itemCount = _jsonAppListInfo.length;
    // Nếu đang tìm kiếm, áp dụng lại bộ lọc tìm kiếm
    if (_showSearch) {
      _searchApp(_searchController.text);
    } else {
      // Cập nhật UI nếu không tìm kiếm
      if(mounted) setState(() {});
    }
  }

  Future<void> getAppList() async { // Đổi thành Future<void>
    if (_isFetchingList) { // Nếu đang fetch thì không gọi lại
      debugPrint("iyue-> Already fetching app list, skipping.");
      return;
    }

    // Chỉ fetch nếu chưa có cache
    if (!_useCached || _cachedAppListInfo.isEmpty) {
      if(mounted) setState(() => _isFetchingList = true); // Bắt đầu fetch
      try {
        debugPrint("iyue-> Calling getAppListInIsolate");
        _cachedAppListInfo = await getAppListInIsolate();
        debugPrint("iyue-> Got ${_cachedAppListInfo.length} apps from isolate");
        _useCached = true;

        // Phân loại vào system/user list một lần sau khi fetch
        _systemAppListInfo.clear();
        _userAppListInfo.clear();
        for (Map<String, dynamic> appInfo in _cachedAppListInfo) {
          if (appInfo["isSystemApp"] == true) { // So sánh rõ ràng với true
            _systemAppListInfo.add(appInfo);
          } else {
            _userAppListInfo.add(appInfo);
          }
        }
        debugPrint("iyue-> User apps: ${_userAppListInfo.length}, System apps: ${_systemAppListInfo.length}");

        _filterAndSortAppList(); // Lọc và sắp xếp dựa trên cài đặt hiện tại

      } on PlatformException catch (e) {
        debugPrint("Failed to get app list: '${e.message}'.");
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to get app list: ${e.message}"), backgroundColor: Colors.red));
        // Xử lý lỗi (ví dụ: hiển thị thông báo)
      } catch (e) {
        debugPrint('An unexpected error happened: $e');
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error getting app list: $e"), backgroundColor: Colors.red));
        // Xử lý lỗi
      } finally {
        if(mounted) setState(() => _isFetchingList = false); // Kết thúc fetch
      }
    } else {
      debugPrint("iyue-> Using cached app list.");
      // Nếu đã có cache, chỉ cần lọc lại (ví dụ khi đổi filter)
      _filterAndSortAppList();
    }
  }

  void _searchApp(String searchText) {
    // Luôn lọc từ _jsonAppListInfo (danh sách đã được lọc theo system/user)
    _searchAppListInfo = _jsonAppListInfo.where((itemMap) {
      // Kiểm tra null trước khi truy cập
      final String label = itemMap["label"]?.toString() ?? "";
      final String packageName = itemMap["packageName"]?.toString() ?? "";
      final String pinyin = PinyinHelper.getShortPinyin(label).toLowerCase();
      final String combined = "$label$pinyin$packageName".toLowerCase();
      final String search = searchText.toLowerCase();
      return combined.contains(search);
    }).toList();
    // Chỉ cần setState để cập nhật ListView
    if (mounted) setState(() {});
  }

  void exitSearch() {
    setState(() {
      debugPrint("exitSearch");
      _showSearch = false;
      _searchController.clear(); // Xóa text tìm kiếm khi thoát
      // Không cần gọi _searchApp("") vì list sẽ tự động dùng _jsonAppListInfo
    });
  }
  // --- End Logic Functions ---


  @override
  Widget build(BuildContext context) {
    // --- Lấy Theme Data ---
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final isDark = theme.brightness == Brightness.dark;
    // --- End Lấy Theme Data ---

    // Tạo lại list keys cho CardCheckbox mỗi lần build
    _cardKeys = List.generate(
        _showSearch ? _searchAppListInfo.length : _jsonAppListInfo.length,
            (index) => GlobalKey<CardCheckboxState>()
    );

    return Scaffold(
      backgroundColor: Colors.white,
      // --- AppBar đã được style ---
      appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0, // Cho phẳng hơn
          title: Text('Configure Proxy App', style: theme.appBarTheme.titleTextStyle), // Title
          actions: <Widget>[
            // --- Search Toggle và TextField ---
            AnimatedCrossFade(
              crossFadeState: _showSearch ? CrossFadeState.showSecond : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 300), // Thêm hiệu ứng mượt
              // Nút Search Icon
              firstChild: IconButton(
                key: const ValueKey('searchIcon'),
                tooltip: 'Search Apps',
                icon: Icon(Icons.search, color: theme.appBarTheme.iconTheme?.color), // Lấy màu từ theme
                onPressed: () {
                  setState(() {
                    _showSearch = true;
                    _searchApp(''); // Hiển thị tất cả trước khi focus
                    // Delay nhẹ để TextField kịp build rồi mới focus
                    Future.delayed(const Duration(milliseconds: 100), () {
                      if (mounted) _searchFocusNode.requestFocus();
                    });
                  });
                },
              ),
              // Search TextField Container
              secondChild: Container(
                key: const ValueKey('searchField'),
                width: MediaQuery.of(context).size.width * 0.6, // Giới hạn chiều rộng
                height: kToolbarHeight - 16, // Chiều cao phù hợp AppBar
                margin: const EdgeInsets.only(right: 8),
                alignment: Alignment.center,
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  autofocus: true, // Tự động focus khi hiện ra
                  cursorColor: colorScheme.primary, // Màu con trỏ cam
                  style: TextStyle(color: theme.appBarTheme.titleTextStyle?.color ?? (isDark ? Colors.white : Colors.black)), // Màu chữ nhập
                  decoration: InputDecoration(
                    hintText: S.of(context).text_search_app,
                    hintStyle: TextStyle(color: (theme.appBarTheme.titleTextStyle?.color ?? (isDark ? Colors.white : Colors.black)).withOpacity(0.7)), // Màu hint mờ hơn
                    border: InputBorder.none, // Không viền
                    filled: true,
                    fillColor: Colors.grey[100], // Nền đen mờ nhẹ
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0), // Padding gọn gàng
                    enabledBorder: OutlineInputBorder( // Thêm viền bo tròn nhẹ
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide(color: colorScheme.primary, width: 1), // Viền cam khi focus
                    ),
                    suffixIcon: IconButton( // Nút X để xóa search và thoát
                      icon: Icon(Icons.close, size: 20, color: (theme.appBarTheme.titleTextStyle?.color ?? (isDark ? Colors.white : Colors.black)).withOpacity(0.8)),
                      onPressed: exitSearch,
                      tooltip: 'Clear Search',
                    ),
                  ),
                  onChanged: _searchApp, // Gọi hàm search khi text thay đổi
                  // Bỏ onTapOutside vì đã có nút X
                ),
              ),
            ),
            // --- Popup Menu ---
            PopupMenuButton<AppOption>(
              icon: Icon(Icons.filter_list, color: theme.appBarTheme.iconTheme?.color), // Icon filter
              tooltip: 'Configure Apps',
              // Style cho popup menu
              color: Colors.grey[50], // Màu nền menu
              itemBuilder: (BuildContext context) {
                return <PopupMenuEntry<AppOption>>[
                  CheckedPopupMenuItem<AppOption>(
                    checked: _selectAll,
                    value: AppOption.selectAll,
                    child: Text(S.of(context).text_select_all, style: textTheme.bodyMedium), // Style text
                  ),
                  const PopupMenuDivider(), // Thêm đường kẻ phân cách
                  CheckedPopupMenuItem<AppOption>(
                    checked: _showUserAppSelected,
                    value: AppOption.showUserApp,
                    child: Text(S.of(context).text_show_user_app, style: textTheme.bodyMedium),
                  ),
                  CheckedPopupMenuItem<AppOption>(
                    checked: _showSystemAppSelected,
                    value: AppOption.showSystemApp,
                    child: Text(S.of(context).text_show_system_app, style: textTheme.bodyMedium),
                  )
                ];
              },
              onSelected: (AppOption value) {
                // Xử lý khi chọn item từ menu
                switch (value) {
                  case AppOption.selectAll:
                    updateSelectAll(!_selectAll); // Đảo trạng thái select all
                    break;
                  case AppOption.showUserApp:
                    updateShowUserApp(!_showUserAppSelected);
                    break;
                  case AppOption.showSystemApp:
                    updateShowSystemApp(!_showSystemAppSelected);
                    break;
                }
              },
            )
          ]),
      // --- Body với RefreshIndicator ---
      body: RefreshIndicator(
        onRefresh: () async { // Đảm bảo là async
          debugPrint("onRefresh triggered");
          setState(() {
            _useCached = false; // Yêu cầu fetch lại
            _isFetchingList = false; // Cho phép fetch
          });
          await getAppList(); // Đợi fetch xong
        },
        color: colorScheme.primary, // Màu spinner cam
        backgroundColor: theme.cardColor, // Màu nền spinner
        // Hiển thị loading hoặc list
        child: _isFetchingList && !_useCached // Chỉ hiện loading chính nếu đang fetch lần đầu
            ? Center(child: CircularProgressIndicator(color: colorScheme.primary))
            : Scrollbar( // Thêm scrollbar
          thumbVisibility: true, // Luôn hiển thị scrollbar
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()), // Luôn cho phép cuộn để refresh
            separatorBuilder: (context, index) => Divider(height: 1, thickness: 0.5, color: Colors.grey[800]), // Thêm đường kẻ mờ
            itemCount: _showSearch ? _searchAppListInfo.length : _jsonAppListInfo.length,
            itemBuilder: (BuildContext context, int index) {
              // Lấy item từ list tương ứng (search hoặc full)
              final currentList = _showSearch ? _searchAppListInfo : _jsonAppListInfo;
              // Kiểm tra index hợp lệ (phòng trường hợp list thay đổi đột ngột)
              if (index >= currentList.length) return const SizedBox.shrink();
              final itemMap = currentList[index];
              // Lấy key cho CardCheckbox
              final cardKey = (index < _cardKeys.length) ? _cardKeys[index] : GlobalKey<CardCheckboxState>();

              return Card(
                // Sử dụng theme cho card
                color: Colors.white,
                elevation: 0, // Bỏ elevation của Card, dùng Divider
                margin: EdgeInsets.zero, // Bỏ margin của Card
                shape: const RoundedRectangleBorder(), // Bỏ bo góc Card
                child: ListTile(
                  horizontalTitleGap: 16, // Khoảng cách giữa icon và text
                  contentPadding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 16.0), // Padding gọn hơn
                  leading: SizedBox(
                    width: 40, // Đồng nhất kích thước icon
                    height: 40,
                    child: itemMap["iconBytes"] != null && itemMap["iconBytes"] is Uint8List // Check kiểu Uint8List
                        ? ClipRRect( // Bo tròn nhẹ icon
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(itemMap["iconBytes"], fit: BoxFit.contain, gaplessPlayback: true), // Contain để không bị cắt
                    )
                        : Container( // Placeholder nếu không có icon
                      decoration: BoxDecoration(
                          color: Colors.grey[700],
                          borderRadius: BorderRadius.circular(8)
                      ),
                      child: Icon(Icons.android, color: Colors.grey[500], size: 24),
                    ),
                  ),
                  title: Text(
                    itemMap["label"] ?? 'Unknown App', // Text nếu label null
                    style: textTheme.titleMedium, // Style từ theme
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    itemMap["packageName"] ?? 'unknown.package', // Text nếu package null
                    style: textTheme.bodySmall?.copyWith(color: Colors.grey[500]), // Màu xám nhạt hơn
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: CardCheckbox(
                    key: cardKey,
                    isSelected: _selectedItemsMap[itemMap["packageName"]] ?? false,
                    // Truyền màu accent vào checkbox
                    activeColor: colorScheme.primary,
                    checkColor: colorScheme.onPrimary, // Màu dấu tick (trắng?)
                    borderColor: Colors.grey[600]!, // Màu viền khi chưa check
                    // Callback khi giá trị thay đổi
                    callbackOnChanged: (newValue) {
                      final packageName = itemMap["packageName"];
                      if (packageName == null) return; // Bỏ qua nếu package name null

                      // Cập nhật Map và List sự kiện
                      setState(() { // Cập nhật trực tiếp trong setState
                        _selectedItemsMap[packageName] = newValue;
                        if (newValue) {
                          appProxyPackageList.add(packageName);
                        } else {
                          appProxyPackageList.remove(packageName);
                          // Nếu bỏ chọn 1 item thì bỏ trạng thái select all
                          _selectAll = false;
                        }
                      });
                      // Lưu vào file sau khi cập nhật state
                      _appfile.saveAppConfig(_selectedItemsMap);
                    },
                  ),
                  onTap: () {
                    // Gọi toggle của CardCheckbox tương ứng
                    cardKey.currentState?.toggleCheckbox();
                    // Không cần gọi getAppList() nữa vì logic sort đã ổn
                    // Chỉ cần setState để checkbox update (đã làm trong callbackOnChanged)
                    // setState((){}); // Có thể không cần thiết
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}


// --- CardCheckbox đã được style ---
class CardCheckbox extends StatefulWidget {
  const CardCheckbox({
    super.key,
    required this.isSelected,
    required this.callbackOnChanged,
    required this.activeColor, // Thêm màu active
    required this.checkColor, // Thêm màu dấu tick
    required this.borderColor, // Thêm màu viền
  });

  final bool isSelected;
  final Function(bool) callbackOnChanged;
  final Color activeColor;
  final Color checkColor;
  final Color borderColor;


  @override
  State<StatefulWidget> createState() => CardCheckboxState();
}

class CardCheckboxState extends State<CardCheckbox> {

  late bool _currentSelected;

  @override
  void initState() {
    super.initState();
    _currentSelected = widget.isSelected;
  }

  // Cập nhật state nội bộ khi widget được rebuild với giá trị isSelected mới từ parent
  @override
  void didUpdateWidget(covariant CardCheckbox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSelected != _currentSelected) {
      setState(() {
        _currentSelected = widget.isSelected;
      });
    }
  }

  // Hàm để parent gọi (ví dụ từ onTap của ListTile)
  void toggleCheckbox() {
    setState(() {
      _currentSelected = !_currentSelected;
      widget.callbackOnChanged(_currentSelected); // Gọi callback để cập nhật state cha và lưu file
    });
  }

  @override
  Widget build(BuildContext context) {
    return Checkbox(
      value: _currentSelected,
      onChanged: (bool? newValue) {
        if (newValue != null) {
          setState(() {
            _currentSelected = newValue;
          });
          widget.callbackOnChanged(newValue); // Gọi callback khi người dùng tự nhấn
        }
      },
      // Áp dụng màu sắc
      activeColor: widget.activeColor, // Màu nền khi check (cam)
      checkColor: widget.checkColor, // Màu dấu tick (trắng)
      side: BorderSide( // Style viền
        color: _currentSelected ? widget.activeColor : widget.borderColor, // Cam khi check, xám khi uncheck
        width: 1.5,
      ),
      shape: RoundedRectangleBorder( // Bo góc nhẹ
        borderRadius: BorderRadius.circular(4),
      ),
      visualDensity: VisualDensity.compact, // Làm cho checkbox nhỏ gọn hơn
    );
  }
}