// import 'package:eupeel_expo/src/models/producto_cosbiome_model.dart';
import 'dart:async';

import 'package:eupeel_expo/src/utils/nfc_writer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eupeel_expo/src/utils/nfc_reader.dart'; // Importa el lector

// import 'package:nfc_manager/nfc_manager.dart';
// import 'package:nfc_manager_ndef/nfc_manager_ndef.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  // --- CONTROLADORES Y SERVICIOS ---
  final TextEditingController _textController = TextEditingController();
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

  @override
  void dispose() {
    _loopTimer?.cancel();
    _reader.stopSession(); // Limpieza final
    super.dispose();
  }

  // ------------------------------------------------------------------------
  // LÓGICA DEL MODO AUTOMÁTICO (LOOP)
  // ------------------------------------------------------------------------

  void _toggleAutoLoop(bool value) {
    setState(() => _isAutoActive = value);

    if (_isAutoActive) {
      // 1. Abrimos sesión (Carga el driver de Windows una sola vez)
      _reader.startSession();

      // 2. Iniciamos el Timer (Cada 1 segundo)
      _loopTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        _processAutoLoop();
      });

      setState(() => _status = "Modo Automático: Buscando tarjeta...");
    } else {
      // Apagar todo
      _loopTimer?.cancel();
      _reader.stopSession();
      setState(() => _status = "Modo Manual");
    }
  }

  Future<void> _processAutoLoop() async {
    // Si estamos haciendo algo manual, o el sistema está ocupado, saltamos este ciclo
    if (_isLoading) return;

    if (_autoMode == "READ") {
      await _autoReadLogic();
    } else {
      await _autoWriteLogic();
    }
  }

  // Lógica: Leer Automáticamente
  Future<void> _autoReadLogic() async {
    // tryReadNdef ya maneja ping y reintentos internamente.
    // Retorna null si no hay tarjeta o falla.
    String? text = await _reader.tryReadNdef();

    if (text != null) {
      // ¡HAY TARJETA Y SE LEYÓ!
      if (!_cardAlreadyProcessed) {
        // Es una tarjeta nueva (o recién puesta)
        if (mounted) {
          setState(() {
            _readText = text;
            _status = "¡Lectura Auto Exitosa!";
            _cardAlreadyProcessed = true; // Marcamos para no volver a leerla
          });
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
      if (_cardAlreadyProcessed) {
        _cardAlreadyProcessed = false;
        if (mounted && _isAutoActive) {
          setState(() => _status = "Esperando siguiente tarjeta...");
        }
      }
    }
  }

  // Lógica: Escribir Automáticamente
  Future<void> _autoWriteLogic() async {
    if (_textController.text.isEmpty) {
      if (mounted)
        setState(() => _status = "¡Error: Escribe un texto para grabar!");
      return;
    }

    // tryWrite maneja ping y pausas internamente
    bool success = await _writer.tryWrite(_textController.text);

    if (success) {
      // ¡ESCRITURA EXITOSA!
      if (!_cardAlreadyProcessed) {
        if (mounted) {
          setState(() {
            _status = "¡GRABADO CORRECTO!";
            _cardAlreadyProcessed =
                true; // Marcamos para no volver a grabar la misma
          });
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
        if (mounted && _isAutoActive) {
          setState(() => _status = "Listo para grabar siguiente...");
        }
      }
    }
  }

  // ------------------------------------------------------------------------
  // LÓGICA MANUAL (BOTONES)
  // ------------------------------------------------------------------------

  Future<void> _manualRead() async {
    _tempPauseAuto(); // Pausar auto para evitar conflictos
    setState(() {
      _isLoading = true;
      _status = "Leyendo...";
    });

    try {
      String? text = await _reader.tryReadNdef();
      print("LECTURA MANUAL: $text");

      if (mounted) {
        if (text != null) {
          setState(() {
            _readText = text;
            _status = "Lectura Manual OK";
          });
        } else {
          setState(() => _status = "No se detectó tarjeta válida");
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
      _resumeAuto();
    }
  }

  Future<void> _manualWrite() async {
    if (_textController.text.isEmpty) return;

    _tempPauseAuto();
    setState(() {
      _isLoading = true;
      _status = "Escribiendo...";
    });

    try {
      bool success = await _writer.tryWrite(_textController.text);
      if (mounted) {
        setState(
          () => _status = success ? "¡Escritura OK!" : "Fallo al escribir",
        );
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
      if (mounted) setState(() => _isLoading = false);
      _resumeAuto();
    }
  }

  // Helpers para pausar el loop si tocas un botón manual
  void _tempPauseAuto() {
    if (_isAutoActive) _loopTimer?.cancel();
  }

  void _resumeAuto() {
    if (_isAutoActive) _toggleAutoLoop(true);
  }

  // ------------------------------------------------------------------------
  // INTERFAZ GRÁFICA
  // ------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("ACR122U Tool"),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          Row(
            children: [
              const Text(
                "Modo Auto",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Switch(
                value: _isAutoActive,
                onChanged: _toggleAutoLoop,
                activeColor: Colors.greenAccent,
                activeTrackColor: Colors.green.shade800,
              ),
              const SizedBox(width: 10),
            ],
          ),
        ],
      ),
      body: Container(
        padding: const EdgeInsets.all(20),
        color: Colors.grey.shade100,
        child: Column(
          children: [
            // 1. SELECTOR DE MODO (Solo visible si Auto está activo)
            if (_isAutoActive)
              Container(
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.blue),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Acción Automática:",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    DropdownButton<String>(
                      value: _autoMode,
                      items: const [
                        DropdownMenuItem(
                          value: "READ",
                          child: Text("LEER Tarjetas"),
                        ),
                        DropdownMenuItem(
                          value: "WRITE",
                          child: Text("GRABAR Tarjetas"),
                        ),
                      ],
                      onChanged: (val) {
                        setState(() {
                          _autoMode = val!;
                          _cardAlreadyProcessed =
                              false; // Reset para que actúe inmediato
                          _status = "Cambiando modo...";
                        });
                      },
                    ),
                  ],
                ),
              ),

            // 2. PANEL DE ESTADO
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: _isAutoActive
                    ? Colors.green.shade50
                    : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _isAutoActive ? Colors.green : Colors.grey,
                ),
              ),
              child: Text(
                _status,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _isAutoActive ? Colors.green.shade800 : Colors.black54,
                ),
              ),
            ),

            const SizedBox(height: 20),

            // 3. CAMPO DE TEXTO (Para escribir)
            TextField(
              controller: _textController,
              decoration: const InputDecoration(
                labelText: "Texto para Grabar (NTAG)",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.nfc),
                fillColor: Colors.white,
                filled: true,
              ),
            ),

            const SizedBox(height: 20),

            // 4. ÁREA DE RESULTADO DE LECTURA
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 5)],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      "CONTENIDO LEÍDO",
                      style: TextStyle(color: Colors.grey, letterSpacing: 1.5),
                    ),
                    const Divider(),
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      child: Text(
                        _readText,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.indigo,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // 5. BOTONES MANUALES (Se desactivan en modo Auto para evitar confusión, o puedes dejarlos)
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _manualRead,
                    icon: const Icon(Icons.download),
                    label: const Text("LEER (Manual)"),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      backgroundColor: Colors.blue.shade600,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _manualWrite,
                    icon: const Icon(Icons.upload),
                    label: const Text("GRABAR (Manual)"),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      backgroundColor: Colors.orange.shade600,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
