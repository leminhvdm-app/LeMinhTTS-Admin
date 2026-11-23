import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/device_model.dart';

class FirebaseService {
  static const String defaultUrl = 'https://leminhtts-license-default-rtdb.asia-southeast1.firebasedatabase.app';
  static const String defaultPin = '123456';

  static const String prefUrlKey = 'firebase_url';
  static const String prefPinKey = 'admin_pin';

  Future<String> getFirebaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(prefUrlKey) ?? defaultUrl;
  }

  Future<void> setFirebaseUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    final clean = url.trim().replaceAll(RegExp(r'/+$'), '');
    await prefs.setString(prefUrlKey, clean);
  }

  Future<String> getAdminPin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(prefPinKey) ?? defaultPin;
  }

  Future<void> setAdminPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefPinKey, pin.trim());
  }

  Future<List<DeviceModel>> fetchDevices() async {
    final baseUrl = await getFirebaseUrl();
    final uri = Uri.parse('$baseUrl/devices.json');

    final response = await http.get(uri).timeout(const Duration(seconds: 10));
    if (response.statusCode == 200) {
      if (response.body == 'null' || response.body.isEmpty) {
        return [];
      }
      final Map<String, dynamic> data = jsonDecode(response.body);
      final List<DeviceModel> devices = [];
      data.forEach((key, value) {
        if (value is Map<String, dynamic>) {
          devices.add(DeviceModel.fromJson(key, value));
        }
      });
      // Sort by created_at desc
      devices.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return devices;
    } else {
      throw Exception('Không thể kết nối Firebase (Mã lỗi: ${response.statusCode})');
    }
  }

  Future<bool> toggleDeviceStatus(String key, bool enable) async {
    final baseUrl = await getFirebaseUrl();
    final uri = Uri.parse('$baseUrl/devices/$key.json');
    final newStatus = enable ? 'active' : 'blocked';

    final response = await http.patch(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'status': newStatus}),
    ).timeout(const Duration(seconds: 10));

    return response.statusCode == 200;
  }

  Future<bool> updateDevice(DeviceModel device) async {
    final baseUrl = await getFirebaseUrl();
    final uri = Uri.parse('$baseUrl/devices/${device.machineKey}.json');

    final response = await http.patch(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'customer_name': device.customerName,
        'note': device.note,
        'status': device.status,
      }),
    ).timeout(const Duration(seconds: 10));

    return response.statusCode == 200;
  }

  Future<bool> deleteDevice(String key) async {
    final baseUrl = await getFirebaseUrl();
    final uri = Uri.parse('$baseUrl/devices/$key.json');

    final response = await http.delete(uri).timeout(const Duration(seconds: 10));
    return response.statusCode == 200;
  }

  Future<bool> addDevice(DeviceModel device) async {
    final baseUrl = await getFirebaseUrl();
    final uri = Uri.parse('$baseUrl/devices/${device.machineKey}.json');

    final response = await http.put(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(device.toJson()),
    ).timeout(const Duration(seconds: 10));

    return response.statusCode == 200;
  }
}
