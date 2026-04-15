// lib/job/local_resume_service.dart
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LocalResumeService {
  final SupabaseClient _sb = Supabase.instance.client;

  // For development: Use local asset resumes
  static const List<Map<String, String>> _localResumes = [
    {
      'name': 'Software_Engineer_Resume.pdf',
      'asset': 'assets/resumes/software_engineer_resume.pdf',
      'description': 'Software Engineer with 3 years experience',
    },
    {
      'name': 'Frontend_Developer_Resume.pdf',
      'asset': 'assets/resumes/frontend_developer_resume.pdf',
      'description': 'React/Flutter specialist',
    },
    {
      'name': 'Data_Scientist_Resume.docx',
      'asset': 'assets/resumes/data_scientist_resume.docx',
      'description': 'ML and data analysis expert',
    },
    {
      'name': 'Product_Manager_Resume.pdf',
      'asset': 'assets/resumes/product_manager_resume.pdf',
      'description': 'Agile product management',
    },
  ];

  // Get list of available local resumes
  static List<Map<String, String>> getAvailableResumes() {
    return _localResumes;
  }

  // Load resume file from assets
  static Future<ByteData?> loadResumeFromAssets(String assetPath) async {
    try {
      return await rootBundle.load(assetPath);
    } catch (e) {
      debugPrint('Error loading resume from assets: $e');
      return null;
    }
  }

  // Copy asset resume to temporary file for viewing
  static Future<File?> copyResumeToTempFile(String assetPath, String fileName) async {
    try {
      final byteData = await rootBundle.load(assetPath);
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/$fileName');
      await tempFile.writeAsBytes(byteData.buffer.asUint8List());
      return tempFile;
    } catch (e) {
      debugPrint('Error copying resume to temp: $e');
      return null;
    }
  }

  // For actual upload to Supabase (if needed later)
  Future<String?> uploadResumeToSupabase({
    required String userId,
    required String filePath,
    required String fileName,
  }) async {
    try {
      final file = File(filePath);
      final bytes = await file.readAsBytes();
      final storagePath = 'resumes/$userId/${DateTime.now().millisecondsSinceEpoch}_$fileName';

      await _sb.storage.from('resumes').uploadBinary(
        storagePath,
        bytes,
        fileOptions: const FileOptions(cacheControl: '3600'),
      );

      return _sb.storage.from('resumes').getPublicUrl(storagePath);
    } catch (e) {
      debugPrint('Error uploading resume: $e');
      return null;
    }
  }
}