import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:jobify/social/post_feed_setting.dart';
import 'package:jobify/social/social_feed_provider.dart';
import 'package:jobify/data/feed_repository.dart';

class SocialPostBottomSheet extends StatefulWidget {
  final String userId;
  final String? companyId;
  final String authorName;
  final String? authorAvatarUrl;

  const SocialPostBottomSheet({
    super.key,
    required this.userId,
    this.companyId,
    required this.authorName,
    this.authorAvatarUrl,
  });

  @override
  State<SocialPostBottomSheet> createState() => _SocialPostBottomSheetState();
}

class _SocialPostBottomSheetState extends State<SocialPostBottomSheet> {
  final _contentCtrl  = TextEditingController();
  final _hashtagCtrl  = TextEditingController();
  final _picker       = ImagePicker();
  final _uuid         = const Uuid();

  PostType _selectedType  = PostType.post;
  final List<String> _hashtags  = [];
  final List<File>   _imageFiles = [];
  bool _isPosting = false;

  static const _allowedTypes = [
    PostType.post, PostType.tip, PostType.event, PostType.news,
  ];

  @override
  void dispose() {
    _contentCtrl.dispose();
    _hashtagCtrl.dispose();
    super.dispose();
  }

  // ── Image picker ──────────────────────────────────────────────────────────

  Future<void> _pickImages() async {
    final List<XFile> picked = await _picker.pickMultiImage(
      imageQuality: 80,
    );
    if (picked.isEmpty) return;

    // Validate extensions: only png, jpg, jpeg
    final valid = picked.where((f) {
      final ext = f.name.split('.').last.toLowerCase();
      return ['png', 'jpg', 'jpeg'].contains(ext);
    }).toList();

    if (valid.length < picked.length) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Only PNG, JPG, JPEG images are allowed.'),
          backgroundColor: Color(0xFFF59E0B),
        ));
      }
    }

    if (mounted) {
      setState(() {
        for (final xf in valid) {
          if (_imageFiles.length < 4) {
            _imageFiles.add(File(xf.path));
          }
        }
      });
    }
  }

  // ── Hashtag helpers ───────────────────────────────────────────────────────

  void _addHashtag() {
    final tag = _hashtagCtrl.text.trim().replaceAll('#', '');
    if (tag.isNotEmpty && !_hashtags.contains(tag) && _hashtags.length < 10) {
      setState(() => _hashtags.add(tag));
      _hashtagCtrl.clear();
    }
  }

  void _parseInlineHashtags(String text) {
    final words = text.split(RegExp(r'\s+'));
    for (final w in words) {
      if (w.startsWith('#') && w.length > 1) {
        final tag = w.substring(1).replaceAll(RegExp(r'[^\w]'), '');
        if (tag.isNotEmpty && !_hashtags.contains(tag) && _hashtags.length < 10) {
          setState(() => _hashtags.add(tag));
        }
      }
    }
  }

  // ── Submit ────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    final content = _contentCtrl.text.trim();
    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Post content cannot be empty.')),
      );
      return;
    }
    setState(() => _isPosting = true);

    try {
      // 1. Upload images → get public URLs
      final repo      = FeedRepository();
      final mediaUrls = <String>[];

      for (final file in _imageFiles) {
        final bytes    = await file.readAsBytes();
        final ext      = file.path.split('.').last.toLowerCase();
        final fileName = 'posts/${widget.userId}_${_uuid.v4()}.$ext';

        final url = await repo.uploadImage(
          bucket:    'post_media',
          fileName:  fileName,
          fileBytes: bytes,
        );
        mediaUrls.add(url);
      }

      // 2. Create post via provider
      final provider = context.read<SocialFeedProvider>();
      final post = await provider.createPost(
        content:   content,
        postType:  _selectedType,
        hashtags:  _hashtags,
        mediaUrls: mediaUrls,
        companyId: widget.companyId,
      );

      if (!mounted) return;
      if (post != null) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Post published!'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to publish post. Please try again.'),
            backgroundColor: Color(0xFFEF4444),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: const Color(0xFFEF4444)),
        );
      }
    } finally {
      if (mounted) setState(() => _isPosting = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).viewInsets.bottom;

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      maxChildSize:     0.96,
      minChildSize:     0.5,
      expand: false,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // ── Handle & header ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                children: [
                  Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text('Create Post',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      ElevatedButton(
                        onPressed: _isPosting ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20)),
                          elevation: 0,
                        ),
                        child: _isPosting
                            ? const SizedBox(width: 16, height: 16,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                            : const Text('Publish',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 16),

            // ── Scrollable body ──────────────────────────────────────────
            Expanded(
              child: ListView(
                controller: scrollCtrl,
                padding: EdgeInsets.fromLTRB(16, 0, 16, bottomPad + 24),
                children: [
                  // Author row
                  Row(
                    children: [
                      _Avatar(name: widget.authorName, url: widget.authorAvatarUrl, radius: 20),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.authorName,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          const Text('Public · Everyone',
                              style: TextStyle(color: Colors.blueGrey, fontSize: 11)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // ── Post type chips ──────────────────────────────────
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _allowedTypes.map((t) {
                        final sel = _selectedType == t;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedType = t),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: sel ? t.color : t.color.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: sel ? t.color : t.color.withOpacity(0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(t.icon, size: 13,
                                    color: sel ? Colors.white : t.color),
                                const SizedBox(width: 5),
                                Text(t.label,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: sel ? Colors.white : t.color,
                                    )),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ── Content input ────────────────────────────────────
                  TextField(
                    controller: _contentCtrl,
                    maxLines: 6,
                    onChanged: _parseInlineHashtags,
                    decoration: InputDecoration(
                      hintText: 'What do you want to share?',
                      hintStyle: const TextStyle(
                          color: Colors.blueGrey, fontSize: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: Color(0xFF2563EB)),
                      ),
                      contentPadding: const EdgeInsets.all(14),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ── Hashtag input ────────────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _hashtagCtrl,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _addHashtag(),
                          decoration: InputDecoration(
                            hintText: 'Add hashtag',
                            prefixText: '# ',
                            prefixStyle: const TextStyle(
                                color: Color(0xFF2563EB),
                                fontWeight: FontWeight.bold),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide:
                              BorderSide(color: Colors.grey.shade200),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide:
                              BorderSide(color: Colors.grey.shade200),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        onPressed: _addHashtag,
                        icon: const Icon(Icons.add),
                        style: IconButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB)),
                      ),
                    ],
                  ),

                  // Hashtag chips
                  if (_hashtags.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6, runSpacing: 6,
                      children: _hashtags.map((tag) => GestureDetector(
                        onTap: () => setState(() => _hashtags.remove(tag)),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('#$tag',
                                  style: const TextStyle(
                                      color: Color(0xFF2563EB),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500)),
                              const SizedBox(width: 4),
                              const Icon(Icons.close,
                                  size: 12, color: Color(0xFF2563EB)),
                            ],
                          ),
                        ),
                      )).toList(),
                    ),
                  ],
                  const SizedBox(height: 16),

                  // Image picker area
                  GestureDetector(
                    onTap: _imageFiles.length < 4 ? _pickImages : null,
                    child: Container(
                      height: _imageFiles.isEmpty ? 80 : null,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: _imageFiles.isEmpty
                          ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate_outlined,
                              color: Colors.blueGrey.shade300, size: 26),
                          const SizedBox(width: 8),
                          Text('Add images (PNG, JPG, JPEG · max 4)',
                              style: TextStyle(
                                  color: Colors.blueGrey.shade400,
                                  fontSize: 13)),
                        ],
                      )
                          : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 6,
                              mainAxisSpacing: 6,
                              childAspectRatio: 1,
                            ),
                            itemCount: _imageFiles.length,
                            itemBuilder: (_, i) => Stack(
                              fit: StackFit.expand,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.file(
                                    _imageFiles[i],
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                Positioned(
                                  top: 4, right: 4,
                                  child: GestureDetector(
                                    onTap: () => setState(
                                            () => _imageFiles.removeAt(i)),
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: const BoxDecoration(
                                        color: Colors.black54,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.close,
                                          size: 14, color: Colors.white),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_imageFiles.length < 4)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: TextButton.icon(
                                onPressed: _pickImages,
                                icon: const Icon(Icons.add_photo_alternate_outlined, size: 16),
                                label: const Text('Add more', style: TextStyle(fontSize: 12)),
                                style: TextButton.styleFrom(
                                    foregroundColor: const Color(0xFF2563EB),
                                    padding: EdgeInsets.zero),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('Images are stored securely in cloud storage.',
                      style: TextStyle(
                          fontSize: 11, color: Colors.blueGrey.shade400)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHARED AVATAR WIDGET
// ─────────────────────────────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  final String name;
  final String? url;
  final double radius;

  const _Avatar({required this.name, this.url, this.radius = 20});

  @override
  Widget build(BuildContext context) {
    if (url != null && url!.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: NetworkImage(url!),
        onBackgroundImageError: (_, __) {},
      );
    }
    final initials = name.trim().isEmpty
        ? '?'
        : name.trim().split(' ').take(2).map((s) => s[0].toUpperCase()).join();
    const colors = [
      Color(0xFF6366F1), Color(0xFF2563EB), Color(0xFF10B981),
      Color(0xFFEC4899), Color(0xFFF59E0B), Color(0xFF0EA5E9),
    ];
    final color = name.isEmpty ? colors[0] : colors[name.codeUnitAt(0) % colors.length];
    return CircleAvatar(
      radius: radius,
      backgroundColor: color,
      child: Text(initials,
          style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: radius * 0.65)),
    );
  }
}