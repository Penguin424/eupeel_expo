import 'dart:async';

import 'package:eupeel_expo/src/utils/nfc_reader.dart';
import 'package:eupeel_expo/src/utils/nfc_writer.dart';
import 'package:flutter/material.dart';

class NFCServices extends ChangeNotifier {
  String _textToWrite = "";
  final NfcReader _reader = NfcReader();
  final NfcWriter _writer = NfcWriter();

  // --- ESTADOS DE LA UI ---
  String _status = "Listo. Selecciona un modo.";
  String _readText = "---";
  bool _isLoading = false; // Bloquea UI durante operaciones manuales

  // --- ESTADOS DE AUTOMATIZACIÓN ---
  bool _isAutoActive = false; // Switch General
  String _autoMode = "READ"; // "READ" o "WRITE"
  Timer? _loopTimer;
  bool _cardAlreadyProcessed =
      false; // Evita leer/escribir la misma tarjeta infinitamente

  int _isReadTextPushTag = 0;

  // --- GETTERS ---

  String get textToWrite => _textToWrite;
  String get status => _status;
  String get readText => _readText;
  bool get isLoading => _isLoading;
  bool get isAutoActive => _isAutoActive;
  String get autoMode => _autoMode;
  Timer? get loopTimer => _loopTimer;
  bool get cardAlreadyProcessed => _cardAlreadyProcessed;
  int get isReadTextPushTag => _isReadTextPushTag;

  // --- SETTERS ---

  set textToWrite(String value) {
    _textToWrite = value;
    notifyListeners();
  }

  set status(String value) {
    _status = value;
    notifyListeners();
  }

  set readText(String value) {
    _readText = value;
    notifyListeners();
  }

  set isLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  set isAutoActive(bool value) {
    _isAutoActive = value;
    notifyListeners();
  }

  set autoMode(String value) {
    _autoMode = value;
    notifyListeners();
  }

  set loopTimer(Timer? value) {
    _loopTimer = value;
    notifyListeners();
  }

  set cardAlreadyProcessed(bool value) {
    _cardAlreadyProcessed = value;
    notifyListeners();
  }

  set isReadTextPushTag(int value) {
    _isReadTextPushTag = value;
    notifyListeners();
  }

  void toggleAutoLoop(BuildContext context, bool value) {
    isAutoActive = value;

    if (_isAutoActive) {
      // 1. Abrimos sesión (Carga el driver de Windows una sola vez)
      _reader.startSession();

      // 2. Iniciamos el Timer (Cada 1 segundo)
      loopTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        processAutoLoop(context);
      });

      status = "Modo Automático: Buscando tarjeta...";
    } else {
      // Apagar todo
      loopTimer?.cancel();
      _reader.stopSession();
      status = "Modo Manual";
    }
  }

  Future<void> processAutoLoop(BuildContext context) async {
    // Si estamos haciendo algo manual, o el sistema está ocupado, saltamos este ciclo
    if (isLoading) return;

    if (autoMode == "READ") {
      await autoReadLogic(context);
    } else {
      await autoWriteLogic(context);
    }
  }

  // Lógica: Leer Automáticamente
  Future<void> autoReadLogic(BuildContext context) async {
    // tryReadNdef ya maneja ping y reintentos internamente.
    // Retorna null si no hay tarjeta o falla.
    String? text = await _reader.tryReadNdef();

    if (text != null) {
      // ¡HAY TARJETA Y SE LEYÓ!
      if (!_cardAlreadyProcessed) {
        // Es una tarjeta nueva (o recién puesta)
        if (context.mounted) {
          readText = text;

          status = "¡Lectura Auto Exitosa!";
          cardAlreadyProcessed = true; // Marcamos para no volver a leerla
          // Feedback visual rápido
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Tarjeta leída"),
              duration: Duration(milliseconds: 500),
              backgroundColor: Colors.blue,
            ),
          );
        }
      }
    } else {
      // NO HAY TARJETA (O se quitó)
      // Solo cuando la tarjeta se quita, reseteamos el flag para permitir la siguiente
      if (cardAlreadyProcessed) {
        cardAlreadyProcessed = false;
        if (context.mounted && isAutoActive) {
          status = "Esperando siguiente tarjeta...";
        }
      }
    }
  }

  // Lógica: Escribir Automáticamente
  Future<void> autoWriteLogic(BuildContext context) async {
    if (textToWrite.isEmpty) {
      if (context.mounted) status = "¡Error: Escribe un texto para grabar!";
      return;
    }

    // tryWrite maneja ping y pausas internamente
    bool success = await _writer.tryWrite(textToWrite);

    if (success) {
      // ¡ESCRITURA EXITOSA!
      if (!_cardAlreadyProcessed) {
        if (context.mounted) {
          status = "¡GRABADO CORRECTO!";
          cardAlreadyProcessed =
              true; // Marcamos para no volver a grabar la misma

          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Grabado OK"),
              duration: Duration(milliseconds: 500),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } else {
      // NO HAY TARJETA
      if (_cardAlreadyProcessed) {
        _cardAlreadyProcessed = false;
        if (context.mounted && _isAutoActive) {
          status = "Listo para grabar siguiente...";
        }
      }
    }
  }

  // ------------------------------------------------------------------------
  // LÓGICA MANUAL (BOTONES)
  // ------------------------------------------------------------------------

  Future<void> manualRead(BuildContext context) async {
    tempPauseAuto(); // Pausar auto para evitar conflictos
    isLoading = true;
    status = "Leyendo...";

    try {
      String? text = await _reader.tryReadNdef();
      print("LECTURA MANUAL: $text");

      if (context.mounted) {
        if (text != null) {
          readText = text;
          status = "Lectura Manual OK";
        } else {
          status = "No se detectó tarjeta válida";
        }
      }
    } finally {
      if (context.mounted) isLoading = false;
      resumeAuto(context);
    }
  }

  Future<void> manualWrite(BuildContext context) async {
    if (textToWrite.isEmpty) return;

    tempPauseAuto();
    isLoading = true;
    status = "Escribiendo...";

    try {
      bool success = await _writer.tryWrite(textToWrite);
      if (context.mounted) {
        status = success ? "¡Escritura OK!" : "Fallo al escribir";
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Escritura Exitosa"),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } finally {
      if (context.mounted) isLoading = false;
      resumeAuto(context);
    }
  }

  // Helpers para pausar el loop si tocas un botón manual
  void tempPauseAuto() {
    if (isAutoActive) _loopTimer?.cancel();
  }

  void resumeAuto(BuildContext context) {
    if (isAutoActive) toggleAutoLoop(context, true);
  }
}
