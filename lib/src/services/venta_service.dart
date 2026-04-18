import 'package:eupeel_expo/src/models/cosbiome_venta_response_model.dart';
import 'package:eupeel_expo/src/models/producto_cosbiome_model.dart';
import 'package:eupeel_expo/src/utils/http_utils.dart';
import 'package:eupeel_expo/src/utils/preferences_uitils.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:toastification/toastification.dart';

class VentaService extends ChangeNotifier {
  int _cantidad = 1;
  final List<Map<String, dynamic>> _productosVenta = [];
  double _total = 0;
  double _subTotal = 0;
  double _descuento = 1.0;
  String _nombreCliente = "";
  String _numTel = "";
  String _metodoPago = "";
  String _nota = "";
  ProductoCosbiomeModel _productoEupeelSelected = ProductoCosbiomeModel();
  bool _isRedirectToCheckOut = false;

  int get cantidad => _cantidad;
  List<Map<String, dynamic>> get productosVenta => _productosVenta;
  double get total => _total;
  double get subTotal => _subTotal;
  double get descuento => _descuento;
  String get nombreCliente => _nombreCliente;
  String get numTel => _numTel;
  String get metodoPago => _metodoPago;
  String get nota => _nota;
  ProductoCosbiomeModel get productoEupeel => _productoEupeelSelected;
  bool get isRedirectToCheckOut => _isRedirectToCheckOut;

  set productosVenta(List<Map<String, dynamic>> value) {
    _productosVenta.clear();
    _productosVenta.addAll(value);
    notifyListeners();
  }

  set cantidad(int value) {
    _cantidad = value;
    notifyListeners();
  }

  set total(double value) {
    _total = value;
    notifyListeners();
  }

  set subTotal(double value) {
    _subTotal = value;
    notifyListeners();
  }

  set descuento(double value) {
    _descuento = value;
    notifyListeners();
  }

  set nombreCliente(String value) {
    _nombreCliente = value;
    notifyListeners();
  }

  set numTel(String value) {
    _numTel = value;
    notifyListeners();
  }

  set metodoPago(String value) {
    _metodoPago = value;

    handleCalculateTotalVenta();

    notifyListeners();
  }

  set nota(String value) {
    _nota = value;
    notifyListeners();
  }

  set productoEupeelSelected(ProductoCosbiomeModel value) {
    _productoEupeelSelected = value;
    notifyListeners();
  }

  set isRedirectToCheckOut(bool value) {
    _isRedirectToCheckOut = value;
    notifyListeners();
  }

  Future<CosbiomeVentaResponseModel> handleRegistrarVenta(
    BuildContext context,
  ) async {
    try {
      context.loaderOverlay.show();
      final countPedidos = await Http.get(
        path: "cosbiomepedidos/count",
        parameters: {},
      );

      final idPedido = "${countPedidos.data + 1301}PU";

      Map<String, dynamic> venta = {
        "abono": false,
        "apartado": 0,
        "estatus": "PAGANDO",
        "ENVIO": "NORMAL",
        "peso": "0kg",
        "sucursal": "FEDERALISMO",
        "procesoList": [],
        "vendedor": "PUNTO DE VENTA NFC",
        "total": total,
        "subTotal": subTotal,
        "referencia": "",
        "productosCompra": productosVenta,
        "numTel": numTel,
        "nota": ".",
        "nombreCliente": nombreCliente,
        "metodoDePago": metodoPago,
        "medio": "enExpo",
        "iva": 0,
        "idPedido": idPedido,
        "idFirebase": "",
        "idCliente": "",
        "horaVenta": DateFormat("HH:mm:ss").format(DateTime.now()),
        "fechaVenta": DateFormat('MM/dd/yyyy').format(DateTime.now()),
        "fechaDeEntrega": DateFormat('yyyy-MM-dd').format(DateTime.now()),
        "direccion": {
          "tipo": ".",
          "domicilio": ".",
          "colonia": ".",
          "ciudad": ".",
          "estado": ".",
          "codigoPostal": ".",
          "cruces": ".",
        },
        "de": "",
        "cargo": 0,
        "autorizado": "",
        "a": "",
        "pagos": "puntoDeVenta",
      };

      final pedidoDB = await Http.post(
        path: "cosbiomepedidos",
        data: venta,
      );

      CosbiomeVentaResponseModel ventaResponse =
          CosbiomeVentaResponseModel.fromJson(
            pedidoDB.data,
          );

      context.loaderOverlay.hide();

      return ventaResponse;
    } catch (e) {
      context.loaderOverlay.hide();
      rethrow;
    }
  }

  void handleAddProductoVenta({
    required Map<String, dynamic> producto,
    required int cantidad,
  }) {
    final index = _productosVenta.indexWhere(
      (element) => element["producto"] == producto["producto"],
    );

    if (index != -1) {
      _productosVenta[index]["cantidad"] =
          (int.parse(_productosVenta[index]["cantidad"]) + cantidad).toString();
    } else {
      _productosVenta.add({
        "producto": producto["producto"],
        "precio": producto["precio"],
        "cantidad": cantidad.toString(),
      });
    }

    handleCalculateTotalVenta();

    notifyListeners();
  }

  Future<void> handleAddProductoEupeel({
    required BuildContext context,
    required String almacen,
    required ProductoCosbiomeModel producto,
    required int cantidad,
  }) async {
    try {
      final isStokAviable = await handleVerifyStockInAlmacen(
        context: context,
        almacen: almacen,
        producto: producto,
        cantidad: cantidad,
      );

      print("isStokAviable: $isStokAviable");

      if (!isStokAviable) {
        if (!context.mounted) return;
        toastification.show(
          context: context,
          type: ToastificationType.error,
          title: Text("Stock insuficiente"),
          description: Text(
            "No hay suficiente stock en el almacén '$almacen' para el producto '${producto.nombreProducto}'.",
          ),
        );
        return;
      }

      handleAddProductoVenta(
        producto: {
          "producto": _productoEupeelSelected.nombreProducto!,
          "precio": _productoEupeelSelected.precioVenta!.toString(),
        },
        cantidad: cantidad,
      );

      if (isRedirectToCheckOut) {
        Navigator.pushNamed(context, "/checkout");
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<bool> handleVerifyStockInAlmacen({
    required BuildContext context,
    required String almacen,
    required ProductoCosbiomeModel producto,
    required int cantidad,
  }) async {
    try {
      final productoEupeelDB = await Http.get(
        path: "cosbiomeproductos/${producto.id}",
        parameters: {},
      );

      final productoEupeel = ProductoCosbiomeModel.fromJson(
        productoEupeelDB.data,
      );

      productoEupeelSelected = productoEupeel;

      int stockAVerificar = productoEupeel.general!;

      if (almacen == "salida") {
        stockAVerificar = productoEupeel.general!;
      }

      if (almacen == "enExpo") {
        stockAVerificar = productoEupeel.enExpo!;
      }

      final index = _productosVenta.indexWhere(
        (element) => element["producto"] == producto.nombreProducto,
      );

      if (index != -1) {
        final cantidadActual = int.parse(_productosVenta[index]["cantidad"]);
        stockAVerificar -= cantidadActual;
      }

      if (cantidad > stockAVerificar) {
        return false;
      } else {
        return true;
      }
    } catch (e) {
      return false;
    }
  }

  void handleRemoveProductoVenta({
    required Map<String, dynamic> producto,
  }) {
    final index = _productosVenta.indexWhere(
      (element) => element["producto"] == producto["producto"],
    );

    if (index != -1) {
      final productoVenta = _productosVenta[index];

      if (int.parse(productoVenta["cantidad"]) > 1) {
        _productosVenta[index]["cantidad"] =
            (int.parse(productoVenta["cantidad"]) - 1).toString();
      } else {
        _productosVenta.removeAt(index);
      }
    }

    handleCalculateTotalVenta();

    notifyListeners();
  }

  void handleCalculateTotalVenta() {
    subTotal = _productosVenta.fold(
      0,
      (previousValue, element) =>
          previousValue +
          (double.parse(element["precio"]) *
              int.parse(
                element["cantidad"],
              )),
    );

    total = subTotal;

    if (subTotal > 8000 && subTotal <= 14000) {
      descuento = metodoPago == "Tarjeta" ? 0.75 : 0.70;
      total = subTotal * descuento;
    } else if (subTotal > 14000) {
      descuento = metodoPago == "Tarjeta" ? 0.65 : 0.60;
      total = subTotal * descuento;
    } else {
      descuento = metodoPago == "Tarjeta" ? 0.85 : 0.80;
      total = subTotal * descuento;
    }
  }
}
