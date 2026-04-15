// lib/job/resume_management_page.dart (Local Version - No Supabase Storage)
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';

class ResumeManagementPage extends StatefulWidget {
  const ResumeManagementPage({super.key});

  @override
  State<ResumeManagementPage> createState() => _ResumeManagementPageState();
}

class _ResumeManagementPageState extends State<ResumeManagementPage> {
  List<Map<String, dynamic>> _resumes = [];
  bool _isLoading = true;
  bool _isUploading = false;

  // Local storage directory for resumes
  String? _resumesDirPath;

  @override
  void initState() {
    super.initState();
    _initResumesDirectory();
  }

  Future<void> _initResumesDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    _resumesDirPath = '${appDir.path}/resumes';
    final dir = Directory(_resumesDirPath!);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    await _loadLocalResumes();
  }

  Future<void> _loadLocalResumes() async {
    setState(() => _isLoading = true);
    try {
      if (_resumesDirPath == null) return;

      final dir = Directory(_resumesDirPath!);
      if (!await dir.exists()) {
        setState(() => _resumes = []);
        return;
      }

      final files = await dir.list().toList();
      final resumeList = <Map<String, dynamic>>[];

      for (final file in files) {
        if (file is File && (file.path.endsWith('.pdf') || file.path.endsWith('.docx') || file.path.endsWith('.doc'))) {
          final stat = await file.stat();
          resumeList.add({
            'path': file.path,
            'name': file.path.split('/').last,
            'size': stat.size,
            'created': stat.modified,
          });
        }
      }

      // Sort by creation date (newest first)
      resumeList.sort((a, b) => b['created'].compareTo(a['created']));
      setState(() => _resumes = resumeList);
    } catch (e) {
      debugPrint('Error loading resumes: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _uploadResume() async {
    FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx'],
    );

    if (result != null && result.files.single.path != null) {
      setState(() => _isUploading = true);

      try {
        final sourceFile = File(result.files.single.path!);
        final fileName = result.files.single.name;

        // Copy to app's local directory
        final destPath = '$_resumesDirPath/$fileName';
        final destFile = File(destPath);

        // Handle duplicate filenames
        if (await destFile.exists()) {
          final nameWithoutExt = fileName.split('.').first;
          final ext = fileName.split('.').last;
          final newName = '${nameWithoutExt}_${DateTime.now().millisecondsSinceEpoch}.$ext';
          final newDestPath = '$_resumesDirPath/$newName';
          await sourceFile.copy(newDestPath);
        } else {
          await sourceFile.copy(destPath);
        }

        await _loadLocalResumes();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Resume uploaded successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error uploading resume: $e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isUploading = false);
        }
      }
    }
  }

  Future<void> _deleteResume(Map<String, dynamic> resume) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Resume'),
        content: Text('Are you sure you want to delete "${resume['name']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      try {
        final file = File(resume['path']);
        if (await file.exists()) {
          await file.delete();
        }
        await _loadLocalResumes();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Resume deleted'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  Future<void> _viewResume(String path, String fileName) async {
    try {
      final result = await OpenFile.open(path);
      if (result.type != ResultType.done) {
        throw Exception('Could not open file');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open file: $e')),
        );
      }
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Resumes'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.upload),
            onPressed: _isUploading ? null : _uploadResume,
            tooltip: 'Upload Resume',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _resumes.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _resumes.length,
        itemBuilder: (ctx, index) {
          final resume = _resumes[index];
          final isPdf = resume['name'].toString().toLowerCase().endsWith('.pdf');

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isPdf ? Colors.red.shade50 : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isPdf ? Icons.picture_as_pdf : Icons.description,
                  color: isPdf ? Colors.red.shade600 : Colors.blue.shade600,
                  size: 28,
                ),
              ),
              title: Text(
                resume['name'] ?? 'Resume',
                style: const TextStyle(fontWeight: FontWeight.w500),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                '${_formatFileSize(resume['size'])} • Uploaded: ${_formatDate(resume['created'])}',
                style: const TextStyle(fontSize: 12),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.visibility, color: Colors.blue),
                    onPressed: () => _viewResume(
                      resume['path'],
                      resume['name'] ?? 'Resume',
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => _deleteResume(resume),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isUploading ? null : _uploadResume,
        backgroundColor: Colors.blue,
        child: _isUploading
            ? const CircularProgressIndicator(color: Colors.white)
            : const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.description_outlined, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text(
            'No resumes uploaded yet',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the + button to upload your resume (PDF, DOC, DOCX)',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}