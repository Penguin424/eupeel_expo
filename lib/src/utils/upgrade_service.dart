import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

class UpgradeService {
  static const String _token = "Cosbiome-2026";
  static const String _url =
      "https://openfaas.cosbiome.online/function/get-version-eupeel-expo";

  // Función principal de validación
  Future<void> checkForUpdatesWindows(
    Function(String, String) onUpdateFound,
  ) async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      print("Versión actual: $currentVersion. Buscando actualizaciones...");

      final response = await Dio().get(
        _url,
        options: Options(headers: {'x-api-key': _token}),
      );

      if (response.statusCode == 200) {
        final latestVersion = response.data.replaceAll('v', '');

        // Comparamos versiones (puedes usar el paquete 'pub_semver' para más precisión)
        if (latestVersion != currentVersion) {
          // Buscamos el ID del asset .msix

          onUpdateFound(
            latestVersion,
            "ID_DEL_ASSET_MSIX",
          ); // Reemplaza con el ID real del asset
        }
      }
    } catch (e) {
      print("Error buscando actualizaciones: $e");
    }
  }

  // Función para descargar e instalar
  Future<void> downloadAndInstallWindows(String assetId) async {
    final tempDir = await getTemporaryDirectory();
    final path = "${tempDir.path}/update.msix";

    await Dio().download(
      "https://openfaas.cosbiome.online/function/get-github-releases-eupeel-expo",
      path,
      options: Options(
        headers: {
          'x-api-key': _token,
          'Accept': 'application/octet-stream',
        },
      ),
    );

    // 1. Ejecutar el archivo directamente usando cmd
    // El par de comillas vacías '' es un hack necesario de Windows para el título de la ventana
    await Process.run('cmd', ['/c', 'start', '', path]);

    // 2. Darle a Windows un pequeño margen para lanzar el App Installer antes de matar la app
    await Future.delayed(const Duration(milliseconds: 500));

    // 3. Cerrar la app de Flutter
    exit(0); // Cerramos la app para que Windows pueda actualizarla
  }
}
