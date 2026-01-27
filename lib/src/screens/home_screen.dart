import 'package:eupeel_expo/src/models/producto_cosbiome_model.dart';
import 'package:eupeel_expo/src/providers/almacen_provider.dart';
import 'package:eupeel_expo/src/providers/venta_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager_ndef/nfc_manager_ndef.dart';

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

              const SizedBox(height: 20),

              ElevatedButton(
                onPressed: () async {
                  NfcAvailability availability = await NfcManager.instance
                      .checkAvailability();

                  if (availability != NfcAvailability.enabled) {
                    print(
                      'NFC may not be supported or may be temporarily disabled.',
                    );
                    return;
                  }

                  // Start the session.

                  NfcManager.instance.startSession(
                    onSessionErrorIos: (p0) {
                      print('NFC Session Error: ${p0.message}');

                      NfcManager.instance.stopSession();
                    },
                    alertMessageIos: 'Acerca el dispositivo al tag NFC',
                    pollingOptions: {
                      NfcPollingOption.iso14443,
                    },
                    onDiscovered: (NfcTag tag) async {
                      // Do something with an NfcTag instance...
                      final Ndef? ndef = Ndef.from(tag);

                      if (ndef == null) {
                        print('This tag is not compatible with NDEF.');
                        return;
                      }

                      final ndefMessage = await ndef.read();

                      if (ndefMessage == null) {
                        print('Failed to read NDEF message from the tag.');
                        return;
                      }

                      final payload = ndefMessage.records.first.payload;
                      String payloadString = String.fromCharCodes(
                        payload,
                      ).split("en").last;

                      await venta.handleAddProductoEupeel(
                        context: context,
                        almacen: "general",
                        producto: ProductoCosbiomeModel(
                          id: payloadString,
                        ),
                        cantidad: 1,
                      );

                      await NfcManager.instance.stopSession();
                    },
                  );
                },
                child: const Text("Escanear Producto"),
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
