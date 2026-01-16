import 'package:eupeel_expo/src/models/producto_cosbiome_model.dart';
import 'package:eupeel_expo/src/utils/http_utils.dart';
import 'package:eupeel_expo/src/widgets/form_add_producto_widget.dart';
import 'package:flutter/material.dart';

class AlmacenService extends ChangeNotifier {
  String _scannedTextService = '';
  ProductoCosbiomeModel? _productoAlmacenModel;
  bool _enableScanning = true;

  String get scannedTextService => _scannedTextService;
  ProductoCosbiomeModel? get productoAlmacenModel => _productoAlmacenModel;
  bool get enableScanning => _enableScanning;

  set scannedTextService(String value) {
    _scannedTextService = value;
    notifyListeners();
  }

  set productoAlmacenModel(ProductoCosbiomeModel? value) {
    _productoAlmacenModel = value;
    notifyListeners();
  }

  set enableScanning(bool value) {
    _enableScanning = value;
    notifyListeners();
  }

  handleGetProductoConId(BuildContext context, String id, Size size) async {
    try {
      print("ID ENVIADO: $id");
      final productoDB = await Http.get(
        path: "cosbiomeproductos/$id",
        parameters: {},
      );

      productoAlmacenModel = ProductoCosbiomeModel.fromJson(
        productoDB.data,
      );

      enableScanning = false;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return FormAddProductoWidget(
            dialogContext: context,
          );
        },
      );
    } catch (e) {
      print(e);
    }
  }
}
