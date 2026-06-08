import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class CloudinaryService {
  final String _cloudName = "dokiv8dpg";
  final String _uploadPreset = "pfe_flutter";

  Future<String?> uploadFile(File file) async {
    final url = Uri.parse("https://api.cloudinary.com/v1_1/$_cloudName/image/upload");
    try {
      final request = http.MultipartRequest("POST", url)
        ..fields['upload_preset'] = _uploadPreset
        ..files.add(await http.MultipartFile.fromPath('file', file.path));
      return await _handleResponse(request);
    } catch (e) {
      debugPrint("Erreur Cloudinary File: $e");
      return null;
    }
  }

  Future<String?> uploadBytes(Uint8List bytes, String fileName) async {
    final url = Uri.parse("https://api.cloudinary.com/v1_1/$_cloudName/image/upload");
    try {
      final request = http.MultipartRequest("POST", url)
        ..fields['upload_preset'] = _uploadPreset
        ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: fileName));
      return await _handleResponse(request);
    } catch (e) {
      debugPrint("Erreur Cloudinary Bytes: $e");
      return null;
    }
  }

  Future<String?> _handleResponse(http.MultipartRequest request) async {
    final response = await request.send();
    final responseData = await response.stream.toBytes();
    final responseString = utf8.decode(responseData);
    if (response.statusCode == 200) {
      final jsonMap = jsonDecode(responseString);
      return jsonMap['secure_url'] as String;
    } else {
      debugPrint("Erreur Cloudinary ${response.statusCode}: $responseString");
      return null;
    }
  }
}