import 'dart:convert';
import 'dart:async'; // Asegúrate de importar esto para Future.delayed
import 'windows_nfc_service.dart';

class NfcReader {
  final _service = WindowsNfcService();

  void startSession() => _service.initialize();
  void stopSession() => _service.dispose();

  /// Intenta leer de forma segura y silenciosa
  Future<String?> tryReadNdef() async {
    try {
      // --- CORRECCIÓN AQUÍ ---
      // Aseguramos que el driver esté iniciado antes de conectar.
      // Si ya estaba iniciado (por el modo auto), esto no hace nada (es seguro).
      _service.initialize();
      // -----------------------

      _service.connectToReader();

      // 1. PING DE ESTABILIZACIÓN (Obtener UID)
      try {
        await _getUid();
      } catch (e) {
        _service.disconnect();
        return null;
      }

      // 2. LECTURA CON REINTENTOS
      List<int> rawData = [];
      bool readSuccess = false;

      for (int attempt = 0; attempt < 3; attempt++) {
        try {
          rawData = _readUserMemory(); // Lee bloques 4-20
          readSuccess = true;
          break;
        } catch (e) {
          await Future.delayed(const Duration(milliseconds: 6000));
        }
      }

      _service.disconnect();

      if (readSuccess) {
        return _parseNdefData(rawData);
      } else {
        return null;
      }
    } catch (e) {
      try {
        _service.disconnect();
      } catch (_) {}
      return null;
    }
  }

  // ... El resto de tus métodos (_getUid, _readUserMemory, _parseNdefData) siguen igual ...
  // Solo asegúrate de copiar el resto del archivo que ya tenías abajo.

  Future<List<int>> _getUid() async {
    List<int> apdu = [0xFF, 0xCA, 0x00, 0x00, 0x00];
    List<int> response = _service.transmit(apdu);
    if (response.length < 2 || response[response.length - 2] != 0x90) {
      throw Exception("Error UID");
    }
    return response;
  }

  List<int> _readUserMemory() {
    List<int> data = [];
    for (int block = 4; block < 20; block++) {
      List<int> apdu = [0xFF, 0xB0, 0x00, block, 0x04];
      List<int> response = _service.transmit(apdu);

      if (response.length >= 2 && response[response.length - 2] == 0x90) {
        data.addAll(response.sublist(0, response.length - 2));
        if (response.contains(0xFE)) break;
      } else {
        throw Exception("Fallo bloque $block");
      }
    }
    return data;
  }

  String _parseNdefData(List<int> data) {
    int startIndex = data.indexOf(0x03);
    if (startIndex == -1) return "No es NDEF (Sin Tag 0x03)";
    if (startIndex + 1 >= data.length) return "Datos incompletos";
    int len = data[startIndex + 1];

    if (startIndex + 2 + len > data.length) return "Lectura parcial...";

    List<int> record = data.sublist(startIndex + 2, startIndex + 2 + len);

    try {
      int payloadLen = record[2];
      int typeLen = record[1];
      int payloadStart = 3 + typeLen;
      int status = record[payloadStart];
      int langLen = status & 0x1F;
      int textStart = payloadStart + 1 + langLen;

      return utf8.decode(record.sublist(textStart));
    } catch (e) {
      return "Formato complejo o vacío";
    }
  }
}
