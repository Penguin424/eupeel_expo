import 'package:eupeel_expo/src/providers/almacen_provider.dart';
import 'package:eupeel_expo/src/providers/venta_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FormAddProductoWidget extends ConsumerStatefulWidget {
  final BuildContext? dialogContext;

  const FormAddProductoWidget({super.key, this.dialogContext});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() =>
      _FormAddProductoWidgetState();
}

class _FormAddProductoWidgetState extends ConsumerState<FormAddProductoWidget> {
  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final almacen = ref.watch(almacenProvider);
    final venta = ref.watch(ventaProvider);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(8.0),
      child: Center(
        child: Container(
          width: size.width * 0.8,
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 10.0,
                offset: Offset(0, 4),
              ),
            ],
          ),
          constraints: BoxConstraints(
            maxHeight: size.height * 0.6,
          ),
          child: SingleChildScrollView(
            child: Form(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Producto Encontrado:',
                    style: Theme.of(context).textTheme.headlineLarge!.copyWith(
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    'Nombre: ${almacen.productoAlmacenModel!.nombreProducto}',
                    style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                      color: Colors.black87,
                    ),
                  ),

                  const SizedBox(
                    height: 20,
                  ),
                  TextFormField(
                    initialValue: venta.cantidad.toString(),
                    decoration: InputDecoration(
                      labelText: 'Descripción',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      final cantidad = int.tryParse(value) ?? 1;
                      venta.cantidad = cantidad;
                    },
                  ),
                  const SizedBox(
                    height: 5,
                  ),
                  Text(
                    'Cantidad Disponible: ${almacen.productoAlmacenModel!.general}',
                    style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(
                    height: 20,
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      await venta.handleAddProductoEupeel(
                        context: widget.dialogContext ?? context,
                        almacen: "general",
                        producto: almacen.productoAlmacenModel!,
                        cantidad: venta.cantidad,
                      );

                      almacen.enableScanning = true;

                      Navigator.of(context).pop();
                    },
                    child: const Text('Agregar Producto'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
