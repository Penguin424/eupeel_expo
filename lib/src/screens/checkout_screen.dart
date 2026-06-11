import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:eupeel_expo/src/models/producto_cosbiome_model.dart';
import 'package:eupeel_expo/src/providers/almacen_provider.dart';
import 'package:eupeel_expo/src/providers/nfc_provider.dart';
import 'package:eupeel_expo/src/providers/venta_provider.dart';
import 'package:eupeel_expo/src/services/venta_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  String _currency(double amount) => '\$${amount.toStringAsFixed(2)}';

  Future<Uint8List> _buildFacturaPdf({
    required VentaService venta,
    required List<ProductoCosbiomeModel> catalogoProductos,
  }) async {
    final pdf = pw.Document();
    final now = DateTime.now();
    final descuentoMonto = venta.subTotal - venta.total;
    final descuentoPorcentaje = ((1 - venta.descuento) * 100).clamp(0, 100);

    // Cargar logo desde assets
    final logoBytes = await rootBundle.load('assets/images/eupeel_logo.png');
    final logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());

    // Descargar imágenes de cada producto desde S3
    final dio = Dio();
    final Map<String, pw.MemoryImage?> imagenesPorNombre = {};
    for (final prod in venta.productosVenta) {
      final nombre = prod["producto"]?.toString() ?? '';
      if (imagenesPorNombre.containsKey(nombre)) continue;
      try {
        final match = catalogoProductos.firstWhere(
          (p) => p.nombreProducto == nombre,
          orElse: () => ProductoCosbiomeModel(),
        );
        final url = match.s3url;
        if (url != null && url.isNotEmpty) {
          final resp = await dio.get<List<int>>(
            url,
            options: Options(responseType: ResponseType.bytes),
          );
          if (resp.data != null) {
            imagenesPorNombre[nombre] = pw.MemoryImage(
              Uint8List.fromList(resp.data!),
            );
          } else {
            imagenesPorNombre[nombre] = null;
          }
        } else {
          imagenesPorNombre[nombre] = null;
        }
      } catch (_) {
        imagenesPorNombre[nombre] = null;
      }
    }

    pdf.addPage(
      pw.MultiPage(
        build: (context) => [
          // Encabezado: título izquierda, logo derecha
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text(
                'Cotización',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Image(
                logoImage,
                width: 100,
                height: 50,
                fit: pw.BoxFit.contain,
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Text('Fecha: ${DateFormat('dd/MM/yyyy HH:mm').format(now)}'),
          pw.Text(
            'Cliente: ${venta.nombreCliente.trim().isEmpty ? 'Sin nombre' : venta.nombreCliente.trim()}',
          ),
          pw.SizedBox(height: 16),
          // Filas de productos con imagen
          ...venta.productosVenta.map((prod) {
            final nombre = prod["producto"]?.toString() ?? '-';
            final cantidad = int.tryParse(prod["cantidad"].toString()) ?? 0;
            final precio = double.tryParse(prod["precio"].toString()) ?? 0;
            final importe = precio * cantidad;
            final imgWidget = imagenesPorNombre[nombre];

            return pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 8),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: pw.BorderRadius.circular(4),
              ),
              padding: const pw.EdgeInsets.all(8),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  if (imgWidget != null)
                    pw.Container(
                      width: 70,
                      height: 70,
                      margin: const pw.EdgeInsets.only(right: 12),
                      child: pw.Image(imgWidget, fit: pw.BoxFit.contain),
                    )
                  else
                    pw.Container(
                      width: 70,
                      height: 70,
                      margin: const pw.EdgeInsets.only(right: 12),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.grey200,
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                    ),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          nombre,
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text('Cantidad: $cantidad'),
                        pw.Text('Precio unitario: ${_currency(precio)}'),
                        pw.Text(
                          'ID: ${catalogoProductos.firstWhere((c) => c.nombreProducto == nombre, orElse: () => ProductoCosbiomeModel()).id ?? ''}',
                          style: const pw.TextStyle(
                            fontSize: 8,
                            color: PdfColors.grey600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  pw.Text(
                    _currency(importe),
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            );
          }),
          pw.SizedBox(height: 16),
          pw.Divider(),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Sub total:',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(_currency(venta.subTotal)),
            ],
          ),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Descuento (${descuentoPorcentaje.toStringAsFixed(2)}%):',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(_currency(descuentoMonto)),
            ],
          ),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Total:',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              pw.Text(
                _currency(venta.total),
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ],
      ),
    );

    return pdf.save();
  }

  Future<void> _descargarFactura(VentaService venta) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (venta.productosVenta.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Agrega al menos un producto para generar la cotización.',
          ),
        ),
      );
      return;
    }

    try {
      final catalogoProductos = ref.read(almacenProvider).productos;
      final pdfBytes = await _buildFacturaPdf(
        venta: venta,
        catalogoProductos: catalogoProductos,
      );
      final downloadDir = await getDownloadsDirectory();
      final baseDir = downloadDir ?? await getApplicationDocumentsDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final clientSanitized = venta.nombreCliente
          .trim()
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
          .replaceAll(RegExp(r'_+'), '_')
          .replaceAll(RegExp(r'^_|_$'), '');
      final clientName = clientSanitized.isEmpty ? 'cliente' : clientSanitized;
      final filePath = p.join(
        baseDir.path,
        'cotizacion_${clientName}_$timestamp.pdf',
      );

      final file = File(filePath);
      await file.writeAsBytes(pdfBytes, flush: true);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cotización descargada en: $filePath')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo descargar la cotización: $e')),
      );
    }
  }

  /// Lee un PDF de cotización generado por esta app, extrae los IDs y
  /// cantidades embebidos en el texto, y agrega los productos a la venta.
  Future<void> _importarCotizacion(VentaService venta) async {
    try {
      // 1. Elegir archivo PDF
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) return;

      final filePath = result.files.single.path;
      if (filePath == null) return;

      // 2. Extraer texto del PDF con Syncfusion
      final fileBytes = await File(filePath).readAsBytes();
      final sfDoc = sf.PdfDocument(inputBytes: fileBytes);
      final extractor = sf.PdfTextExtractor(sfDoc);
      final rawText = extractor.extractText();
      sfDoc.dispose();

      // 3. Parsear pares ID / Cantidad desde el texto
      // El PDF embebe: "ID: <id>" y "Cantidad: <n>" en cada bloque de producto.
      final lineas = rawText.split('\n').map((l) => l.trim()).toList();

      // Mapa: id del producto → cantidad
      final Map<String, int> idsCantidad = {};

      for (int i = 0; i < lineas.length; i++) {
        final idMatch = RegExp(
          r'^ID:\s*(.+)$',
          caseSensitive: false,
        ).firstMatch(lineas[i]);

        if (idMatch == null) continue;
        final id = idMatch.group(1)?.trim() ?? '';
        if (id.isEmpty) continue;

        // Buscar "Cantidad: X" en el bloque cercano (±8 líneas)
        int cantidad = 1;
        for (int delta = -8; delta <= 8; delta++) {
          final j = i + delta;
          if (j < 0 || j >= lineas.length || j == i) continue;
          final cantMatch = RegExp(
            r'Cantidad[:\s]+(\d+)',
            caseSensitive: false,
          ).firstMatch(lineas[j]);
          if (cantMatch != null) {
            cantidad = int.tryParse(cantMatch.group(1) ?? '1') ?? 1;
            break;
          }
        }

        idsCantidad[id] = cantidad;
      }

      if (idsCantidad.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se encontraron productos con ID en el PDF.\n'
              'Asegúrate de usar una cotización generada por esta app.',
            ),
          ),
        );
        return;
      }

      // 4. Agregar cada producto a la venta por su ID
      int agregados = 0;
      for (final entry in idsCantidad.entries) {
        await venta.handleAddProductoEupeel(
          context: context,
          almacen: venta.almacenVenta,
          producto: ProductoCosbiomeModel(id: entry.key),
          cantidad: entry.value,
        );
        agregados++;
      }

      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$agregados producto(s) importado(s) desde la cotización.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al importar cotización: $e')),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    final nfc = ref.read(nfcProvider);
    final venta = ref.read(ventaProvider);

    Future.delayed(Duration.zero, () {
      venta.isRedirectToCheckOut = false;
      nfc.toggleAutoLoop(context, true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final nfc = ref.watch(nfcProvider);
    final venta = ref.read(ventaProvider);
    final size = MediaQuery.of(context).size;
    final almacen = ref.watch(almacenProvider);

    print("ESTADO DE LECTURA NFC: ${nfc.status}");

    if (nfc.status == "¡Lectura Auto Exitosa!") {
      venta.handleAddProductoEupeel(
        context: context,
        almacen: venta.almacenVenta,
        producto: ProductoCosbiomeModel(
          id: nfc.readText,
        ),
        cantidad: 1,
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,

              children: [
                Hero(
                  tag: "eupeel_logo_png",
                  child: Image.asset(
                    'assets/images/eupeel_logo.png',
                    width: size.width * 0.2,
                    height: size.height * 0.2,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(
                  height: 20,
                ),
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Nombre',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(50)),
                    ),
                  ),
                  onChanged: (value) {
                    venta.nombreCliente = value;
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor ingresa tu nombre';
                    }
                    return null;
                  },
                ),
                const SizedBox(
                  height: 5,
                ),
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Numero de telefono',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(50)),
                    ),
                  ),
                  onChanged: (value) {
                    venta.numTel = value;
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor ingresa tu numero de telefono';
                    }
                    return null;
                  },
                ),

                const SizedBox(
                  height: 20,
                ),
                Container(
                  constraints: BoxConstraints(
                    minHeight: size.height * 0.1,
                    maxHeight: size.height * 0.4,
                  ),
                  width: size.width * 0.9,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(),
                  child: ListView(
                    children: [
                      ...venta.productosVenta.map(
                        (producto) {
                          final productoAlamcen = almacen.productos.firstWhere((
                            prod,
                          ) {
                            return prod.nombreProducto == producto["producto"];
                          });

                          return Column(
                            children: [
                              ListTile(
                                // leading: Image.network(
                                //   productoAlamcen.s3url!,
                                //   width: 50,
                                //   height: 50,
                                //   fit: BoxFit.cover,
                                // ),
                                title: Text(
                                  productoAlamcen.nombreProducto!,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 22,
                                  ),
                                ),
                                subtitle: Row(
                                  children: [
                                    IconButton(
                                      onPressed: () {
                                        venta.handleRemoveProductoVenta(
                                          producto: {
                                            "producto": producto["producto"],
                                          },
                                        );
                                        setState(() {});
                                      },
                                      icon: const Icon(
                                        Icons.remove_circle_outline,
                                      ),
                                    ),
                                    Text(
                                      'Cantidad: ${producto["cantidad"]}',
                                      style: const TextStyle(
                                        fontSize: 18,
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () async {
                                        await venta.handleAddProductoEupeel(
                                          context: context,
                                          almacen: venta.almacenVenta,
                                          producto: ProductoCosbiomeModel(
                                            id: productoAlamcen.id,
                                          ),
                                          cantidad: 1,
                                        );
                                        setState(() {});
                                      },
                                      icon: const Icon(
                                        Icons.add_circle_outline,
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: Text(
                                  '\$${(double.parse(producto["precio"].toString()) * int.parse(producto["cantidad"].toString())).toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 20,
                                  ),
                                ),
                              ),
                              const Divider(),
                            ],
                          );
                        },
                      ).toList(),

                      const SizedBox(
                        height: 20,
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Sub total:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 24,
                              color: Colors.black38,
                            ),
                          ),
                          Text(
                            '\$${venta.subTotal.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 24,
                              color: Colors.black38,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Descuento:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 24,
                              color: Colors.black54,
                            ),
                          ),
                          Text(
                            '\$${(venta.subTotal - venta.total).toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 24,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 24,
                              color: Colors.black87,
                            ),
                          ),
                          Text(
                            '\$${venta.total.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 24,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(
                  height: 20,
                ),
                DropdownButtonFormField<String>(
                  value: venta.almacenVenta,
                  decoration: const InputDecoration(
                    labelText: "Almacén",
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: "enExpo",
                      child: Text("En Expo"),
                    ),
                    DropdownMenuItem(
                      value: "salida",
                      child: Text("Salida"),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    venta.almacenVenta = value;
                    setState(() {});
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: venta.metodoPago,
                  validator: (value) {
                    if (value!.isEmpty) {
                      return "El metodo de pago es requerido";
                    }
                    return null;
                  },
                  decoration: const InputDecoration(
                    labelText: "Metodo de Pago",
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: "",
                      child: Text(""),
                    ),
                    DropdownMenuItem(
                      value: "Efectivo",
                      child: Text("Efectivo"),
                    ),
                    DropdownMenuItem(
                      value: "Transferencia",
                      child: Text("Transferencia"),
                    ),
                    DropdownMenuItem(
                      value: "Tarjeta",
                      child: Text("Tarjeta"),
                    ),
                  ],
                  onChanged: (value) {
                    venta.metodoPago = value!;
                  },
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: () => _importarCotizacion(venta),
                  icon: const Icon(Icons.upload_file),
                  label: const Text("Importar cotización PDF"),
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: () => _descargarFactura(venta),
                  icon: const Icon(Icons.download),
                  label: const Text("Descargar cotización PDF"),
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () async {
                    if (_formKey.currentState!.validate()) {
                      // Process data.
                      await venta.handleRegistrarVenta(
                        context,
                      );

                      venta.nombreCliente = "";
                      venta.numTel = "";
                      venta.metodoPago = "";
                      venta.nota = "";
                      venta.almacenVenta = "enExpo";
                      venta.subTotal = 0;
                      venta.descuento = 0;
                      venta.total = 0;
                      venta.productosVenta = [];

                      if (context.mounted) {
                        Navigator.pushNamedAndRemoveUntil(
                          context,
                          "/",
                          (route) => false,
                        );
                      }
                    }
                  },
                  child: const Text("Realizar compra"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
