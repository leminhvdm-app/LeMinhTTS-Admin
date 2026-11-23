import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/device_model.dart';
import '../services/app_update_service.dart';
import '../services/firebase_service.dart';
import 'settings_screen.dart';

class DeviceListScreen extends StatefulWidget {
  const DeviceListScreen({super.key});

  @override
  State<DeviceListScreen> createState() => _DeviceListScreenState();
}

class _DeviceListScreenState extends State<DeviceListScreen> {
  final FirebaseService _service = FirebaseService();
  final AppUpdateService _updateService = AppUpdateService();
  List<DeviceModel> _allDevices = [];
  List<DeviceModel> _filteredDevices = [];
  bool _isLoading = false;
  String _searchQuery = '';
  String _selectedTab = 'all'; // 'all', 'active', 'blocked', 'pending'
  AppUpdateInfo? _updateInfo;

  @override
  void initState() {
    super.initState();
    _fetchDevices();
    _checkAppUpdate(silent: true);
  }

  Future<void> _checkAppUpdate({bool silent = true}) async {
    try {
      final info = await _updateService.checkForUpdate();
      if (info.hasUpdate && mounted) {
        setState(() => _updateInfo = info);
        _showUpdateDialog(info);
      } else if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bạn đang sử dụng phiên bản Admin mới nhất (V${AppUpdateService.currentVersion})'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (_) {}
  }

  void _showUpdateDialog(AppUpdateInfo info) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Row(
          children: [
            const Icon(Icons.system_update_rounded, color: Color(0xFF38BDF8)),
            const SizedBox(width: 10),
            Text('Bản cập nhật V${info.latestVersion}', style: const TextStyle(color: Colors.white, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Phiên bản hiện tại: V${info.currentVersion}', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
            const SizedBox(height: 12),
            const Text('Nội dung cập nhật:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(10),
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(info.changelog, style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 12)),
            ),
          ],
        ),
        actions: [
          if (!info.forceUpdate)
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Để sau', style: TextStyle(color: Colors.grey)),
            ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF38BDF8),
              foregroundColor: Colors.black,
            ),
            icon: const Icon(Icons.download, size: 18),
            label: const Text('Cập nhật ngay', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () {
              Navigator.pop(ctx);
              _updateService.launchUpdateUrl(info.apkUrl);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _fetchDevices() async {
    setState(() => _isLoading = true);
    try {
      final list = await _service.fetchDevices();
      setState(() {
        _allDevices = list;
        _applyFilters();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi kết nối Firebase: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFilters() {
    List<DeviceModel> result = _allDevices;

    if (_selectedTab == 'active') {
      result = result.where((d) => d.isActive).toList();
    } else if (_selectedTab == 'blocked') {
      result = result.where((d) => d.isBlocked).toList();
    } else if (_selectedTab == 'pending') {
      result = result.where((d) => d.isPending).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result.where((d) {
        return d.customerName.toLowerCase().contains(q) ||
            d.machineKey.toLowerCase().contains(q) ||
            d.deviceName.toLowerCase().contains(q);
      }).toList();
    }

    _filteredDevices = result;
  }

  Future<void> _toggleStatus(DeviceModel device, bool newStatus) async {
    final originalStatus = device.status;
    setState(() {
      final idx = _allDevices.indexWhere((d) => d.machineKey == device.machineKey);
      if (idx != -1) {
        _allDevices[idx] = device.copyWith(status: newStatus ? 'active' : 'blocked');
        _applyFilters();
      }
    });

    try {
      final success = await _service.toggleDeviceStatus(device.machineKey, newStatus);
      if (!success) {
        throw Exception('Không thể cập nhật máy chủ');
      }
    } catch (e) {
      // Revert if failed
      setState(() {
        final idx = _allDevices.indexWhere((d) => d.machineKey == device.machineKey);
        if (idx != -1) {
          _allDevices[idx] = device.copyWith(status: originalStatus);
          _applyFilters();
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cập nhật thất bại: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showEditDialog(DeviceModel device) {
    final nameCtrl = TextEditingController(text: device.customerName);
    final noteCtrl = TextEditingController(text: device.note);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Thông tin máy', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Mã máy: ${device.machineKey}',
                style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextField(
              controller: nameCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Tên khách hàng / Ghi chú máy',
                labelStyle: TextStyle(color: Color(0xFF94A3B8)),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF64748B))),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Ghi chú thêm',
                labelStyle: TextStyle(color: Color(0xFF94A3B8)),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF64748B))),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF38BDF8)),
            onPressed: () async {
              final updated = device.copyWith(
                customerName: nameCtrl.text.trim(),
                note: noteCtrl.text.trim(),
              );
              Navigator.pop(ctx);
              await _service.updateDevice(updated);
              _fetchDevices();
            },
            child: const Text('Lưu', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  void _showAddDialog() {
    final keyCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final noteCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Thêm máy mới thủ công', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: keyCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Mã Key máy (VD: LMTTS-XXXX-XXXX-XXXX)',
                labelStyle: TextStyle(color: Color(0xFF94A3B8)),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF64748B))),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Tên khách hàng',
                labelStyle: TextStyle(color: Color(0xFF94A3B8)),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF64748B))),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Ghi chú',
                labelStyle: TextStyle(color: Color(0xFF94A3B8)),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF64748B))),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF38BDF8)),
            onPressed: () async {
              final k = keyCtrl.text.trim().toUpperCase();
              if (k.isEmpty) return;
              final newDev = DeviceModel(
                machineKey: k,
                deviceName: 'Nhập thủ công',
                customerName: nameCtrl.text.trim().isEmpty ? 'Khách hàng mới' : nameCtrl.text.trim(),
                status: 'active',
                note: noteCtrl.text.trim(),
                createdAt: DateTime.now(),
                lastSeen: DateTime.now(),
              );
              Navigator.pop(ctx);
              await _service.addDevice(newDev);
              _fetchDevices();
            },
            child: const Text('Thêm & Bật', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  void _deleteDevice(DeviceModel device) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Xác nhận xóa máy', style: TextStyle(color: Colors.white)),
        content: Text('Bạn có chắc muốn xóa mã ${device.machineKey} khỏi hệ thống?',
            style: const TextStyle(color: Color(0xFF94A3B8))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.pop(ctx);
              await _service.deleteDevice(device.machineKey);
              _fetchDevices();
            },
            child: const Text('Xóa', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeCount = _allDevices.where((d) => d.isActive).length;
    final blockedCount = _allDevices.where((d) => d.isBlocked).length;
    final pendingCount = _allDevices.where((d) => d.isPending).length;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        title: const Text(
          'Quản Lý Máy LeMinhTTS',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchDevices,
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
              _fetchDevices();
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF38BDF8),
        foregroundColor: Colors.black,
        onPressed: _showAddDialog,
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _fetchDevices();
          await _checkAppUpdate(silent: false);
        },
        color: const Color(0xFF38BDF8),
        backgroundColor: const Color(0xFF1E293B),
        child: Column(
          children: [
            if (_updateInfo != null && _updateInfo!.hasUpdate)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                child: Row(
                  children: [
                    const Icon(Icons.system_update, color: Color(0xFF38BDF8), size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Có bản cập nhật Admin mới V${_updateInfo!.latestVersion}',
                        style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF38BDF8),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                        minimumSize: const Size(60, 32),
                      ),
                      onPressed: () => _showUpdateDialog(_updateInfo!),
                      child: const Text('Cập nhật', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            // Stats summary row
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: const Color(0xFF1E293B),
              child: Row(
                children: [
                  _buildStatBadge('Tổng', _allDevices.length, const Color(0xFF94A3B8)),
                  const SizedBox(width: 8),
                  _buildStatBadge('Đang Bật', activeCount, const Color(0xFF4ADE80)),
                  const SizedBox(width: 8),
                  _buildStatBadge('Đã Khóa', blockedCount, const Color(0xFFF87171)),
                  const SizedBox(width: 8),
                  _buildStatBadge('Chờ Duyệt', pendingCount, const Color(0xFFFBBF24)),
                ],
              ),
            ),
            // Search field
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Tìm theo tên khách, mã key...',
                  hintStyle: const TextStyle(color: Color(0xFF64748B)),
                  prefixIcon: const Icon(Icons.search, color: Color(0xFF64748B)),
                  filled: true,
                  fillColor: const Color(0xFF1E293B),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val.trim();
                    _applyFilters();
                  });
                },
              ),
            ),
            // Filter Tabs
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  _buildFilterChip('all', 'Tất cả (${_allDevices.length})'),
                  const SizedBox(width: 8),
                  _buildFilterChip('active', 'Đang Bật ($activeCount)'),
                  const SizedBox(width: 8),
                  _buildFilterChip('blocked', 'Đã Khóa ($blockedCount)'),
                  const SizedBox(width: 8),
                  _buildFilterChip('pending', 'Chờ Duyệt ($pendingCount)'),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Device List
            Expanded(
              child: _isLoading && _allDevices.isEmpty
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF38BDF8)))
                  : _filteredDevices.isEmpty
                      ? Center(
                          child: Text(
                            _allDevices.isEmpty
                                ? 'Chưa có máy nào kết nối.\nKhi app PC mở lần đầu, máy sẽ hiện tại đây!'
                                : 'Không tìm thấy máy phù hợp.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Color(0xFF94A3B8)),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _filteredDevices.length,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          itemBuilder: (ctx, idx) => _buildDeviceCard(_filteredDevices[idx]),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatBadge(String label, int count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Text(
              count.toString(),
              style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              label,
              style: TextStyle(color: color, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _selectedTab == key;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: const Color(0xFF38BDF8),
      backgroundColor: const Color(0xFF1E293B),
      labelStyle: TextStyle(
        color: isSelected ? Colors.black : const Color(0xFF94A3B8),
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
      onSelected: (val) {
        setState(() {
          _selectedTab = key;
          _applyFilters();
        });
      },
    );
  }

  Widget _buildDeviceCard(DeviceModel device) {
    final df = DateFormat('dd/MM/yyyy HH:mm');
    final active = device.isActive;

    Color badgeColor;
    String badgeText;
    if (device.isActive) {
      badgeColor = const Color(0xFF4ADE80);
      badgeText = 'ĐANG BẬT';
    } else if (device.isBlocked) {
      badgeColor = const Color(0xFFF87171);
      badgeText = 'ĐÃ TẮT';
    } else {
      badgeColor = const Color(0xFFFBBF24);
      badgeText = 'CHỜ DUYỆT';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: active ? const Color(0xFF38BDF8).withValues(alpha: 0.3) : const Color(0xFF334155),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.desktop_windows_outlined,
                  color: active ? const Color(0xFF38BDF8) : Colors.grey,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.customerName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      device.deviceName,
                      style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                    ),
                  ],
                ),
              ),
              // ON/OFF SWITCH
              Column(
                children: [
                  Switch(
                    value: device.isActive,
                    activeColor: const Color(0xFF4ADE80),
                    activeTrackColor: const Color(0xFF4ADE80).withValues(alpha: 0.3),
                    inactiveThumbColor: const Color(0xFFF87171),
                    inactiveTrackColor: const Color(0xFFF87171).withValues(alpha: 0.3),
                    onChanged: (val) => _toggleStatus(device, val),
                  ),
                  Text(
                    badgeText,
                    style: TextStyle(
                      color: badgeColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Divider(color: Color(0xFF334155), height: 20),
          // Machine Key Row
          Row(
            children: [
              const Text('Key: ', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
              SelectableText(
                device.machineKey,
                style: const TextStyle(
                  color: Color(0xFF38BDF8),
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.copy, size: 16, color: Color(0xFF94A3B8)),
                tooltip: 'Sao chép mã',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: device.machineKey));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Đã sao chép mã Key!'), duration: Duration(seconds: 1)),
                  );
                },
              ),
              const SizedBox(width: 12),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 20, color: Color(0xFF94A3B8)),
                color: const Color(0xFF0F172A),
                onSelected: (val) {
                  if (val == 'edit') _showEditDialog(device);
                  if (val == 'delete') _deleteDevice(device);
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Text('Sửa tên / ghi chú', style: TextStyle(color: Colors.white)),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Xóa máy này', style: TextStyle(color: Colors.redAccent)),
                  ),
                ],
              ),
            ],
          ),
          if (device.note.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Ghi chú: ${device.note}',
              style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 12, fontStyle: FontStyle.italic),
            ),
          ],
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Tạo: ${df.format(device.createdAt)}',
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
              ),
              Text(
                'Hoạt động: ${df.format(device.lastSeen)}',
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
