import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Added for HapticFeedback, SystemSound and Keyboard events
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:maxmybill/utils/translation_helper.dart';
import 'package:maxmybill/utils/responsive_helper.dart';
import 'package:maxmybill/Colors.dart'; // Using your theme colors
import 'dart:math' as math;

class ScannedProductFeedback {
  final String name;
  final String quantityText;

  ScannedProductFeedback({
    required this.name,
    required this.quantityText,
  });
}

class BarcodeScannerPage extends StatefulWidget {
  final Function(String) onBarcodeScanned;

  const BarcodeScannerPage({
    super.key,
    required this.onBarcodeScanned,
  });

  @override
  State<BarcodeScannerPage> createState() => _BarcodeScannerPageState();
}

class _BarcodeScannerPageState extends State<BarcodeScannerPage> with SingleTickerProviderStateMixin {
  // Controller for phone camera scanner
  late MobileScannerController cameraController;

  bool _isScanning = true;
  bool _isProcessingScan = false;
  String _lastScannedCode = '';
  DateTime? _lastScanTime;
  Timer? _productBadgeTimer;
  ScannedProductFeedback? _lastScannedProduct;
  bool _isFlashOn = false;

  // External Scanner logic
  bool _isExternalScannerConnected = false;
  final StringBuffer _externalScannerBuffer = StringBuffer();
  final FocusNode _externalScannerFocusNode = FocusNode();

  // Animation for the scanning line
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();

    // Initialize controller for camera scanning
    cameraController = MobileScannerController(
      formats: [BarcodeFormat.all],
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
    );

    // Setup scanning line animation
    _animationController = AnimationController(
      duration: const Duration(seconds: 1, milliseconds: 500),
      vsync: this,
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    // Listen for hardware scanner/keyboard events
    HardwareKeyboard.instance.addHandler(_handleHardwareKey);
  }

  @override
  void dispose() {
    _productBadgeTimer?.cancel();
    HardwareKeyboard.instance.removeHandler(_handleHardwareKey);
    cameraController.dispose();
    _animationController.dispose();
    _externalScannerFocusNode.dispose();
    super.dispose();
  }

  // Handles input from the external hardware scanner (HID Device)
  bool _handleHardwareKey(KeyEvent event) {
    // If we receive any hardware key event, we know a device is active
    if (!_isExternalScannerConnected) {
      setState(() {
        _isExternalScannerConnected = true;
      });
    }

    if (event is KeyDownEvent) {
      final String? character = event.character;

      // Hardware scanners typically act as keyboards and send an 'Enter' key at the end
      if (event.logicalKey == LogicalKeyboardKey.enter) {
        if (_externalScannerBuffer.isNotEmpty) {
          _handleBarcodeScan(_externalScannerBuffer.toString(), isHardware: true);
          _externalScannerBuffer.clear();
        }
      } else if (character != null) {
        // Buffer the character sent by the scanner
        _externalScannerBuffer.write(character);
      }
    }
    return false; // Allow event to propagate if necessary
  }

  void _handleBarcodeScan(String barcode, {bool isHardware = false}) async {
    final cleanBarcode = barcode.trim();
    if (cleanBarcode.isEmpty || !_isScanning || _isProcessingScan) return;

    final now = DateTime.now();
    // For camera scanner: 1000ms debounce for the exact same barcode to prevent frame spam,
    // while allowing scanning the second item smoothly right after!
    // For hardware scanner (user pulling trigger): 300ms debounce to prevent key bounce.
    final debounceMs = isHardware ? 300 : 1000;
    if (cleanBarcode == _lastScannedCode &&
        _lastScanTime != null &&
        now.difference(_lastScanTime!).inMilliseconds < debounceMs) {
      return;
    }

    _lastScannedCode = cleanBarcode;
    _lastScanTime = now;
    _isProcessingScan = true;

    try {
      final dynamic result = widget.onBarcodeScanned(cleanBarcode);
      final resolvedResult = (result is Future) ? await result : result;

      if (!mounted) return;

      if (resolvedResult == false) {
        // Failed / not found
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    context.tr('product_not_found'),
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: R.sp(context, 13)),
                  ),
                ),
              ],
            ),
            backgroundColor: kOrange,
            duration: const Duration(milliseconds: 1400),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: R.radius(context, 12)),
            margin: EdgeInsets.only(bottom: R.sp(context, 110), left: R.sp(context, 24), right: R.sp(context, 24)),
          ),
        );
      } else if (resolvedResult is Map) {
        final bool success = resolvedResult['success'] == true;
        final String name = (resolvedResult['name'] ?? resolvedResult['productName'] ?? cleanBarcode).toString();
        final dynamic qtyVal = resolvedResult['quantity'];
        final String qtyStr = (qtyVal != null)
            ? (qtyVal is num && qtyVal % 1 == 0 ? '${qtyVal.toInt()}' : '$qtyVal')
            : '1';
        final String? message = resolvedResult['message']?.toString();

        if (success) {
          // Play mild click sound & light haptic feedback
          SystemSound.play(SystemSoundType.click);
          HapticFeedback.lightImpact();

          if (!mounted) return;

          setState(() {
            _lastScannedProduct = ScannedProductFeedback(
              name: name,
              quantityText: qtyStr,
            );
          });

          _productBadgeTimer?.cancel();
          _productBadgeTimer = Timer(const Duration(seconds: 4), () {
            if (mounted) {
              setState(() {
                _lastScannedProduct = null;
              });
            }
          });

          // Show floating snackbar
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.white, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '$name x $qtyStr',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: R.sp(context, 14),
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white38),
                    ),
                    child: Text(
                      'x $qtyStr',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        fontSize: R.sp(context, 13),
                      ),
                    ),
                  ),
                ],
              ),
              backgroundColor: kPrimaryColor,
              duration: const Duration(milliseconds: 1400),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: R.radius(context, 12)),
              margin: EdgeInsets.only(bottom: R.sp(context, 110), left: R.sp(context, 24), right: R.sp(context, 24)),
            ),
          );
        } else {
          // Max stock reached / out of stock / error
          HapticFeedback.heavyImpact();
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.white, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      message ?? context.tr('product_not_found'),
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: R.sp(context, 13)),
                    ),
                  ),
                ],
              ),
              backgroundColor: kOrange,
              duration: const Duration(milliseconds: 1400),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: R.radius(context, 12)),
              margin: EdgeInsets.only(bottom: R.sp(context, 110), left: R.sp(context, 24), right: R.sp(context, 24)),
            ),
          );
        }
      } else {
        // Fallback for non-map return types (e.g. true, String, etc.)
        SystemSound.play(SystemSoundType.click);
        HapticFeedback.lightImpact();

        if (!mounted) return;

        final displayText = (resolvedResult is String && resolvedResult.isNotEmpty)
            ? resolvedResult
            : cleanBarcode;

        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${context.tr('product_added_scanned')}: $displayText',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: R.sp(context, 13)),
                  ),
                ),
              ],
            ),
            backgroundColor: kPrimaryColor,
            duration: const Duration(milliseconds: 1200),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: R.radius(context, 12)),
            margin: EdgeInsets.only(bottom: R.sp(context, 110), left: R.sp(context, 24), right: R.sp(context, 24)),
          ),
        );
      }
    } finally {
      _isProcessingScan = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    final double statusBarHeight = MediaQuery.of(context).padding.top;
    final double appBarHeight = AppBar().preferredSize.height;
    final double availableHeight = screenHeight - statusBarHeight - appBarHeight;

    final scanAreaSize = screenWidth * 0.72;
    final laserWidth = math.max(0.0, scanAreaSize - 40);

    final Rect scanWindow = Rect.fromCenter(
      center: Offset(screenWidth / 2, availableHeight / 2 + statusBarHeight + appBarHeight),
      width: scanAreaSize,
      height: scanAreaSize,
    );

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        ),
        title: Text(
            context.tr('scanbarcode'),
            style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white, fontSize: R.sp(context, 18))
        ),
        backgroundColor: kPrimaryColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isFlashOn ? Icons.flashlight_on : Icons.flashlight_off,
              color: Colors.white,
              size: 22,
            ),
            onPressed: () {
              cameraController.toggleTorch();
              setState(() {
                _isFlashOn = !_isFlashOn;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.cameraswitch_outlined, color: Colors.white, size: 22),
            onPressed: () => cameraController.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          // 1. Camera View
          MobileScanner(
            controller: cameraController,
            scanWindow: scanWindow,
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                if (barcode.rawValue != null) {
                  _handleBarcodeScan(barcode.rawValue!);
                  break;
                }
              }
            },
          ),

          // 2. Overlay
          CustomPaint(
            painter: ScannerOverlay(
              scanAreaSize: scanAreaSize,
            ),
            child: const SizedBox.expand(),
          ),

          // 3. Animated "Laser"
          AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              final double scanAreaTop = (availableHeight - scanAreaSize) / 2;
              final double laserTop = scanAreaTop + (scanAreaSize * _animation.value);

              return Positioned(
                top: laserTop,
                left: (screenWidth - laserWidth) / 2,
                child: Container(
                  width: laserWidth,
                  height: 3,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.redAccent.withOpacity(0.1),
                        Colors.redAccent,
                        Colors.redAccent.withOpacity(0.1),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.redAccent.withOpacity(0.6),
                        blurRadius: 12,
                        spreadRadius: 1,
                      )
                    ],
                  ),
                ),
              );
            },
          ),

          // 4. Scanner Connection Status Indicator
          Positioned(
            top: R.sp(context, 20),
            left: 0,
            right: 0,
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: EdgeInsets.symmetric(horizontal: R.sp(context, 16), vertical: R.sp(context, 8)),
                decoration: BoxDecoration(
                  color: _isExternalScannerConnected ? Colors.green.withOpacity(0.9) : Colors.orange.withOpacity(0.9),
                  borderRadius: R.radius(context, 20),
                  boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isExternalScannerConnected ? Icons.usb : Icons.usb_off,
                      color: Colors.white,
                      size: R.sp(context, 18),
                    ),
                    SizedBox(width: R.sp(context, 8)),
                    Text(
                      _isExternalScannerConnected
                          ? context.tr('External Scanner Ready')
                          : context.tr('Connect External Scanner'),
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: R.sp(context, 12)),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 5. Instructions HUD & Live Scanned Item Feedback Badge
          Positioned(
            bottom: screenHeight * 0.05,
            left: 0,
            right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_lastScannedProduct != null)
                  _buildScannedProductBadge(),
                Container(
                  margin: EdgeInsets.symmetric(horizontal: R.sp(context, 30)),
                  padding: EdgeInsets.symmetric(horizontal: R.sp(context, 20), vertical: R.sp(context, 16)),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.8),
                    borderRadius: R.radius(context, 20),
                    border: Border.all(color: Colors.white.withOpacity(0.15)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        context.tr('scan_multiple_products'),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: R.sp(context, 14),
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.3,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: R.sp(context, 6)),
                      Text(
                        "You can also connect the external scanner and scan through it",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: R.sp(context, 11),
                          fontWeight: FontWeight.w400,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: R.sp(context, 12)),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.barcode_reader, color: Colors.white54, size: R.sp(context, 16)),
                          SizedBox(width: R.sp(context, 12)),
                          Icon(Icons.qr_code_2, color: Colors.white54, size: R.sp(context, 16)),
                          SizedBox(width: R.sp(context, 12)),
                          Icon(Icons.keyboard, color: Colors.white54, size: R.sp(context, 16)),
                        ],
                      )
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScannedProductBadge() {
    final item = _lastScannedProduct;
    if (item == null) return const SizedBox.shrink();

    return Container(
      key: ValueKey('${item.name}_${item.quantityText}'),
      margin: EdgeInsets.only(
        left: R.sp(context, 24),
        right: R.sp(context, 24),
        bottom: R.sp(context, 10),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: R.sp(context, 16),
        vertical: R.sp(context, 12),
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF162319).withOpacity(0.96), // deep glass emerald
        borderRadius: R.radius(context, 16),
        border: Border.all(
          color: const Color(0xFF10B981).withOpacity(0.8),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withOpacity(0.35),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(
              color: Color(0xFF10B981),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_rounded, color: Colors.white, size: 18),
          ),
          SizedBox(width: R.sp(context, 12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.name,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: R.sp(context, 14),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: R.sp(context, 2)),
                Text(
                  context.tr('product_added_scanned'),
                  style: TextStyle(
                    color: const Color(0xFF6EE7B7),
                    fontWeight: FontWeight.w600,
                    fontSize: R.sp(context, 11),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: R.sp(context, 8)),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: R.sp(context, 12),
              vertical: R.sp(context, 6),
            ),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFEAB308), Color(0xFFCA8A04)],
              ),
              borderRadius: R.radius(context, 20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFEAB308).withOpacity(0.4),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Text(
              'x ${item.quantityText}',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w900,
                fontSize: R.sp(context, 14),
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ScannerOverlay extends CustomPainter {
  final double scanAreaSize;

  ScannerOverlay({required this.scanAreaSize});

  @override
  void paint(Canvas canvas, Size size) {
    final double scanAreaLeft = (size.width - scanAreaSize) / 2;
    final double scanAreaTop = (size.height - scanAreaSize) / 2;
    final Rect scanArea = Rect.fromLTWH(scanAreaLeft, scanAreaTop, scanAreaSize, scanAreaSize);

    final Paint backgroundPaint = Paint()
      ..color = Colors.black.withOpacity(0.65)
      ..style = PaintingStyle.fill;

    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height)),
        Path()
          ..addRRect(RRect.fromRectAndRadius(scanArea, const Radius.circular(24)))
          ..close(),
      ),
      backgroundPaint,
    );

    final Paint borderPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    const double cornerLength = 36;
    const double offset = 2;

    canvas.drawLine(Offset(scanAreaLeft - offset, scanAreaTop + cornerLength), Offset(scanAreaLeft - offset, scanAreaTop - offset), borderPaint);
    canvas.drawLine(Offset(scanAreaLeft - offset, scanAreaTop - offset), Offset(scanAreaLeft + cornerLength, scanAreaTop - offset), borderPaint);

    canvas.drawLine(Offset(scanAreaLeft + scanAreaSize + offset, scanAreaTop + cornerLength), Offset(scanAreaLeft + scanAreaSize + offset, scanAreaTop - offset), borderPaint);
    canvas.drawLine(Offset(scanAreaLeft + scanAreaSize + offset, scanAreaTop - offset), Offset(scanAreaLeft + scanAreaSize - cornerLength, scanAreaTop - offset), borderPaint);

    canvas.drawLine(Offset(scanAreaLeft - offset, scanAreaTop + scanAreaSize - cornerLength), Offset(scanAreaLeft - offset, scanAreaTop + scanAreaSize + offset), borderPaint);
    canvas.drawLine(Offset(scanAreaLeft - offset, scanAreaTop + scanAreaSize + offset), Offset(scanAreaLeft + cornerLength, scanAreaTop + scanAreaSize + offset), borderPaint);

    canvas.drawLine(Offset(scanAreaLeft + scanAreaSize + offset, scanAreaTop + scanAreaSize - cornerLength), Offset(scanAreaLeft + scanAreaSize + offset, scanAreaTop + scanAreaSize + offset), borderPaint);
    canvas.drawLine(Offset(scanAreaLeft + scanAreaSize + offset, scanAreaTop + scanAreaSize + offset), Offset(scanAreaLeft + scanAreaSize - cornerLength, scanAreaTop + scanAreaSize + offset), borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}