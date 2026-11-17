import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../../domain/repositories/vault_repository.dart';
import '../widgets/animated_pressable.dart';

class WhatsAppProfileViewer extends StatefulWidget {
  final Uint8List? initialImage;
  final String username;
  final VaultRepository repository;
  final VoidCallback onPhotoChanged;

  const WhatsAppProfileViewer({
    super.key,
    required this.initialImage,
    required this.username,
    required this.repository,
    required this.onPhotoChanged,
  });

  @override
  State<WhatsAppProfileViewer> createState() => _WhatsAppProfileViewerState();
}

class _WhatsAppProfileViewerState extends State<WhatsAppProfileViewer> {
  Uint8List? _image;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _image = widget.initialImage;
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _changePhoto() async {
    if (_isProcessing) return;
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.image,
        dialogTitle: 'Select profile photo',
      );
      if (files.isEmpty || !mounted) return;

      setState(() => _isProcessing = true);
      final newBytes = await files.first.readAsBytes();
      if (newBytes.length > 5 * 1024 * 1024) {
        _showMessage('Choose an image smaller than 5 MB.');
        setState(() => _isProcessing = false);
        return;
      }

      await widget.repository.saveProfileImage(newBytes);
      if (!mounted) return;
      setState(() {
        _image = newBytes;
        _isProcessing = false;
      });
      widget.onPhotoChanged();
      _showMessage('Profile photo updated.');
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        _showMessage('Could not update photo: $e');
      }
    }
  }

  Future<void> _removePhoto() async {
    if (_isProcessing) return;
    if (_image == null) {
      _showMessage('No photo to remove.');
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        actionsOverflowButtonSpacing: 8,
        backgroundColor: const Color(0xFF1F2C34),
        title: const Text(
          'Remove profile photo?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'This will remove your current profile photo from the vault.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      setState(() => _isProcessing = true);
      try {
        await widget.repository.saveProfileImage(null);
        if (!mounted) return;
        setState(() {
          _image = null;
          _isProcessing = false;
        });
        widget.onPhotoChanged();
        _showMessage('Profile photo removed.');
      } catch (e) {
        if (mounted) {
          setState(() => _isProcessing = false);
          _showMessage('Could not remove photo: $e');
        }
      }
    }
  }

  Future<void> _savePhoto() async {
    if (_isProcessing) return;
    if (_image == null) {
      _showMessage('No photo to save.');
      return;
    }

    setState(() => _isProcessing = true);
    try {
      final fileName =
          'vault_profile_${DateTime.now().millisecondsSinceEpoch}.png';
      File? targetFile;

      // Try Android Download folder first
      try {
        final downloadDir = Directory('/storage/emulated/0/Download');
        if (await downloadDir.exists()) {
          targetFile = File('${downloadDir.path}/$fileName');
        }
      } catch (_) {}

      // Fallback to pictures directory or external storage or app documents
      if (targetFile == null) {
        try {
          final extDir = await getExternalStorageDirectory();
          if (extDir != null) {
            targetFile = File('${extDir.path}/$fileName');
          }
        } catch (_) {}
      }

      if (targetFile == null) {
        final docDir = await getApplicationDocumentsDirectory();
        targetFile = File('${docDir.path}/$fileName');
      }

      await targetFile.writeAsBytes(_image!);
      if (mounted) {
        _showMessage('Image saved to ${targetFile.path.contains('Download') ? 'Downloads' : 'Storage'}: $fileName');
      }
    } catch (e) {
      if (mounted) {
        _showMessage('Could not save photo: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B141B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F2C34),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          widget.username.isEmpty ? 'Profile photo' : widget.username,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: _image != null
                ? InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 4.0,
                    clipBehavior: Clip.none,
                    child: Image.memory(
                      _image!,
                      fit: BoxFit.contain,
                      gaplessPlayback: true,
                    ),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.15),
                            width: 2,
                          ),
                        ),
                        child: Container(
                          width: 156,
                          height: 156,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1F2C34),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.1),
                              width: 1,
                            ),
                          ),
                          child: const Icon(
                            Icons.person_rounded,
                            size: 88,
                            color: Colors.white38,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'No profile photo set',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Tap "Change" below to upload a photo',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
          ),
          if (_isProcessing)
            Container(
              color: Colors.black45,
              alignment: Alignment.center,
              child: const CircularProgressIndicator(color: Colors.white),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          color: const Color(0xFF1F2C34),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Change Button
              Expanded(
                child: AnimatedPressable(
                  onTap: _isProcessing ? null : _changePhoto,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.photo_camera_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Change',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Remove Button
              Expanded(
                child: AnimatedPressable(
                  onTap: _isProcessing ? null : _removePhoto,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.delete_outline_rounded,
                          color: _image != null ? Colors.redAccent : Colors.white38,
                          size: 22,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Remove',
                          style: TextStyle(
                            color: _image != null ? Colors.redAccent : Colors.white38,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Save Button
              Expanded(
                child: AnimatedPressable(
                  onTap: _isProcessing ? null : _savePhoto,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.download_rounded,
                          color: _image != null ? Colors.white : Colors.white38,
                          size: 22,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Save',
                          style: TextStyle(
                            color: _image != null ? Colors.white : Colors.white38,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

