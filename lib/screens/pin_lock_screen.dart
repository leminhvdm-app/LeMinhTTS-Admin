import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import 'device_list_screen.dart';

class PinLockScreen extends StatefulWidget {
  const PinLockScreen({super.key});

  @override
  State<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends State<PinLockScreen> {
  final FirebaseService _service = FirebaseService();
  String _enteredPin = '';
  String _actualPin = '123456';
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadPin();
  }

  Future<void> _loadPin() async {
    final pin = await _service.getAdminPin();
    setState(() {
      _actualPin = pin;
    });
  }

  void _onKeyPress(String val) {
    if (_enteredPin.length < 6) {
      setState(() {
        _enteredPin += val;
        _errorMessage = '';
      });
      if (_enteredPin.length == 6) {
        _verifyPin();
      }
    }
  }

  void _onDelete() {
    if (_enteredPin.isNotEmpty) {
      setState(() {
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
        _errorMessage = '';
      });
    }
  }

  void _verifyPin() {
    if (_enteredPin == _actualPin) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const DeviceListScreen()),
      );
    } else {
      setState(() {
        _errorMessage = 'Mã PIN không đúng, vui lòng thử lại';
        _enteredPin = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF38BDF8), width: 2),
              ),
              child: const Icon(
                Icons.shield_outlined,
                size: 48,
                color: Color(0xFF38BDF8),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'LeMinhTTS Quản Lý',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Nhập mã PIN Admin để truy cập',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(height: 32),
            // PIN dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(6, (index) {
                final filled = index < _enteredPin.length;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: filled ? const Color(0xFF38BDF8) : Colors.transparent,
                    border: Border.all(
                      color: filled ? const Color(0xFF38BDF8) : const Color(0xFF64748B),
                      width: 2,
                    ),
                  ),
                );
              }),
            ),
            if (_errorMessage.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                _errorMessage,
                style: const TextStyle(color: Colors.redAccent, fontSize: 13),
              ),
            ],
            const Spacer(),
            // Numeric Keypad
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
              child: Column(
                children: [
                  for (var row = 0; row < 3; row++)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          for (var col = 1; col <= 3; col++)
                            _buildKeyButton((row * 3 + col).toString()),
                        ],
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        const SizedBox(width: 72, height: 72),
                        _buildKeyButton('0'),
                        SizedBox(
                          width: 72,
                          height: 72,
                          child: IconButton(
                            icon: const Icon(Icons.backspace_outlined, color: Colors.white70),
                            onPressed: _onDelete,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildKeyButton(String text) {
    return SizedBox(
      width: 72,
      height: 72,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          shape: const CircleBorder(),
          backgroundColor: const Color(0xFF1E293B),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        onPressed: () => _onKeyPress(text),
        child: Text(
          text,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
