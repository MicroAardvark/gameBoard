// lib/services/image_upload_service.dart
import 'dart:io';
import 'package:http/http.dart' as http;
import 'api_client.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http_parser/http_parser.dart';
import 'auth_service.dart';
import 'dart:convert';

class ImageUploadService {
  static const String baseUrl = 'https://microaardvark.co.uk/api/auth';
  
  /// Pick an image from gallery or camera
  static Future<File?> pickImage({bool fromCamera = false}) async {
    try {
      final ImagePicker picker = ImagePicker();
      
      final XFile? image = await picker.pickImage(
        source: fromCamera ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      
      if (image == null) {
        return null;
      }
      
      return File(image.path);
    } catch (e) {
      print('❌ Error picking image: $e');
      return null;
    }
  }
  
  /// Upload profile image to server
  static Future<Map<String, dynamic>> uploadProfileImage(File imageFile) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        return {'success': false, 'error': 'No authentication token found'};
      }
      
      // Create multipart request
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/upload-profile-image'),
      );
      
      // Add authorization header
      request.headers['Authorization'] = 'Bearer $token';
      
      // Add image file
      final imageStream = http.ByteStream(imageFile.openRead());
      final imageLength = await imageFile.length();
      
      final multipartFile = http.MultipartFile(
        'profileImage',
        imageStream,
        imageLength,
        filename: imageFile.path.split('/').last,
        contentType: MediaType('image', 'jpeg'), // Adjust based on file type
      );
      
      request.files.add(multipartFile);
      
      // Send request
      final streamedResponse = await apiClient.send(request);
      final response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('✅ Profile image uploaded successfully');
        return {
          'success': true,
          'user': data['user'],
          'message': data['message'],
        };
      } else {
        final error = jsonDecode(response.body);
        print('❌ Upload failed: ${error['error']}');
        return {
          'success': false,
          'error': error['error'] ?? 'Upload failed',
        };
      }
    } catch (e) {
      print('❌ Upload error: $e');
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }
  
  /// Delete profile image
  static Future<Map<String, dynamic>> deleteProfileImage() async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        return {'success': false, 'error': 'No authentication token found'};
      }
      
      final response = await apiClient.delete(
        Uri.parse('$baseUrl/delete-profile-image'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('✅ Profile image deleted successfully');
        return {
          'success': true,
          'user': data['user'],
          'message': data['message'],
        };
      } else {
        final error = jsonDecode(response.body);
        print('❌ Delete failed: ${error['error']}');
        return {
          'success': false,
          'error': error['error'] ?? 'Delete failed',
        };
      }
    } catch (e) {
      print('❌ Delete error: $e');
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }
}