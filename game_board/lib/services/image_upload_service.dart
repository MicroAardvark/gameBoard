// lib/services/image_upload_service.dart
//
// ImageUploadService — handles profile image selection and management.
//
// Responsibilities:
//   - Picking images from the device gallery or camera.
//   - Uploading profile images to the server as multipart/form-data.
//   - Deleting a user's current profile image.
//
// All upload/delete operations require a valid JWT token from [AuthService].
// Images are compressed on pick (max 1024×1024, 85% quality) to reduce
// bandwidth usage and storage costs.
//
// Base API endpoint: https://microaardvark.co.uk/api/auth

import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:http_parser/http_parser.dart';
import 'auth_service.dart';
import 'dart:convert';

class ImageUploadService {
  /// Base URL for profile image API endpoints.
  static const String baseUrl = 'https://microaardvark.co.uk/api/auth';

  // =============================
  // IMAGE PICKER
  // =============================

  /// Opens the image source (gallery or camera) and returns the selected file.
  ///
  /// Images are constrained to a maximum dimension of 1024×1024 pixels and
  /// compressed to 85% quality before being returned, reducing file size
  /// whilst maintaining acceptable visual fidelity for profile pictures.
  ///
  /// Parameters:
  ///   - [fromCamera]: If `true`, opens the device camera. Defaults to the
  ///     gallery when `false`.
  ///
  /// Returns the selected [File], or `null` if the user cancelled the picker
  /// or an error occurred.
  static Future<File?> pickImage({bool fromCamera = false}) async {
    try {
      final ImagePicker picker = ImagePicker();

      final XFile? image = await picker.pickImage(
        source: fromCamera ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      // User cancelled the picker — return null gracefully.
      if (image == null) {
        return null;
      }

      return File(image.path);
    } catch (e) {
      print('❌ Error picking image: $e');
      return null;
    }
  }

  // =============================
  // UPLOAD PROFILE IMAGE
  // =============================

  /// Uploads a profile image to the server using a multipart POST request.
  ///
  /// The image is sent as the 'profileImage' field in a multipart/form-data
  /// request. The server stores the image and updates the user's profile
  /// with the new image URL.
  ///
  /// Note: The content type is currently hardcoded to image/jpeg. If the
  /// application is extended to support PNG or other formats, this should
  /// be determined dynamically from the file extension.
  ///
  /// Parameters:
  ///   - [imageFile]: The local [File] to upload, typically returned by [pickImage].
  ///
  /// Returns:
  ///   - `success: true` with updated `user` data and `message` on HTTP 200.
  ///   - `success: false` with `error` on authentication failure or upload error.
  static Future<Map<String, dynamic>> uploadProfileImage(File imageFile) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        return {'success': false, 'error': 'No authentication token found'};
      }

      // Build a multipart POST request to the upload endpoint.
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/upload-profile-image'),
      );

      // Attach the JWT token for authenticated access.
      request.headers['Authorization'] = 'Bearer $token';

      // Read the image file as a byte stream and attach it to the request.
      final imageStream = http.ByteStream(imageFile.openRead());
      final imageLength = await imageFile.length();

      final multipartFile = http.MultipartFile(
        'profileImage', // Field name expected by the server.
        imageStream,
        imageLength,
        filename: imageFile.path.split('/').last,
        contentType: MediaType('image', 'jpeg'), // TODO: Detect type dynamically.
      );

      request.files.add(multipartFile);

      // Send the request and await the full response.
      final streamedResponse = await request.send();
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

  // =============================
  // DELETE PROFILE IMAGE
  // =============================

  /// Removes the authenticated user's profile image from the server.
  ///
  /// Sends a DELETE request to the profile image endpoint. The server removes
  /// the stored image file and clears the image URL from the user's profile.
  ///
  /// Returns:
  ///   - `success: true` with updated `user` data and `message` on HTTP 200.
  ///   - `success: false` with `error` on authentication failure or server error.
  static Future<Map<String, dynamic>> deleteProfileImage() async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        return {'success': false, 'error': 'No authentication token found'};
      }

      final response = await http.delete(
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