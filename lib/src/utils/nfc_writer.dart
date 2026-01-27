import 'dart:convert';
import 'dart:async';
import 'windows_nfc_service.dart';

class NfcWriter {
  final _service = WindowsNfcService();

  Future<bool> tryWrite(String text) async {
    try {
      _service.initialize();
      _service.connectToReader();

      // 1. PING (Igual que el lector)
      try {
        await _getUid();
      } catch (e) {
        _service.disconnect();
        return false;
      }

      // 2. PREPARAR DATOS
      List<int> ndefData = _createNdefTextPayload(text);

      // 3. ESCRIBIR CON PAUSAS
      bool success = false;
      try {
        await _performWriteSequence(ndefData);
        success = true;
      } catch (e) {
        // Un solo reintento si falla
        await Future.delayed(const Duration(milliseconds: 100));
        try {
          await _performWriteSequence(ndefData);
          success = true;
        } catch (_) {}
      }

      _service.disconnect();
      return success;
    } catch (e) {
      try {
        _service.disconnect();
      } catch (_) {}
      return false;
    }
  }

  Future<void> _performWriteSequence(List<int> ndefData) async {
    int currentBlock = 4;
    List<int> dataToWrite = List.from(ndefData);
    while (dataToWrite.length % 4 != 0) dataToWrite.add(0x00);

    for (int i = 0; i < dataToWrite.length; i += 4) {
      List<int> pageData = dataToWrite.sublist(i, i + 4);
      List<int> apdu = [0xFF, 0xD6, 0x00, currentBlock, 0x04, ...pageData];

      List<int> response = _service.transmit(apdu);
      if (response.length < 2 || response[response.length - 2] != 0x90) {
        throw Exception("Error Write");
      }
      // Pausa necesaria para que la memoria se grabe
      await Future.delayed(const Duration(milliseconds: 20));
      currentBlock++;
    }
  }

  Future<void> _getUid() async {
    List<int> apdu = [0xFF, 0xCA, 0x00, 0x00, 0x00];
    List<int> res = _service.transmit(apdu);
    if (res.length < 2 || res[res.length - 2] != 0x90)
      throw Exception("Error UID");
  }

  List<int> _createNdefTextPayload(String text) {
    List<int> textBytes = utf8.encode(text);
    List<int> lang = utf8.encode("en");
    int payloadLen = 1 + lang.length + textBytes.length;
    List<int> record = [
      0xD1,
      0x01,
      payloadLen,
      0x54,
      lang.length,
      ...lang,
      ...textBytes,
    ];
    List<int> tlv = [0x03, record.length, ...record, 0xFE];
    return tlv;
  }
}
