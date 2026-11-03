// lib/widgets/profile_photo_cropper.dart
// Crop step shown after a profile photo is picked: drag to move, pinch or use the
// slider to zoom, choose a circle or square crop. Returns the cropped PNG bytes
// (or null if the user cancels).

import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Opens the crop screen. Returns cropped PNG bytes, or null when cancelled.
Future<Uint8List?> cropProfilePhoto(BuildContext context, Uint8List imageBytes) {
  return Navigator.of(context).push<Uint8List>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => ProfilePhotoCropScreen(imageBytes: imageBytes),
    ),
  );
}

class ProfilePhotoCropScreen extends StatefulWidget {
  const ProfilePhotoCropScreen({super.key, required this.imageBytes});

  final Uint8List imageBytes;

  /// Side length (px) of the exported square image.
  static const double outputSize = 800;

  @override
  State<ProfilePhotoCropScreen> createState() => _ProfilePhotoCropScreenState();
}

class _ProfilePhotoCropScreenState extends State<ProfilePhotoCropScreen> {
  static const double _maxZoom = 5;

  final _controller = TransformationController();
  final _boundaryKey = GlobalKey();
  ui.Image? _image;
  bool _circle = true;
  bool _saving = false;
  double _zoom = 1;
  double _viewport = 0; // side of the square crop area, set from layout
  Size _content = Size.zero; // image size scaled to cover the crop area

  @override
  void initState() {
    super.initState();
    _controller.addListener(_syncZoomFromController);
    ui.decodeImageFromList(widget.imageBytes, (img) {
      if (mounted) setState(() => _image = img);
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_syncZoomFromController);
    _controller.dispose();
    super.dispose();
  }

  void _syncZoomFromController() {
    final z = _controller.value.getMaxScaleOnAxis().clamp(1.0, _maxZoom);
    if ((z - _zoom).abs() > 0.001) setState(() => _zoom = z);
  }

  /// Centres the image in the crop area (cover fit) once the viewport is known.
  void _configure(double viewport) {
    final img = _image!;
    final scale = viewport / (img.width < img.height ? img.width : img.height);
    final content = Size(img.width * scale, img.height * scale);
    if (_viewport == viewport && _content == content) return;
    _viewport = viewport;
    _content = content;
    _controller.value = Matrix4.translationValues(
      -(content.width - viewport) / 2,
      -(content.height - viewport) / 2,
      0,
    );
  }

  /// Zooms around the centre of the crop area, keeping the image covering it.
  void _setZoom(double target) {
    final current = _controller.value.getMaxScaleOnAxis();
    final factor = target / current;
    final focal = _viewport / 2;
    final m = _controller.value.clone();
    final tx = focal - (focal - m.getTranslation().x) * factor;
    final ty = focal - (focal - m.getTranslation().y) * factor;
    final minTx = _viewport - _content.width * target;
    final minTy = _viewport - _content.height * target;
    _controller.value = Matrix4.identity()
      ..translateByDouble(tx.clamp(minTx, 0.0), ty.clamp(minTy, 0.0), 0, 1)
      ..scaleByDouble(target, target, 1, 1);
  }

  Future<void> _done() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final boundary = _boundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: ProfilePhotoCropScreen.outputSize / _viewport);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (!mounted) return;
      Navigator.of(context).pop(data!.buffer.asUint8List());
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not crop the image: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1220),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B1220),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          key: const Key('crop_cancel_button'),
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Crop photo', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16)),
        actions: [
          TextButton(
            key: const Key('crop_done_button'),
            onPressed: (_image == null || _saving) ? null : _done,
            child: _saving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text('Done', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
      body: SafeArea(
        child: _image == null
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
            : LayoutBuilder(
                builder: (context, constraints) {
                  // Crop area is square and must leave room for the controls below it.
                  final viewport = ((constraints.maxWidth - 32) < (constraints.maxHeight - 210)
                          ? (constraints.maxWidth - 32)
                          : (constraints.maxHeight - 210))
                      .clamp(140.0, 420.0);
                  _configure(viewport);
                  return Column(
                    children: [
                      const SizedBox(height: 16),
                      Text(
                        'Drag to move, pinch or use the slider to zoom',
                        style: GoogleFonts.inter(color: Colors.white70, fontSize: 12),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: viewport,
                        height: viewport,
                        child: Stack(
                          children: [
                            RepaintBoundary(
                              key: _boundaryKey,
                              child: ClipPath(
                                clipper: _CropShapeClipper(circle: _circle),
                                child: SizedBox(
                                  width: viewport,
                                  height: viewport,
                                  child: InteractiveViewer(
                                    transformationController: _controller,
                                    constrained: false,
                                    boundaryMargin: EdgeInsets.zero,
                                    minScale: 1,
                                    maxScale: _maxZoom,
                                    child: Image.memory(
                                      widget.imageBytes,
                                      width: _content.width,
                                      height: _content.height,
                                      fit: BoxFit.fill,
                                      gaplessPlayback: true,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            // Guide outline (outside the RepaintBoundary, so it is not exported)
                            IgnorePointer(
                              child: CustomPaint(
                                size: Size(viewport, viewport),
                                painter: _CropGuidePainter(circle: _circle),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Row(
                          children: [
                            const Icon(Icons.zoom_out_rounded, color: Colors.white70, size: 20),
                            Expanded(
                              child: Slider(
                                key: const Key('crop_zoom_slider'),
                                value: _zoom,
                                min: 1,
                                max: _maxZoom,
                                activeColor: const Color(0xFF38A3F5),
                                onChanged: _setZoom,
                              ),
                            ),
                            const Icon(Icons.zoom_in_rounded, color: Colors.white70, size: 20),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      SegmentedButton<bool>(
                        key: const Key('crop_shape_toggle'),
                        showSelectedIcon: false,
                        segments: const [
                          ButtonSegment(value: true, icon: Icon(Icons.circle_outlined, size: 18), label: Text('Circle')),
                          ButtonSegment(value: false, icon: Icon(Icons.crop_square_rounded, size: 18), label: Text('Square')),
                        ],
                        selected: {_circle},
                        onSelectionChanged: (v) => setState(() => _circle = v.first),
                        style: ButtonStyle(
                          foregroundColor: WidgetStateProperty.resolveWith(
                            (s) => s.contains(WidgetState.selected) ? const Color(0xFF0B1220) : Colors.white,
                          ),
                          backgroundColor: WidgetStateProperty.resolveWith(
                            (s) => s.contains(WidgetState.selected) ? Colors.white : Colors.transparent,
                          ),
                          side: const WidgetStatePropertyAll(BorderSide(color: Colors.white38)),
                        ),
                      ),
                    ],
                  );
                },
              ),
      ),
    );
  }
}

class _CropShapeClipper extends CustomClipper<Path> {
  _CropShapeClipper({required this.circle});
  final bool circle;

  @override
  Path getClip(Size size) => circle
      ? (Path()..addOval(Offset.zero & size))
      : (Path()..addRect(Offset.zero & size));

  @override
  bool shouldReclip(_CropShapeClipper old) => old.circle != circle;
}

class _CropGuidePainter extends CustomPainter {
  _CropGuidePainter({required this.circle});
  final bool circle;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.white;
    // Dim everything outside the crop shape.
    final dim = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(rect)
      ..addPath(circle ? (Path()..addOval(rect)) : (Path()..addRect(rect)), Offset.zero);
    canvas.drawPath(dim, Paint()..color = const Color(0xAA0B1220));
    if (circle) {
      canvas.drawOval(rect.deflate(1), paint);
    } else {
      canvas.drawRect(rect.deflate(1), paint);
    }
  }

  @override
  bool shouldRepaint(_CropGuidePainter old) => old.circle != circle;
}
