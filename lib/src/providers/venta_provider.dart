import 'package:eupeel_expo/src/services/venta_service.dart';
import 'package:flutter_riverpod/legacy.dart';

final ventaProvider = ChangeNotifierProvider<VentaService>(
  (ref) => VentaService(),
);
