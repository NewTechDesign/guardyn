import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../domain/entities/media_entity.dart';

class MediaPickerResult {
  final String filePath;
  final MediaType type;
  final String mimeType;
  final String filename;
  final int sizeBytes;

  const MediaPickerResult({
    required this.filePath,
    required this.type,
    required this.mimeType,
    required this.filename,
    required this.sizeBytes,
  });
}

class MediaPickerSheet extends StatelessWidget {
  final void Function(MediaPickerResult result) onMediaSelected;
  final VoidCallback? onCancelled;
  final bool allowMultiple;
  final int maxFileSize;

  const MediaPickerSheet({
    super.key,
    required this.onMediaSelected,
    this.onCancelled,
    this.allowMultiple = false,
    this.maxFileSize = 100 * 1024 * 1024,
  });

  static Future<void> show(
    BuildContext context, {
    required void Function(MediaPickerResult result) onMediaSelected,
    VoidCallback? onCancelled,
    bool allowMultiple = false,
    int maxFileSize = 100 * 1024 * 1024,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => MediaPickerSheet(
        onMediaSelected: onMediaSelected,
        onCancelled: onCancelled,
        allowMultiple: allowMultiple,
        maxFileSize: maxFileSize,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Attach Media',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Divider(),
            _PickerOption(
              icon: Icons.camera_alt_rounded,
              label: 'Take Photo',
              onTap: () => _pickFromCamera(context, isVideo: false),
            ),
            _PickerOption(
              icon: Icons.videocam_rounded,
              label: 'Record Video',
              onTap: () => _pickFromCamera(context, isVideo: true),
            ),
            _PickerOption(
              icon: Icons.photo_library_rounded,
              label: 'Photo Library',
              onTap: () => _pickFromGallery(context, isVideo: false),
            ),
            _PickerOption(
              icon: Icons.video_library_rounded,
              label: 'Video Library',
              onTap: () => _pickFromGallery(context, isVideo: true),
            ),
            _PickerOption(
              icon: Icons.insert_drive_file_rounded,
              label: 'Documents',
              onTap: () => _pickDocument(context),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                onCancelled?.call();
              },
              child: Text(
                'Cancel',
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _pickFromCamera(BuildContext context, {required bool isVideo}) async {
    final picker = ImagePicker();

    try {
      final XFile? file;
      if (isVideo) {
        file = await picker.pickVideo(
          source: ImageSource.camera,
          maxDuration: const Duration(minutes: 10),
        );
      } else {
        file = await picker.pickImage(
          source: ImageSource.camera,
          imageQuality: 85,
          maxWidth: 2048,
          maxHeight: 2048,
        );
      }

      if (file != null && context.mounted) {
        await _processFile(context, file.path, file.name);
      }
    } catch (e) {
      if (context.mounted) {
        _showError(context, 'Failed to capture: ${e.toString()}');
      }
    }
  }

  Future<void> _pickFromGallery(BuildContext context, {required bool isVideo}) async {
    final picker = ImagePicker();

    try {
      final XFile? file;
      if (isVideo) {
        file = await picker.pickVideo(source: ImageSource.gallery);
      } else {
        file = await picker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 85,
          maxWidth: 2048,
          maxHeight: 2048,
        );
      }

      if (file != null && context.mounted) {
        await _processFile(context, file.path, file.name);
      }
    } catch (e) {
      if (context.mounted) {
        _showError(context, 'Failed to select: ${e.toString()}');
      }
    }
  }

  Future<void> _pickDocument(BuildContext context) async {
    try {
      final result = await FilePicker.pickFiles(
        allowMultiple: allowMultiple,
        type: FileType.any,
        withData: false,
        withReadStream: false,
      );

      if (result != null && result.files.isNotEmpty && context.mounted) {
        final file = result.files.first;
        if (file.path != null) {
          await _processFile(context, file.path!, file.name);
        }
      }
    } catch (e) {
      if (context.mounted) {
        _showError(context, 'Failed to select file: ${e.toString()}');
      }
    }
  }

  Future<void> _processFile(BuildContext context, String filePath, String filename) async {
    final file = File(filePath);
    final stat = await file.stat();
    final sizeBytes = stat.size;

    if (sizeBytes > maxFileSize) {
      if (context.mounted) {
        _showError(
          context,
          'File too large. Maximum size is ${(maxFileSize / (1024 * 1024)).toStringAsFixed(0)} MB',
        );
      }
      return;
    }

    final mimeType = _detectMimeType(filePath);
    final type = _detectMediaType(mimeType);

    if (context.mounted) {
      Navigator.pop(context);
      onMediaSelected(MediaPickerResult(
        filePath: filePath,
        type: type,
        mimeType: mimeType,
        filename: filename,
        sizeBytes: sizeBytes,
      ));
    }
  }

  String _detectMimeType(String filePath) {
    final extension = filePath.split('.').last.toLowerCase();
    return switch (extension) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'gif' => 'image/gif',
      'webp' => 'image/webp',
      'heic' => 'image/heic',
      'heif' => 'image/heif',
      'mp4' => 'video/mp4',
      'webm' => 'video/webm',
      'mov' => 'video/quicktime',
      'avi' => 'video/x-msvideo',
      'mp3' => 'audio/mpeg',
      'm4a' => 'audio/x-m4a',
      'wav' => 'audio/wav',
      'ogg' => 'audio/ogg',
      'pdf' => 'application/pdf',
      'doc' => 'application/msword',
      'docx' => 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'xls' => 'application/vnd.ms-excel',
      'xlsx' => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'ppt' => 'application/vnd.ms-powerpoint',
      'pptx' => 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
      'txt' => 'text/plain',
      'zip' => 'application/zip',
      'rar' => 'application/x-rar-compressed',
      '7z' => 'application/x-7z-compressed',
      _ => 'application/octet-stream',
    };
  }

  MediaType _detectMediaType(String mimeType) {
    if (mimeType.startsWith('image/')) return MediaType.image;
    if (mimeType.startsWith('video/')) return MediaType.video;
    if (mimeType.startsWith('audio/')) return MediaType.audio;
    if (mimeType.startsWith('application/') || mimeType.startsWith('text/')) {
      return MediaType.document;
    }
    return MediaType.other;
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }
}

class _PickerOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _PickerOption({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: theme.textTheme.bodyLarge,
            ),
            const Spacer(),
            Icon(
              Icons.chevron_right_rounded,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ],
        ),
      ),
    );
  }
}
