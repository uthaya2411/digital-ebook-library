import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../models/ebook.dart';

class ApiService {
  static String get baseUrl {
    // If Android emulator, redirect to host loopback IP 10.0.2.2
    if (!kIsWeb && Platform.isAndroid) {
      return 'http://10.0.2.2:3000/api';
    }
    // Fallback for iOS, macOS, Web, and desktop
    return 'http://localhost:3000/api';
  }

  // Get all ebooks (with optional search, sort, filter)
  static Future<List<Ebook>> fetchEbooks({
    String? query,
    String? sortBy,
    String? sortOrder,
    String? fileType,
  }) async {
    final Map<String, String> queryParameters = {};
    if (query != null && query.isNotEmpty) {
      queryParameters['q'] = query;
    }
    if (sortBy != null && sortBy.isNotEmpty) {
      queryParameters['sort_by'] = sortBy;
    }
    if (sortOrder != null && sortOrder.isNotEmpty) {
      queryParameters['sort_order'] = sortOrder;
    }
    if (fileType != null && fileType.isNotEmpty) {
      queryParameters['file_type'] = fileType;
    }

    final uri = Uri.parse('$baseUrl/ebooks').replace(queryParameters: queryParameters);
    
    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Ebook.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load ebooks: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: Failed to connect to server. Please check if Rails is running.');
    }
  }

  // Fetch single ebook details
  static Future<Ebook> fetchEbook(int id) async {
    final uri = Uri.parse('$baseUrl/ebooks/$id');
    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        return Ebook.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Ebook not found: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Upload ebook (supports bytes/paths for ebook file and optional cover image)
  static Future<Ebook> uploadEbook({
    required String name,
    required List<int> bytes,
    String? path,
    String? title,
    String? author,
    List<int>? coverBytes,
    String? coverPath,
    String? coverName,
  }) async {
    final uri = Uri.parse('$baseUrl/ebooks');
    
    try {
      final request = http.MultipartRequest('POST', uri);
      
      // Attach Ebook File
      if (!kIsWeb && path != null) {
        request.files.add(await http.MultipartFile.fromPath('file', path));
      } else {
        request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: name));
      }

      // Attach Ebook Cover Image (if provided)
      if (!kIsWeb && coverPath != null) {
        request.files.add(await http.MultipartFile.fromPath('cover', coverPath));
      } else if (coverBytes != null && coverBytes.isNotEmpty) {
        request.files.add(http.MultipartFile.fromBytes('cover', coverBytes, filename: coverName ?? 'cover.jpg'));
      }

      if (title != null && title.trim().isNotEmpty) {
        request.fields['title'] = title.trim();
      }
      if (author != null && author.trim().isNotEmpty) {
        request.fields['author'] = author.trim();
      }

      final streamedResponse = await request.send().timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 201) {
        return Ebook.fromJson(jsonDecode(response.body));
      } else {
        final Map<String, dynamic> errorBody = jsonDecode(response.body);
        final errors = errorBody['errors'] as List<dynamic>?;
        final errorMessage = errors?.join(', ') ?? 'Failed to upload ebook';
        throw Exception(errorMessage);
      }
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Network error during upload: $e');
    }
  }

  // Download ebook to local storage (returns path on local system, or URL on Web)
  static Future<String> downloadEbook(Ebook ebook, {Function(double progress)? onProgress}) async {
    if (kIsWeb) {
      // On web, just return the download url directly so browser can handle it
      return ebook.downloadUrl;
    }

    try {
      final client = http.Client();
      final request = http.Request('GET', Uri.parse(ebook.downloadUrl));
      final response = await client.send(request).timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        throw Exception('Download failed with status: ${response.statusCode}');
      }

      final contentLength = response.contentLength ?? 0;
      final List<int> bytes = [];
      int downloaded = 0;

      await for (var chunk in response.stream) {
        bytes.addAll(chunk);
        downloaded += chunk.length;
        if (contentLength > 0 && onProgress != null) {
          onProgress(downloaded / contentLength);
        }
      }

      // Save to device documents/downloads folder
      final directory = await getApplicationDocumentsDirectory();
      
      // Clean filename
      String safeName = ebook.fileName ?? '${ebook.title.replaceAll(RegExp(r'[^\w\s\-\.]'), '')}.pdf';
      if (!safeName.endsWith('.pdf') && !safeName.endsWith('.epub')) {
        safeName += '.pdf';
      }
      
      final filePath = '${directory.path}/$safeName';
      final file = File(filePath);
      await file.writeAsBytes(bytes);
      
      return filePath;
    } catch (e) {
      throw Exception('Failed to download ebook: $e');
    }
  }

  // Delete an ebook
  static Future<void> deleteEbook(int id) async {
    final uri = Uri.parse('$baseUrl/ebooks/$id');
    try {
      final response = await http.delete(uri).timeout(const Duration(seconds: 10));
      
      if (response.statusCode != 200) {
        final Map<String, dynamic> errorBody = jsonDecode(response.body);
        final errorMessage = errorBody['error'] ?? 'Failed to delete ebook';
        throw Exception(errorMessage);
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }
}
