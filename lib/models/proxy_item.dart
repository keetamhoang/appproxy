import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart'; // for kDebugMode and print

class ProxyItem {
  final String token;
  final String expiredAt; // Giữ dạng String ban đầu, có thể parse sau nếu cần
  final int status; // 1 = active? 0 = inactive?
  final String createdAt; // Giữ dạng String
  final String type;
  final String note;
  final String typeText;

  ProxyItem({
    required this.token,
    required this.expiredAt,
    required this.status,
    required this.createdAt,
    required this.type,
    required this.note,
    required this.typeText,
  });

  // Factory constructor để tạo instance từ JSON (Map)
  factory ProxyItem.fromJson(Map<String, dynamic> json) {
    // Thêm kiểm tra kiểu dữ liệu để tránh lỗi runtime
    return ProxyItem(
      token: json['token'] as String? ?? '', // Cung cấp giá trị mặc định nếu null
      expiredAt: json['expired_at'] as String? ?? '',
      status: (json['status'] is int) ? json['status'] : ( (json['status'] is String) ? (int.tryParse(json['status']) ?? 0) : 0 ) , // Xử lý cả int và String
      createdAt: json['created_at'] as String? ?? '',
      type: json['type'] as String? ?? 'unknown', // Cung cấp loại mặc định
      note: json['note'] as String? ?? '',
      typeText: json['type_text'] as String? ?? '',
    );
  }

  // (Tùy chọn) Thêm phương thức để lấy DateTime object nếu cần xử lý ngày giờ
  DateTime? get expiredDateTime {
    try {
      // API trả về 'YYYY-MM-DD HH:MM:SS', cần thay ' ' bằng 'T' để parse chuẩn ISO8601
      // Hoặc dùng intl package để parse định dạng cụ thể
      return DateTime.tryParse(expiredAt.replaceFirst(' ', 'T'));
    } catch (e) {
      if (kDebugMode) print("Error parsing expiredAt '$expiredAt': $e");
      return null;
    }
  }

  // (Tùy chọn) Check xem proxy có active không dựa trên status
  bool get isActive => status == 1;

  // (Tùy chọn) Lấy màu dựa trên status
  Color get statusColor => isActive ? const Color(0xFF10BA59) : Colors.grey;

  // (Tùy chọn) Lấy icon dựa trên status
  IconData get statusIcon => isActive ? FontAwesomeIcons.solidCirclePlay : FontAwesomeIcons.solidCirclePause;

}