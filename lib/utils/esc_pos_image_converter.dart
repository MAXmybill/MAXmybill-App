import 'dart:typed_data';
import 'package:image/image.dart' as img;

class EscPosImageConverter {
  /// Converts a standard image byte array (e.g. PNG/JPG) into an ESC/POS 
  /// compatible monochrome raster bit image (GS v 0).
  /// [targetWidth] should be a multiple of 8. Common: 384 (58mm) or 576 (80mm).
  static Future<List<int>> convertToMonochromeRaster(
      Uint8List imageBytes, int targetWidth) async {
    
    // Decode image
    final img.Image? decodedImage = img.decodeImage(imageBytes);
    if (decodedImage == null) return [];

    // Resize image to fit printer width exactly
    img.Image processedImage = decodedImage;
    if (decodedImage.width != targetWidth) {
      processedImage = img.copyResize(decodedImage, width: targetWidth);
    }
    
    // Convert to grayscale
    processedImage = img.grayscale(processedImage);
    
    List<int> bytes = [];
    
    // Initialize printer
    bytes.addAll([0x1B, 0x40]); 
    
    final int width = processedImage.width;
    final int height = processedImage.height;
    
    // GS v 0 (Raster bit image)
    // m=0 (Normal mode)
    bytes.addAll([0x1D, 0x76, 0x30, 0x00]);
    
    // xL, xH: Width in bytes (width / 8)
    final int widthBytes = (width / 8).ceil();
    bytes.addAll([widthBytes % 256, widthBytes ~/ 256]);
    
    // yL, yH: Height in dots
    bytes.addAll([height % 256, height ~/ 256]);
    
    // Iterate through pixels and pack into bytes
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < widthBytes; x++) {
        int byte = 0;
        for (int b = 0; b < 8; b++) {
          final int pixelX = x * 8 + b;
          if (pixelX < width) {
            final img.Pixel pixel = processedImage.getPixel(pixelX, y);
            
            // Calculate luminance
            // 0 = black, 255 = white
            final num luminance = pixel.r * 0.299 + pixel.g * 0.587 + pixel.b * 0.114;
            
            // Threshold for black (dark pixels should be 1, light pixels 0)
            if (luminance < 220 && pixel.a > 100) {
              byte |= (1 << (7 - b));
            }
          }
        }
        bytes.add(byte);
      }
    }
    
    // Add some line feeds at the end
    bytes.addAll([0x0A, 0x0A, 0x0A]);
    
    return bytes;
  }
}
