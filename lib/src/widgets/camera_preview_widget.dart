import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

/// Widget que muestra un preview de la cámara y captura imágenes constantemente
class CameraPreviewWidget extends StatefulWidget {
  /// Callback que se llama cada vez que se captura una imagen
  final Function(XFile? imageFile) onImageCaptured;

  /// Intervalo de tiempo entre capturas en milisegundos (default: 1000ms = 1 segundo)
  final int captureIntervalMs;

  /// Cámara a usar (default: primera cámara trasera disponible)
  final CameraDescription? camera;

  /// Habilita o deshabilita la captura automática de imágenes (default: true)
  final bool enableAutoCapture;

  /// Habilita el recuadro de escaneo y el recorte de imagen (default: false)
  final bool enableScanBox;

  /// Porcentaje del ancho para el recuadro de escaneo (default: 0.8 = 80%)
  final double scanBoxWidthRatio;

  /// Porcentaje del alto para el recuadro de escaneo (default: 0.4 = 40%)
  final double scanBoxHeightRatio;

  const CameraPreviewWidget({
    super.key,
    required this.onImageCaptured,
    this.captureIntervalMs = 1000,
    this.camera,
    this.enableAutoCapture = true,
    this.enableScanBox = false,
    this.scanBoxWidthRatio = 0.8,
    this.scanBoxHeightRatio = 0.4,
  });

  @override
  State<CameraPreviewWidget> createState() => _CameraPreviewWidgetState();
}

class _CameraPreviewWidgetState extends State<CameraPreviewWidget> {
  CameraController? _controller;
  Timer? _captureTimer;
  bool _isInitialized = false;
  String? _errorMessage;
  bool _isCapturing = false;
  final GlobalKey _cameraPreviewKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  @override
  void didUpdateWidget(CameraPreviewWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Detectar cambios en enableAutoCapture
    if (oldWidget.enableAutoCapture != widget.enableAutoCapture) {
      if (widget.enableAutoCapture) {
        // Iniciar captura si se habilitó
        _startAutoCapture();
      } else {
        // Detener captura si se deshabilitó
        _stopAutoCapture();
      }
    }
  }

  Future<void> _initializeCamera() async {
    try {
      // Obtener las cámaras disponibles
      final cameras = await availableCameras();

      if (cameras.isEmpty) {
        setState(() {
          _errorMessage = 'No se encontraron cámaras disponibles';
        });
        return;
      }

      // Usar la cámara especificada o la primera trasera disponible
      final camera =
          widget.camera ??
          cameras.firstWhere(
            (camera) => camera.lensDirection == CameraLensDirection.back,
            orElse: () => cameras.first,
          );

      // Crear el controller
      _controller = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      // Inicializar el controller
      await _controller!.initialize();

      if (!mounted) return;

      setState(() {
        _isInitialized = true;
      });

      // Iniciar la captura automática solo si está habilitada
      if (widget.enableAutoCapture) {
        _startAutoCapture();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error al inicializar la cámara: $e';
      });
    }
  }

  void _startAutoCapture() {
    // Evitar iniciar múltiples timers
    if (_captureTimer != null && _captureTimer!.isActive) {
      return;
    }

    _captureTimer = Timer.periodic(
      Duration(milliseconds: widget.captureIntervalMs),
      (_) => _captureImage(),
    );
  }

  void _stopAutoCapture() {
    _captureTimer?.cancel();
    _captureTimer = null;
  }

  Future<void> _captureImage() async {
    // Evitar capturas simultáneas
    if (_isCapturing ||
        _controller == null ||
        !_controller!.value.isInitialized) {
      return;
    }

    try {
      _isCapturing = true;

      // Capturar la imagen
      final XFile imageFile = await _controller!.takePicture();

      // Si el recuadro de escaneo está habilitado, recortar la imagen
      if (widget.enableScanBox) {
        final croppedFile = await _cropImageToScanBox(imageFile);
        widget.onImageCaptured(croppedFile);
      } else {
        // Llamar al callback con la imagen capturada completa
        widget.onImageCaptured(imageFile);
      }
    } catch (e) {
      // En caso de error, pasar null al callback
      widget.onImageCaptured(null);
      debugPrint('Error al capturar imagen: $e');
    } finally {
      _isCapturing = false;
    }
  }

  Future<XFile?> _cropImageToScanBox(XFile imageFile) async {
    try {
      // Leer la imagen
      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);

      if (image == null) return imageFile;

      // Obtener el contexto del preview para calcular proporciones
      final RenderBox? renderBox =
          _cameraPreviewKey.currentContext?.findRenderObject() as RenderBox?;

      if (renderBox == null) return imageFile;

      final previewSize = renderBox.size;

      // Calcular el tamaño del recuadro en píxeles de la pantalla
      final boxWidth = previewSize.width * widget.scanBoxWidthRatio;
      final boxHeight = previewSize.height * widget.scanBoxHeightRatio;
      final boxLeft = (previewSize.width - boxWidth) / 2;
      final boxTop = (previewSize.height - boxHeight) / 2;

      // Calcular la escala entre la imagen y el preview
      final scaleX = image.width / previewSize.width;
      final scaleY = image.height / previewSize.height;

      // Calcular las coordenadas de recorte en la imagen original
      final cropX = (boxLeft * scaleX).round();
      final cropY = (boxTop * scaleY).round();
      final cropWidth = (boxWidth * scaleX).round();
      final cropHeight = (boxHeight * scaleY).round();

      // Recortar la imagen
      final croppedImage = img.copyCrop(
        image,
        x: cropX,
        y: cropY,
        width: cropWidth,
        height: cropHeight,
      );

      // Guardar la imagen recortada
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final croppedPath = path.join(tempDir.path, 'cropped_$timestamp.jpg');

      final croppedFile = File(croppedPath);
      await croppedFile.writeAsBytes(img.encodeJpg(croppedImage));

      return XFile(croppedPath);
    } catch (e) {
      debugPrint('Error al recortar imagen: $e');
      return imageFile; // Retornar la imagen original en caso de error
    }
  }

  @override
  void dispose() {
    _captureTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 48,
                color: Colors.red,
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
            ],
          ),
        ),
      );
    }

    if (!_isInitialized || _controller == null) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: AspectRatio(
        aspectRatio: _controller!.value.aspectRatio,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CameraPreview(
              _controller!,
              key: _cameraPreviewKey,
            ),
            if (widget.enableScanBox) _buildScanBoxOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildScanBoxOverlay() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boxWidth = constraints.maxWidth * widget.scanBoxWidthRatio;
        final boxHeight = constraints.maxHeight * widget.scanBoxHeightRatio;
        final boxLeft = (constraints.maxWidth - boxWidth) / 2;
        final boxTop = (constraints.maxHeight - boxHeight) / 2;

        return Stack(
          children: [
            // Overlay oscuro con recorte transparente en el centro
            CustomPaint(
              size: Size(constraints.maxWidth, constraints.maxHeight),
              painter: _ScanBoxPainter(
                boxRect: Rect.fromLTWH(boxLeft, boxTop, boxWidth, boxHeight),
              ),
            ),
            // Borde del recuadro
            Positioned(
              left: boxLeft,
              top: boxTop,
              child: Container(
                width: boxWidth,
                height: boxHeight,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.white,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            // Esquinas del recuadro
            Positioned(
              left: boxLeft - 2,
              top: boxTop - 2,
              child: _buildCorner(top: true, left: true),
            ),
            Positioned(
              right: (constraints.maxWidth - boxLeft - boxWidth) - 2,
              top: boxTop - 2,
              child: _buildCorner(top: true, right: true),
            ),
            Positioned(
              left: boxLeft - 2,
              bottom: (constraints.maxHeight - boxTop - boxHeight) - 2,
              child: _buildCorner(bottom: true, left: true),
            ),
            Positioned(
              right: (constraints.maxWidth - boxLeft - boxWidth) - 2,
              bottom: (constraints.maxHeight - boxTop - boxHeight) - 2,
              child: _buildCorner(bottom: true, right: true),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCorner({
    bool top = false,
    bool bottom = false,
    bool left = false,
    bool right = false,
  }) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        border: Border(
          top: top
              ? const BorderSide(color: Colors.greenAccent, width: 5)
              : BorderSide.none,
          bottom: bottom
              ? const BorderSide(color: Colors.greenAccent, width: 5)
              : BorderSide.none,
          left: left
              ? const BorderSide(color: Colors.greenAccent, width: 5)
              : BorderSide.none,
          right: right
              ? const BorderSide(color: Colors.greenAccent, width: 5)
              : BorderSide.none,
        ),
      ),
    );
  }
}

/// Painter para crear un overlay oscuro con un recorte transparente
class _ScanBoxPainter extends CustomPainter {
  final Rect boxRect;

  _ScanBoxPainter({required this.boxRect});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.6)
      ..style = PaintingStyle.fill;

    // Crear el path con el recorte
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(
        RRect.fromRectAndRadius(
          boxRect,
          const Radius.circular(8),
        ),
      )
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_ScanBoxPainter oldDelegate) =>
      boxRect != oldDelegate.boxRect;
}
