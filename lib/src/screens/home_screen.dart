import 'package:eupeel_expo/src/models/producto_cosbiome_model.dart';
import 'package:eupeel_expo/src/providers/nfc_provider.dart';
import 'package:eupeel_expo/src/providers/venta_provider.dart';
import 'package:eupeel_expo/src/services/nfc_services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    final nfc = ref.read(nfcProvider);

    Future.delayed(Duration.zero, () {
      nfc.toggleAutoLoop(context, true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final nfc = ref.watch(nfcProvider);
    final venta = ref.read(ventaProvider);
    final size = MediaQuery.of(context).size;

    if (nfc.status == "¡Lectura Auto Exitosa!") {
      print(nfc.status);
      venta.handleAddProductoEupeel(
        context: context,
        almacen: "general",
        producto: ProductoCosbiomeModel(
          id: nfc.readText,
        ),
        cantidad: 1,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home Screen'),
      ),
      body: Center(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'REGISTRO PRODUCTO ESTATUS:',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                color: Colors.black54,
              ),
            ),
            Text(
              nfc.status,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: size.height * 0.02),
            const Text(
              'PRODUCTO LEÍDO:',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                color: Colors.black54,
              ),
            ),
            Text(
              nfc.readText,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: size.height * 0.4,

              child: ListView.separated(
                itemBuilder: (_, index) {
                  final producto = venta.productosVenta[index];
                  return ListTile(
                    title: Text(producto["producto"]),
                    subtitle: Text('Cantidad: ${producto["cantidad"]}'),
                  );
                },
                separatorBuilder: (_, __) => const Divider(),
                itemCount: venta.productosVenta.length,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'SUBTOTAL: ${venta.subTotal}',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
