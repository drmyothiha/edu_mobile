import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';

class KioskPairingScannerScreen extends StatefulWidget {
  final String? initialPayload;

  const KioskPairingScannerScreen({super.key, this.initialPayload});

  @override
  State<KioskPairingScannerScreen> createState() => _KioskPairingScannerScreenState();
}

class _KioskPairingScannerScreenState extends State<KioskPairingScannerScreen> {
  final MobileScannerController _cameraController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
  );

  bool _isProcessing = false;
  bool _torchEnabled = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialPayload != null && widget.initialPayload!.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() => _isProcessing = true);
        _processPairingPayload(widget.initialPayload!.trim());
      });
    }
  }

  @override
  void dispose() {
    _cameraController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final rawValue = barcodes.first.rawValue;
    if (rawValue == null || rawValue.trim().isEmpty) return;

    setState(() {
      _isProcessing = true;
    });

    await _processPairingPayload(rawValue.trim());
  }

  Future<void> _processPairingPayload(String rawData) async {
    String pairingId = rawData;
    if (rawData.startsWith('edu:kiosk:pair:')) {
      pairingId = rawData.substring('edu:kiosk:pair:'.length).trim();
    }

    try {
      final res = await ApiService.confirmGatePairing(
        pairingId,
        gateName: 'ဂိတ်-၀၁ (အဓိက အဝင်ဝ) • Gate-01',
      );

      if (!mounted) return;
      _showSuccessDialog(res);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('စက်ချိတ်ဆက်မှု မအောင်မြင်ပါ: ${e.toString().replaceAll('Exception: ', '')}'),
          backgroundColor: AppTheme.error,
        ),
      );
      setState(() {
        _isProcessing = false;
      });
    }
  }

  void _showSuccessDialog(Map<String, dynamic> data) {
    final schoolName = data['school_name_my'] ?? data['school_name'] ?? 'အခြေခံပညာကျောင်း';
    final gateName = data['gate_name'] ?? 'ဂိတ်-၀၁ (အဓိက အဝင်ဝ)';

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFA7F3D0), width: 2),
              ),
              child: const Icon(Icons.check_circle, color: Color(0xFF059669), size: 36),
            ),
            const SizedBox(height: 16),
            const Text(
              'ဂိတ်စက် အောင်မြင်စွာ ချိတ်ဆက်ပြီးပါပြီ!',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textMain),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            const Text(
              'Gate Kiosk Provisioned Successfully',
              style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('ကျောင်း:', style: TextStyle(fontSize: 13, color: AppTheme.textMuted)),
                      Text(schoolName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('ဂိတ်အမှတ်:', style: TextStyle(fontSize: 13, color: AppTheme.textMuted)),
                      Text(gateName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                    ],
                  ),
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('အခြေအနေ:', style: TextStyle(fontSize: 13, color: AppTheme.textMuted)),
                      Row(
                        children: const [
                          Icon(Icons.cloud_done, color: Color(0xFF059669), size: 16),
                          SizedBox(width: 4),
                          Text('Roster Auto-Downloading', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).pop(true);
                },
                child: const Text('ပြီးပါပြီ (Done)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showManualEntryDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pairing Code ရိုက်ထည့်ရန်', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ကွန်ပျူတာမျက်နှာပြင်ပေါ်ရှိ Pairing ID ကို ရိုက်ထည့်ပါ:',
              style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'ဥပမာ - kiosk_ee367d37_dbcfdb92',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('မလုပ်ဆောင်ပါ'),
          ),
          ElevatedButton(
            onPressed: () {
              final val = controller.text.trim();
              Navigator.of(ctx).pop();
              if (val.isNotEmpty) {
                setState(() => _isProcessing = true);
                _processPairingPayload(val);
              }
            },
            child: const Text('အတည်ပြုမည်'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('ဂိတ်စက် ချိတ်ဆက်ခြင်း (Kiosk Pair)', style: TextStyle(color: Colors.white, fontSize: 16)),
        actions: [
          IconButton(
            icon: Icon(_torchEnabled ? Icons.flash_on : Icons.flash_off, color: Colors.white),
            onPressed: () {
              setState(() {
                _torchEnabled = !_torchEnabled;
              });
              _cameraController.toggleTorch();
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _cameraController,
            onDetect: _onDetect,
          ),

          // Viewfinder overlay
          Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.indigoAccent, width: 3),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.indigo.withValues(alpha: 0.3),
                    blurRadius: 15,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
          ),

          // Top Instruction Card
          Positioned(
            top: 20,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white24),
              ),
              child: Row(
                children: const [
                  Icon(Icons.qr_code_scanner, color: Colors.indigoAccent, size: 24),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'ကျောင်းဝင်ပေါက် PWA မျက်နှာပြင်ပေါ်ရှိ Device Setup QR ကုဒ်ကို ချိန်ရွယ်ပါ',
                      style: TextStyle(color: Colors.white, fontSize: 13, height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom Action: Manual entry
          Positioned(
            bottom: 30,
            left: 30,
            right: 30,
            child: Column(
              children: [
                if (_isProcessing)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                        SizedBox(width: 10),
                        Text('စက်ချိတ်ဆက်မှုကို အတည်ပြုနေသည်...', style: TextStyle(color: Colors.white, fontSize: 13)),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.15),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.keyboard, color: Colors.white, size: 18),
                  label: const Text('Pairing ID ဖြင့် တိုက်ရိုက်ရိုက်ထည့်ရန်', style: TextStyle(color: Colors.white, fontSize: 13)),
                  onPressed: _showManualEntryDialog,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
