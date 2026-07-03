import 'dart:math';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../models/ebook.dart';
import '../services/api_service.dart';

class UploadDialog extends StatefulWidget {
  final Function(Ebook) onUploadSuccess;

  const UploadDialog({super.key, required this.onUploadSuccess});

  @override
  State<UploadDialog> createState() => _UploadDialogState();
}

class _UploadDialogState extends State<UploadDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _authorController = TextEditingController();

  PlatformFile? _selectedFile;
  PlatformFile? _selectedCoverFile;
  bool _isUploading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _titleController.dispose();
    _authorController.dispose();
    super.dispose();
  }

  // Pick file using file_picker
  Future<void> _pickFile() async {
    setState(() {
      _errorMessage = null;
    });

    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'epub'],
        withData: true, // Crucial for Web to get bytes, also useful for mobile
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;

        // Validate size (50MB)
        if (file.size > 50 * 1024 * 1024) {
          setState(() {
            _errorMessage = 'File is too large. Maximum size is 50MB.';
          });
          return;
        }

        // Validate extension
        final extension = file.extension?.toLowerCase();
        if (extension != 'pdf' && extension != 'epub') {
          setState(() {
            _errorMessage = 'Only PDF and EPUB files are supported.';
          });
          return;
        }

        setState(() {
          _selectedFile = file;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to pick file: $e';
      });
    }
  }

  // Pick optional cover image using file_picker
  Future<void> _pickCoverFile() async {
    setState(() {
      _errorMessage = null;
    });

    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;

        // Validate size (5MB)
        if (file.size > 5 * 1024 * 1024) {
          setState(() {
            _errorMessage = 'Cover image is too large. Maximum size is 5MB.';
          });
          return;
        }

        setState(() {
          _selectedCoverFile = file;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to pick cover: $e';
      });
    }
  }

  // Handle ebook upload
  Future<void> _upload() async {
    if (_selectedFile == null) {
      setState(() {
        _errorMessage = 'Please select a file first.';
      });
      return;
    }

    setState(() {
      _isUploading = true;
      _errorMessage = null;
    });

    try {
      // Collect file details
      final name = _selectedFile!.name;
      final bytes = _selectedFile!.bytes ?? const <int>[];
      final path = _selectedFile!.path;

      // Collect cover details if present
      final coverBytes = _selectedCoverFile?.bytes;
      final coverPath = _selectedCoverFile?.path;
      final coverName = _selectedCoverFile?.name;

      // Call API Service upload
      final newBook = await ApiService.uploadEbook(
        name: name,
        bytes: bytes,
        path: path,
        title: _titleController.text.trim(),
        author: _authorController.text.trim(),
        coverBytes: coverBytes,
        coverPath: coverPath,
        coverName: coverName,
      );

      if (mounted) {
        widget.onUploadSuccess(newBook);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${newBook.title}" uploaded successfully!'),
            backgroundColor: Colors.teal,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isUploading = false;
        });
      }
    }
  }

  String _formatBytes(int bytes, int decimals) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB"];
    var i = (log(bytes) / log(1024)).floor();
    return '${(bytes / pow(1024, i)).toStringAsFixed(decimals)} ${suffixes[i]}';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
      insetPadding: const EdgeInsets.all(16.0),
      child: Stack(
        children: [
          // Content
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Add New Ebook',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20.0,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white60),
                          onPressed: _isUploading
                              ? null
                              : () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20.0),

                    // File picker zone
                    GestureDetector(
                      onTap: _isUploading ? null : _pickFile,
                      child: Container(
                        height: 120.0,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.03),
                          borderRadius: BorderRadius.circular(12.0),
                          border: Border.all(
                            color: _selectedFile != null
                                ? Colors.tealAccent.withOpacity(0.5)
                                : Colors.white10,
                            style: BorderStyle.solid,
                            width: 1.5,
                          ),
                        ),
                        child: _selectedFile == null
                            ? Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.cloud_upload_rounded,
                                    size: 40.0,
                                    color: Colors.white.withOpacity(0.3),
                                  ),
                                  const SizedBox(height: 8.0),
                                  Text(
                                    'Tap to select a PDF or EPUB file',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.6),
                                      fontSize: 13.0,
                                    ),
                                  ),
                                  const SizedBox(height: 4.0),
                                  Text(
                                    'Maximum size: 50MB',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.3),
                                      fontSize: 11.0,
                                    ),
                                  ),
                                ],
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.picture_as_pdf_rounded,
                                    size: 36.0,
                                    color: Colors.tealAccent,
                                  ),
                                  const SizedBox(height: 8.0),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16.0,
                                    ),
                                    child: Text(
                                      _selectedFile!.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14.0,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4.0),
                                  Text(
                                    _formatBytes(_selectedFile!.size, 2),
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.4),
                                      fontSize: 12.0,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 16.0),

                    // Cover image picker zone (Optional)
                    GestureDetector(
                      onTap: _isUploading || _selectedFile == null
                          ? null
                          : _pickCoverFile,
                      child: Opacity(
                        opacity: _selectedFile == null ? 0.5 : 1.0,
                        child: Container(
                          height: 100.0,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.02),
                            borderRadius: BorderRadius.circular(12.0),
                            border: Border.all(
                              color: _selectedCoverFile != null
                                  ? Colors.tealAccent.withOpacity(0.4)
                                  : Colors.white10,
                              style: BorderStyle.solid,
                              width: 1.2,
                            ),
                          ),
                          child: _selectedCoverFile == null
                              ? Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.add_photo_alternate_rounded,
                                      size: 32.0,
                                      color: Colors.white.withOpacity(0.25),
                                    ),
                                    const SizedBox(height: 6.0),
                                    Text(
                                      'Add Cover Image (Optional)',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.5),
                                        fontSize: 12.0,
                                      ),
                                    ),
                                    const SizedBox(height: 2.0),
                                    Text(
                                      'JPEG, PNG, WebP (Max 5MB)',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.2),
                                        fontSize: 10.0,
                                      ),
                                    ),
                                  ],
                                )
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.photo_library_rounded,
                                      size: 30.0,
                                      color: Colors.tealAccent,
                                    ),
                                    const SizedBox(height: 6.0),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16.0,
                                      ),
                                      child: Text(
                                        _selectedCoverFile!.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 13.0,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 2.0),
                                    Text(
                                      _formatBytes(_selectedCoverFile!.size, 2),
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.4),
                                        fontSize: 11.0,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20.0),

                    // Fields (Only enabled if a file is selected)
                    TextFormField(
                      controller: _titleController,
                      enabled: !_isUploading && _selectedFile != null,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Book Title (Optional)',
                        labelStyle: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                        ),
                        hintText: 'Autofilled from PDF metadata if empty',
                        hintStyle: TextStyle(
                          color: Colors.white.withOpacity(0.25),
                          fontSize: 13.0,
                        ),
                        enabledBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.white10),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.tealAccent),
                        ),
                        disabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: Colors.white.withOpacity(0.05),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16.0),

                    TextFormField(
                      controller: _authorController,
                      enabled: !_isUploading && _selectedFile != null,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Author (Optional)',
                        labelStyle: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                        ),
                        hintText: 'Autofilled from PDF metadata if empty',
                        hintStyle: TextStyle(
                          color: Colors.white.withOpacity(0.25),
                          fontSize: 13.0,
                        ),
                        enabledBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.white10),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.tealAccent),
                        ),
                        disabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: Colors.white.withOpacity(0.05),
                          ),
                        ),
                      ),
                    ),

                    // Error message section
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 16.0),
                      Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 13.0,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],

                    const SizedBox(height: 24.0),

                    // Actions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: _isUploading
                              ? null
                              : () => Navigator.pop(context),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(color: Colors.white54),
                          ),
                        ),
                        const SizedBox(width: 12.0),
                        ElevatedButton(
                          onPressed: _isUploading || _selectedFile == null
                              ? null
                              : _upload,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: Colors.teal.withOpacity(
                              0.3,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                          ),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 16.0,
                              vertical: 10.0,
                            ),
                            child: Text('Upload'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Uploading overlay
          if (_isUploading)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(16.0),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.tealAccent,
                      ),
                    ),
                    const SizedBox(height: 20.0),
                    Text(
                      'Uploading Ebook...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8.0),
                    Text(
                      'Parsing PDF metadata & saving file',
                      style: TextStyle(color: Colors.white70, fontSize: 12.0),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
