import 'package:eupeel_expo/src/providers/almacen_provider.dart';
import 'package:eupeel_expo/src/providers/venta_provider.dart';
import 'package:eupeel_expo/src/widgets/camera_preview_widget.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final almacen = ref.watch(almacenProvider);
    final size = MediaQuery.of(context).size;
    final venta = ref.watch(ventaProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home Screen'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                almacen.scannedTextService,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),

              Text(
                "Escano activado: ${almacen.enableScanning ? "SI" : "NO"}",
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),

              const SizedBox(height: 20),

              SizedBox(
                height: size.height * 0.2,
                child: CameraPreviewWidget(
                  enableAutoCapture: almacen.enableScanning,
                  captureIntervalMs: 2200,
                  enableScanBox: true, // Activa el recuadro de escaneo
                  scanBoxWidthRatio: 0.8, // 80% del ancho
                  scanBoxHeightRatio: 0.4, //
                  onImageCaptured: (imageFile) async {
                    final inputImage = InputImage.fromFilePath(imageFile!.path);
                    final textRecognizer = TextRecognizer(
                      script: TextRecognitionScript.latin,
                    );
                    final RecognizedText recognizedText = await textRecognizer
                        .processImage(
                          inputImage,
                        );
                    String scannedText = "";

                    for (var block in recognizedText.blocks) {
                      scannedText = block.text.trim().replaceAll(" ", "");
                    }

                    if (kDebugMode) {
                      print(
                        "TEXTO DETECTADO: $scannedText",
                      );
                    }

                    if (scannedText.isEmpty) {
                      almacen.scannedTextService =
                          'No se detectó texto en la imagen.';
                    } else {
                      final regex = RegExp(r'\b\w{24}\b');
                      final match = regex.firstMatch(scannedText);

                      if (match != null) {
                        scannedText = match.group(0)!;
                      } else {
                        almacen.scannedTextService =
                            'No se encontró un ID válido de 24 caracteres.';
                      }
                    }

                    textRecognizer.close();

                    await almacen.handleGetProductoConId(
                      context,
                      scannedText,
                      size,
                    );
                  },
                ),
              ),

              const SizedBox(height: 20),

              SizedBox(
                height: size.height * 0.4,
                width: double.infinity,
                child: ListView.separated(
                  itemBuilder: (context, index) {
                    final producto = venta.productosVenta[index];
                    return ListTile(
                      title: Text(
                        "Producto ID: ${producto["producto"]}",
                      ),
                      subtitle: Text(
                        "Cantidad: ${producto["cantidad"]} - Precio: \$${producto["precio"]}",
                      ),
                    );
                  },
                  separatorBuilder: (context, index) {
                    return const Divider();
                  },
                  itemCount: venta.productosVenta.length,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
