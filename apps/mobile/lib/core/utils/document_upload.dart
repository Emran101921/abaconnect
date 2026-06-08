import 'package:dio/dio.dart';

const documentUploadExtensions = ['pdf', 'png', 'jpg', 'jpeg'];

const allowedDocumentMimeTypes = {
  'application/pdf',
  'image/png',
  'image/jpeg',
};

String mimeFromExtension(String ext) {
  switch (ext.toLowerCase()) {
    case 'pdf':
      return 'application/pdf';
    case 'png':
      return 'image/png';
    case 'jpg':
    case 'jpeg':
      return 'image/jpeg';
    default:
      return 'application/octet-stream';
  }
}

String? validateDocumentUpload({
  required String? extension,
  required String mimeType,
}) {
  if (extension == null ||
      !documentUploadExtensions.contains(extension.toLowerCase())) {
    return 'Only PDF and image files (PNG, JPG) are allowed';
  }
  if (!allowedDocumentMimeTypes.contains(mimeType)) {
    return 'Invalid file type. PDF must be application/pdf';
  }
  return null;
}

String formatUploadError(Object error) {
  if (error is DioException) {
    final response = error.response;
    final data = response?.data;
    if (data is Map) {
      final message = data['message'];
      if (message is String && message.isNotEmpty) return message;
      if (message is List && message.isNotEmpty) {
        return message.map((e) => e.toString()).join(', ');
      }
    }
    if (response?.statusCode != null) {
      return 'Upload failed (${response!.statusCode})';
    }
    if (error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout) {
      return 'Cannot reach server. Check your connection.';
    }
  }
  return error.toString();
}
