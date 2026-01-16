import 'package:eupeel_expo/src/services/almacen_service.dart';
import 'package:flutter_riverpod/legacy.dart';

final almacenProvider = ChangeNotifierProvider<AlmacenService>((ref) {
  return AlmacenService();
});
