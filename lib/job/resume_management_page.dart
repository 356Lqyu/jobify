// lib/job/resume_management_page.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

class ResumeManagementPage extends StatefulWidget {
  const ResumeManagementPage({super.key});

  @override
  State<ResumeManagementPage> createState() => _ResumeManagementPageState();
}

class _ResumeManagementPageState extends State<ResumeManagementPage> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _resumes = [];
  bool _isLoading = true;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _loadResumes();
  }

  Future<void> _loadResumes() async {
    setState(() => _isLoading = true);
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      final response = await supabase
          .from('resume')
          .select()
          .eq('user_id', userId)
          .order('uploaded_at', ascending: false);

      setState(() {
        _resumes = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading resumes: $e')),
        );
      }
    }
  }

  Future<void> _viewResume(String url, String fileName) async {
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/$fileName');
        await file.writeAsBytes(response.bodyBytes);

        if (mounted) Navigator.pop(context);
        await OpenFile.open(file.path);
      } else {
        if (mounted) Navigator.pop(context);
        throw Exception('Failed to download resume');
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening resume: $e')),
        );
      }
    }
  }

  Future<void> _deleteResume(Map<String, dynamic> resume) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Resume'),
        content: Text('Are you sure you want to delete "${resume['file_name']}"?'),
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
        // Delete from storage
        final url = resume['file_url'] as String;
        final path = url.split('/resumes/').last;
        await supabase.storage.from('resumes').remove([path]);

        // Delete from database
        await supabase
            .from('resume')
            .delete()
            .eq('resume_id', resume['resume_id']);

        await _loadResumes();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Resume deleted'), backgroundColor: Colors.orange),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Resumes'),
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _resumes.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
        onRefresh: _loadResumes,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _resumes.length,
          itemBuilder: (ctx, index) {
            final resume = _resumes[index];
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
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.picture_as_pdf,
                    color: Colors.red.shade600,
                    size: 28,
                  ),
                ),
                title: Text(
                  resume['file_name'],
                  style: const TextStyle(fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  'Uploaded: ${_formatDate(resume['uploaded_at'])}',
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.visibility, color: Color(0xFF2563EB)),
                      onPressed: () => _viewResume(resume['file_url'], resume['file_name']),
                      tooltip: 'View Resume',
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => _deleteResume(resume),
                      tooltip: 'Delete Resume',
                    ),
                  ],
                ),
              ),
            );
          },
        ),
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
            'Upload your resume from your profile page',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'Unknown';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return 'Unknown';
    }
  }
}