import 'package:eupeel_expo/src/services/nfc_services.dart';
import 'package:flutter_riverpod/legacy.dart';

final nfcProvider = ChangeNotifierProvider<NFCServices>(
  (ref) {
    return NFCServices();
  },
);
