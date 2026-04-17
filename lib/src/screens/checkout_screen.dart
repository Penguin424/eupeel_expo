import 'package:eupeel_expo/src/models/producto_cosbiome_model.dart';
import 'package:eupeel_expo/src/providers/almacen_provider.dart';
import 'package:eupeel_expo/src/providers/nfc_provider.dart';
import 'package:eupeel_expo/src/providers/venta_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

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
        almacen: "enExpo",
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
                                          almacen: "enExpo",
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
