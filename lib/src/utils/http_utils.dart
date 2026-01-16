import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:eupeel_expo/src/utils/preferences_uitils.dart';

class TypeAuth {
  const TypeAuth(this._auth);

  final Map<String, String> _auth;

  static const TypeAuth whitoutAuth = TypeAuth({
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  });

  static TypeAuth cosbiome = TypeAuth({
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'Authorization': 'Bearer ${PreferencesUtils.getString("jwtCosbiome")}',
  });
}

class TypeHost {
  const TypeHost(this._host, this._scheme);

  final String _host;
  final String _scheme;

  static const TypeHost cosbiome = TypeHost("cosbiome.online", "https");
}

class Http {
  static final Http _httpMod = Http._internal();
  factory Http() {
    return _httpMod;
  }
  Http._internal();

  static Future<Response> get({
    TypeAuth typeAuth = TypeAuth.whitoutAuth,
    TypeHost typeHost = TypeHost.cosbiome,
    required String path,
    required Map<String, dynamic> parameters,
  }) async {
    Uri url = Uri(
      host: typeHost._host,
      path: path,
      port: typeHost._scheme == "http" ? 3000 : 443,
      queryParameters: parameters,
      scheme: typeHost._scheme,
    );

    print("URL: ${url.toString()}");

    Response response = await Dio().get(
      url.toString(),
      options: Options(headers: typeAuth._auth),
    );

    return response;
  }

  static Future<Response> post({
    TypeAuth typeAuth = TypeAuth.whitoutAuth,
    TypeHost typeHost = TypeHost.cosbiome,
    required String path,
    required Map<String, dynamic> data,
    Map<String, dynamic>? parameters,
  }) async {
    Uri url = Uri(
      host: typeHost._host,
      path: path,
      port: typeHost._scheme == "http" ? 3000 : 443,
      queryParameters: parameters,
      scheme: typeHost._scheme,
    );
    print("URL: ${url.toString()}");
    Response response = await Dio().post(
      url.toString(),
      data: jsonEncode(data),
      options: Options(headers: typeAuth._auth),
    );

    return response;
  }

  static Future<Response> upload({
    TypeAuth typeAuth = TypeAuth.whitoutAuth,
    TypeHost typeHost = TypeHost.cosbiome,
    required String path,
    required FormData data,
  }) async {
    Uri url = Uri(
      host: typeHost._host,
      path: path,
      port: typeHost._scheme == "http" ? 3000 : 443,
      scheme: typeHost._scheme,
    );
    Response response = await Dio().post(
      url.toString(),
      data: data,
      options: Options(headers: typeAuth._auth),
    );

    return response;
  }

  static Future<Response> login({
    TypeAuth typeAuth = TypeAuth.whitoutAuth,
    TypeHost typeHost = TypeHost.cosbiome,
    required String path,
    required Map<String, dynamic> data,
  }) async {
    Uri url = Uri(
      host: typeHost._host,
      path: path,
      port: typeHost._scheme == "http" ? 3000 : 443,
      scheme: typeHost._scheme,
    );

    print("URL: ${url.toString()}");

    Response response = await Dio().post(
      url.toString(),
      data: jsonEncode(data),
      options: Options(headers: typeAuth._auth),
    );

    return response;
  }

  static Future<Response> update({
    TypeAuth typeAuth = TypeAuth.whitoutAuth,
    TypeHost typeHost = TypeHost.cosbiome,
    required String path,
    required Map<String, dynamic> data,
    Map<String, dynamic>? parameters,
  }) async {
    Uri url = Uri(
      host: typeHost._host,
      path: path,
      port: typeHost._scheme == "http" ? 3000 : 443,
      scheme: typeHost._scheme,
      queryParameters: parameters,
    );

    print("URL: ${url.toString()}");

    Response response = await Dio().put(
      url.toString(),
      data: jsonEncode(data),
      options: Options(headers: typeAuth._auth),
    );

    return response;
  }

  static Future<Response> delete({
    TypeAuth typeAuth = TypeAuth.whitoutAuth,
    TypeHost typeHost = TypeHost.cosbiome,
    required String path,
    required Map<String, dynamic> parameters,
  }) async {
    Uri url = Uri(
      host: typeHost._host,
      path: path,
      port: typeHost._scheme == "http" ? 3000 : 443,
      queryParameters: parameters,
      scheme: typeHost._scheme,
    );
    Response response = await Dio().delete(
      url.toString(),
      options: Options(headers: typeAuth._auth),
    );

    return response;
  }

  static Future<String> uploadFileToS3(FormData data) async {
    String host = 'https://cosbiomeescuela.s3.us-east-2.amazonaws.com/';

    await Dio().post(
      host,
      data: data,
      options: Options(headers: {'Content-Type': 'multipart/form-data'}),
    );

    return host + data.fields.first.value;
  }

  static getTokenRoom(String courseTitle) async {
    Uri url = Uri(
      host: "livekit.cosbiome.online",
      path: "/api/get-participant-token",
      queryParameters: {
        "room": courseTitle,
        "username": PreferencesUtils.getString("username"),
      },
      scheme: "https",
    );

    final responseDB = await Dio().get(
      url.toString(),
      options: Options(
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          "Access-Control-Allow-Origin": "*",
        },
      ),
    );

    return responseDB.data["token"];
  }
}
