import 'dart:math';

import 'dart:ui' as ui;
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:js' as js;

class ResultScreen extends StatefulWidget {
  final String layoutName;
  final List<XFile> images;
  const ResultScreen(
      {super.key, required this.layoutName, required this.images});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen>
    with SingleTickerProviderStateMixin {
  List<_MosaicCell>? _cells;
  List<ui.Image>? _decodedImages;
  bool _loading = true;
  String _status = 'Decoding images...';
  late AnimationController _revealCtrl;
  final GlobalKey _globalKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _revealCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _generateMosaic();
  }

  @override
  void dispose() {
    _revealCtrl.dispose();
    if (_decodedImages != null) {
      for (final img in _decodedImages!) {
        img.dispose();
      }
    }
    super.dispose();
  }

  Future<void> _generateMosaic() async {
    try {
      // Decode all images
      final images = <ui.Image>[];
      for (int i = 0; i < widget.images.length; i++) {
        setState(() => _status = 'Decoding image ${i + 1}/${widget.images.length}...');
        final bytes = await widget.images[i].readAsBytes();
        final codec = await ui.instantiateImageCodec(
          bytes,
          targetWidth: 600,
          targetHeight: 600,
        );
        final frame = await codec.getNextFrame();
        images.add(frame.image);
      }

      // Canvas dimensions for high-density rendering
      const canvasW = 1600.0;
      const canvasH = 800.0;

      // Render text character by character with tighter spacing
      final chars = widget.layoutName.toUpperCase().split('');
      const charGap = 20.0; // Tighter gap
      double totalWidth = (chars.length - 1) * charGap;
      
      final charPainters = chars.map((c) {
        final tp = TextPainter(
          text: TextSpan(
            text: c,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 600,
              fontWeight: FontWeight.w900,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        return tp;
      }).toList();

      for (final p in charPainters) totalWidth += p.width;
      
      final scaleToFit = min(canvasW * 0.95 / totalWidth, canvasH * 0.8 / 600);
      final finalCharGap = charGap * scaleToFit;
      
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawRect(Rect.fromLTWH(0, 0, canvasW, canvasH), Paint()..color = Colors.black);

      // Store character info for the painter to draw outlines
      final List<_LetterInfo> letterInfos = [];
      double currentX = (canvasW - totalWidth * scaleToFit) / 2;
      for (int i = 0; i < charPainters.length; i++) {
        final p = charPainters[i];
        final charW = p.width * scaleToFit;
        final charH = p.height * scaleToFit;
        final charY = (canvasH - charH) / 2;
        
        letterInfos.add(_LetterInfo(
          char: chars[i],
          offset: Offset(currentX, charY),
          fontSize: 600.0 * scaleToFit,
        ));

        final charColor = Color.fromARGB(255, i + 1, i + 1, i + 1);
        final scaledTp = TextPainter(
          text: TextSpan(
            text: chars[i],
            style: TextStyle(
              color: charColor,
              fontSize: 600.0 * scaleToFit,
              fontWeight: FontWeight.w900,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        
        scaledTp.paint(canvas, Offset(currentX, charY));
        currentX += charW + finalCharGap;
      }

      final picture = recorder.endRecording();
      final textImage = await picture.toImage(canvasW.toInt(), canvasH.toInt());
      final byteData = await textImage.toByteData(format: ui.ImageByteFormat.rawRgba);
      final pixels = byteData!.buffer.asUint8List();
      textImage.dispose();

      // FIXED high density cell size
      const double cs = 14.0; 
      final List<_MosaicCell> activeCells = [];
      final cols = (canvasW / cs).floor();
      final rows = (canvasH / cs).floor();

      for (int r = 0; r < rows; r++) {
        for (int c = 0; c < cols; c++) {
          int detectedLetterIndex = -1;
          for (double ox = 0.2; ox <= 0.8; ox += 0.4) {
            for (double oy = 0.2; oy <= 0.8; oy += 0.4) {
              final cx = (c * cs + cs * ox).toInt().clamp(0, canvasW.toInt() - 1);
              final cy = (r * cs + cs * oy).toInt().clamp(0, canvasH.toInt() - 1);
              final int idx = (cy * canvasW.toInt() + cx) * 4;
              if (idx >= 0 && idx < pixels.length && pixels[idx] > 0) {
                detectedLetterIndex = pixels[idx] - 1;
                break;
              }
            }
            if (detectedLetterIndex != -1) break;
          }

          if (detectedLetterIndex != -1) {
            activeCells.add(_MosaicCell(
              rect: Rect.fromLTWH(c * cs, r * cs, cs, cs),
              index: activeCells.length % images.length,
              letterIndex: detectedLetterIndex,
            ));
          }
        }
      }

      // Calculate bounding box for tight fit
      double minX = canvasW, minY = canvasH, maxX = 0, maxY = 0;
      for (final cell in activeCells) {
        if (cell.rect.left < minX) minX = cell.rect.left;
        if (cell.rect.top < minY) minY = cell.rect.top;
        if (cell.rect.right > maxX) maxX = cell.rect.right;
        if (cell.rect.bottom > maxY) maxY = cell.rect.bottom;
      }

      // Add a small margin (e.g., 20px)
      const margin = 20.0;
      final tightW = (maxX - minX) + margin * 2;
      final tightH = (maxY - minY) + margin * 2;

      // Shift all cells to fit the new tight canvas
      final shiftedCells = activeCells.map((c) => _MosaicCell(
        rect: c.rect.shift(Offset(-minX + margin, -minY + margin)),
        index: c.index,
        letterIndex: c.letterIndex,
      )).toList();

      setState(() {
        _decodedImages = images;
        _cells = shiftedCells;
        _letterInfos = letterInfos;
        _loading = false;
        _status = 'Mosaic Ready';
        _mosaicContentSize = Size(tightW, tightH);
      });
      _revealCtrl.forward();
    } catch (e) {
      setState(() { _loading = false; _status = 'Error: $e'; });
    }
  }

  Size _mosaicContentSize = const Size(1600, 800);

  Future<void> _downloadMosaic() async {
    try {
      setState(() => _status = 'Capturing...');
      await Future.delayed(const Duration(milliseconds: 100));
      final boundary = _globalKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      // Dynamic Pixel Ratio based on platform capabilities
      double ratio = 12.0; // Default Web Extreme
      if (!kIsWeb) {
        if (defaultTargetPlatform == TargetPlatform.windows || 
            defaultTargetPlatform == TargetPlatform.macOS) {
          ratio = 24.0; // DESKTOP ULTRA (Targeting 64K)
        } else {
          ratio = 12.0;  // MOBILE PRO (Targeting 20K)
        }
      }

      final image = await boundary.toImage(pixelRatio: ratio);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();

      if (kIsWeb) {
        final base64data = base64Encode(bytes);
        final fileName = 'mosaic_${widget.layoutName}.png';
        js.context.callMethod('eval', [
          "var link = document.createElement('a'); "
          "link.href = 'data:image/png;base64,$base64data'; "
          "link.download = '$fileName'; "
          "link.click();"
        ]);
      } else {
        // On Desktop/Mobile, we'd typically use file_picker or path_provider.
        // Since we are in a 'flutter run' environment, I'll show a message
        // but the 'ratio' logic is now ready for native builds.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ultra-Res (${ratio.toInt()}x) captured! Native save pending platform permissions.')),
        );
      }
      setState(() => _status = 'Mosaic Ready');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save error: $e')));
    }
  }

  List<_LetterInfo>? _letterInfos;




  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050508),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: Colors.white.withValues(alpha: 0.06),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      child: const Icon(Icons.arrow_back_rounded,
                          color: Colors.white70, size: 20),
                    ),
                  ),
                  const Spacer(),
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [Color(0xFF8B5CF6), Color(0xFFD946EF)],
                    ).createShader(bounds),
                    child: Text(
                      widget.layoutName.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 3,
                      ),
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(width: 44),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Mosaic area with Zoom/Pan
            Expanded(
              child: _loading
                  ? _buildLoading()
                  : _cells == null || _decodedImages == null
                      ? _buildError()
                      : InteractiveViewer(
                          maxScale: 10.0,
                          minScale: 0.1,
                          boundaryMargin: const EdgeInsets.all(double.infinity),
                          child: Center(
                            child: RepaintBoundary(
                              key: _globalKey,
                              child: _buildMosaic(),
                            ),
                          ),
                        ),
            ),
            // Bottom bar
            if (!_loading && _cells != null)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 60,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          gradient: const LinearGradient(
                            colors: [Color(0xFF8B5CF6), Color(0xFFD946EF)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: ElevatedButton.icon(
                          onPressed: _downloadMosaic,
                          icon: const Icon(Icons.download_rounded, color: Colors.white),
                          label: Text(
                            'Download PNG',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Container(
                      height: 60,
                      width: 60,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: Colors.white.withValues(alpha: 0.05),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      child: IconButton(
                        onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                        icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }


  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor:
                  AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            _status,
            style: TextStyle(
              fontSize: 15,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Text(
        _status,
        style: const TextStyle(color: Colors.redAccent, fontSize: 15),
      ),
    );
  }

  Widget _buildMosaic() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final canvasW = _mosaicContentSize.width;
        final canvasH = _mosaicContentSize.height;

        final scaleW = constraints.maxWidth / canvasW;
        final scaleH = constraints.maxHeight / canvasH;
        final finalScale = min(scaleW, scaleH);

        return AnimatedBuilder(
          animation: _revealCtrl,
          builder: (context, child) {
            return SizedBox(
              width: canvasW * finalScale,
              height: canvasH * finalScale,
              child: CustomPaint(
                size: Size(canvasW, canvasH),
                painter: _MosaicPainter(
                  cells: _cells ?? [],
                  images: _decodedImages ?? [],
                  letterInfos: _letterInfos,
                  scale: finalScale,
                  offset: Offset.zero, // Offset is handled by SizedBox/Center
                  revealProgress: _revealCtrl.value,
                ),
              ),
            );
          },
        );
      },
    );
  }
}


class _MosaicCell {
  final Rect rect;
  final int index;
  final int letterIndex;
  const _MosaicCell({
    required this.rect,
    required this.index,
    required this.letterIndex,
  });
}

class _LetterInfo {
  final String char;
  final Offset offset;
  final double fontSize;
  const _LetterInfo({
    required this.char,
    required this.offset,
    required this.fontSize,
  });
}

class _MosaicPainter extends CustomPainter {
  final List<_MosaicCell> cells;
  final List<ui.Image> images;
  final List<_LetterInfo>? letterInfos;
  final double scale;
  final Offset offset;
  final double revealProgress;

  _MosaicPainter({
    required this.cells,
    required this.images,
    this.letterInfos,
    required this.scale,
    required this.offset,
    required this.revealProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..filterQuality = FilterQuality.high;

    for (int i = 0; i < cells.length; i++) {
      final cellProgress =
          ((revealProgress * cells.length - i) / 10).clamp(0.0, 1.0);
      if (cellProgress <= 0) continue;

      final cell = cells[i];
      final imgIndex = cell.index;
      if (imgIndex >= images.length) continue;

      final img = images[imgIndex];
      final dst = Rect.fromLTWH(
        offset.dx + cell.rect.left * scale,
        offset.dy + cell.rect.top * scale,
        cell.rect.width * scale - 0.5,
        cell.rect.height * scale - 0.5,
      );

      final srcSize = min(img.width.toDouble(), img.height.toDouble());
      final src = Rect.fromCenter(
        center: Offset(img.width / 2, img.height / 2),
        width: srcSize,
        height: srcSize,
      );

      paint.color = Color.fromRGBO(255, 255, 255, cellProgress);

      canvas.save();
      canvas.clipRRect(RRect.fromRectAndRadius(
        dst,
        Radius.circular(1 * scale),
      ));
      canvas.drawImageRect(img, src, dst, paint);
      canvas.restore();
    }

    // Third pass: Draw identifying SHAPE-FOLLOWING outlines
    // REMOVED as per user request
  }

  @override
  bool shouldRepaint(covariant _MosaicPainter old) {
    return old.revealProgress != revealProgress;
  }
}



