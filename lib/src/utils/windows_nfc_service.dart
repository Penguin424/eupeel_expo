import 'dart:ffi';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

// --- CONSTANTES CRÍTICAS ---
const int SCARD_S_SUCCESS = 0;
const int SCARD_SCOPE_USER = 0;
const int SCARD_SHARE_SHARED = 2;
const int SCARD_PROTOCOL_T0 = 1;
const int SCARD_PROTOCOL_T1 = 2;
const int SCARD_LEAVE_CARD = 0;
const int SCARD_RESET_CARD = 1;
const int SCARD_UNPOWER_CARD = 2; // <--- CRUCIAL PARA ACR122U

class WindowsNfcService {
  int _context = 0;
  int _card = 0;
  int _protocol = 0;

  void initialize() {
    if (_context != 0) return; // Evitar doble inicialización

    final phContext = calloc<IntPtr>();
    try {
      final result = SCardEstablishContext(
        SCARD_SCOPE_USER,
        nullptr,
        nullptr,
        phContext,
      );
      if (result != SCARD_S_SUCCESS) {
        // Ignoramos error si ya existe, pero lanzamos si es fatal
        if (result != 0x8010001D) throw Exception('Error contexto: $result');
      }
      _context = phContext.value;
    } finally {
      calloc.free(phContext);
    }
  }

  void dispose() {
    disconnect();
    if (_context != 0) {
      SCardReleaseContext(_context);
      _context = 0;
    }
  }

  void connectToReader() {
    // Busca el primer lector disponible
    final pcbReaders = calloc<Uint32>();
    var result = SCardListReaders(_context, nullptr, nullptr, pcbReaders);
    if (result != SCARD_S_SUCCESS) throw Exception('Sin lectores (Fase 1)');

    final mszReaders = calloc<Uint16>(pcbReaders.value);
    try {
      result = SCardListReaders(
        _context,
        nullptr,
        mszReaders.cast<Utf16>(),
        pcbReaders,
      );
      if (result != SCARD_S_SUCCESS) throw Exception('Sin lectores (Fase 2)');

      final readersData = mszReaders.cast<Utf16>().toDartString();
      final readers = readersData
          .split('\u0000')
          .where((s) => s.isNotEmpty)
          .toList();
      if (readers.isEmpty) throw Exception('Lista vacía');

      final readerName = readers.first;
      final readerNamePtr = readerName.toNativeUtf16();
      final phCard = calloc<IntPtr>();
      final pdwActiveProtocol = calloc<Uint32>();

      try {
        result = SCardConnect(
          _context,
          readerNamePtr,
          SCARD_SHARE_SHARED,
          SCARD_PROTOCOL_T0 | SCARD_PROTOCOL_T1,
          phCard,
          pdwActiveProtocol,
        );
        if (result != SCARD_S_SUCCESS)
          throw Exception('No se pudo conectar (¿Tarjeta ausente?)');

        _card = phCard.value;
        _protocol = pdwActiveProtocol.value;
      } finally {
        calloc.free(readerNamePtr);
        calloc.free(phCard);
        calloc.free(pdwActiveProtocol);
      }
    } finally {
      calloc.free(pcbReaders);
      calloc.free(mszReaders);
    }
  }

  List<int> transmit(List<int> commandApdu) {
    if (_card == 0) throw Exception("No conectado");

    final sendBuffer = calloc<Uint8>(commandApdu.length);
    final recvBuffer = calloc<Uint8>(256);
    final recvLength = calloc<Uint32>()..value = 256;

    final pioSendPci = calloc<SCARD_IO_REQUEST>();
    pioSendPci.ref.dwProtocol = _protocol;
    pioSendPci.ref.cbPciLength = sizeOf<SCARD_IO_REQUEST>();

    try {
      for (int i = 0; i < commandApdu.length; i++)
        sendBuffer[i] = commandApdu[i];

      final result = SCardTransmit(
        _card,
        pioSendPci,
        sendBuffer,
        commandApdu.length,
        nullptr,
        recvBuffer,
        recvLength,
      );

      if (result != SCARD_S_SUCCESS) throw Exception('Error Transmit: $result');

      return List.generate(recvLength.value, (i) => recvBuffer[i]);
    } finally {
      calloc.free(sendBuffer);
      calloc.free(recvBuffer);
      calloc.free(recvLength);
      calloc.free(pioSendPci);
    }
  }

  void disconnect() {
    if (_card != 0) {
      // USAR UNPOWER (2) ES LA CLAVE PARA EL MODO BUCLE
      SCardDisconnect(_card, SCARD_UNPOWER_CARD);
      _card = 0;
    }
  }
}
