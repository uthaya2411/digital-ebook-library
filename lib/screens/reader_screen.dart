import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../models/ebook.dart';

class ReaderScreen extends StatefulWidget {
  final Ebook ebook;

  const ReaderScreen({super.key, required this.ebook});

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  late PdfViewerController _pdfViewerController;
  final GlobalKey<SfPdfViewerState> _pdfViewerKey = GlobalKey();
  
  bool _isLoading = true;
  bool _isLocal = false;
  File? _localFile;
  int _currentPage = 1;
  int _totalPages = 0;
  bool _isFullscreen = false;
  double _zoomLevel = 1.0;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _pdfViewerController = PdfViewerController();
    _checkLocalFileAndLoad();
  }

  @override
  void dispose() {
    _pdfViewerController.dispose();
    super.dispose();
  }

  // Check if ebook exists locally on the device to avoid fetching over network
  Future<void> _checkLocalFileAndLoad() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      String safeName = widget.ebook.fileName ?? 
          '${widget.ebook.title.replaceAll(RegExp(r'[^\w\s\-\.]'), '')}.pdf';
      if (!safeName.endsWith('.pdf') && !safeName.endsWith('.epub')) {
        safeName += '.pdf';
      }
      
      final filePath = '${directory.path}/$safeName';
      final file = File(filePath);
      
      if (await file.exists()) {
        setState(() {
          _localFile = file;
          _isLocal = true;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLocal = false;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLocal = false;
        _isLoading = false;
        _errorMessage = 'Error loading source file: $e';
      });
    }
  }

  // Load and restore last read position
  Future<void> _restoreLastReadPosition() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedPage = prefs.getInt('ebook_read_position_${widget.ebook.id}');
      if (savedPage != null && savedPage > 1 && savedPage <= _totalPages) {
        // Prompt user or automatically jump to last read position
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Resuming from page $savedPage'),
              duration: const Duration(seconds: 2),
              backgroundColor: Colors.teal,
            ),
          );
          _pdfViewerController.jumpToPage(savedPage);
        }
      }
    } catch (e) {
      debugPrint('Failed to load last read position: $e');
    }
  }

  // Save current read position to preferences
  Future<void> _saveReadPosition(int pageNumber) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('ebook_read_position_${widget.ebook.id}', pageNumber);
    } catch (e) {
      debugPrint('Failed to save read position: $e');
    }
  }

  // Handle Zoom In
  void _zoomIn() {
    setState(() {
      _zoomLevel = (_zoomLevel + 0.25).clamp(1.0, 3.0);
      _pdfViewerController.zoomLevel = _zoomLevel;
    });
  }

  // Handle Zoom Out
  void _zoomOut() {
    setState(() {
      _zoomLevel = (_zoomLevel - 0.25).clamp(1.0, 3.0);
      _pdfViewerController.zoomLevel = _zoomLevel;
    });
  }

  // Reset Zoom
  void _resetZoom() {
    setState(() {
      _zoomLevel = 1.0;
      _pdfViewerController.zoomLevel = 1.0;
    });
  }

  // Jump to specific page dialog
  void _showJumpToPageDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text('Go to Page', style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Enter page number (1 - $_totalPages)',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
              enabledBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white24),
              ),
              focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.tealAccent),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
            TextButton(
              onPressed: () {
                final page = int.tryParse(controller.text);
                if (page != null && page >= 1 && page <= _totalPages) {
                  _pdfViewerController.jumpToPage(page);
                }
                Navigator.pop(context);
              },
              child: const Text('Go', style: TextStyle(color: Colors.tealAccent)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF121212),
        body: Center(child: CircularProgressIndicator(color: Colors.tealAccent)),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: const Color(0xFF121212),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1E1E1E),
          title: Text(widget.ebook.title),
        ),
        body: Center(
          child: Text(
            _errorMessage!,
            style: const TextStyle(color: Colors.redAccent, fontSize: 16.0),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: _isFullscreen
          ? null
          : AppBar(
              backgroundColor: const Color(0xFF1E1E1E),
              foregroundColor: Colors.white,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.ebook.title,
                    style: const TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    _isLocal ? 'Offline Mode' : 'Online Stream',
                    style: TextStyle(fontSize: 11.0, color: _isLocal ? Colors.tealAccent : Colors.amberAccent),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.zoom_out, color: Colors.white70),
                  onPressed: _zoomLevel > 1.0 ? _zoomOut : null,
                ),
                Text(
                  '${(_zoomLevel * 100).toInt()}%',
                  style: const TextStyle(color: Colors.white70, fontSize: 12.0),
                ),
                IconButton(
                  icon: const Icon(Icons.zoom_in, color: Colors.white70),
                  onPressed: _zoomLevel < 3.0 ? _zoomIn : null,
                ),
                IconButton(
                  icon: const Icon(Icons.fullscreen_rounded, color: Colors.white70),
                  onPressed: () {
                    setState(() {
                      _isFullscreen = true;
                    });
                  },
                ),
              ],
            ),
      body: Stack(
        children: [
          // The PDF Viewer
          SafeArea(
            child: _isLocal && _localFile != null
                ? SfPdfViewer.file(
                    _localFile!,
                    key: _pdfViewerKey,
                    controller: _pdfViewerController,
                    onDocumentLoaded: (PdfDocumentLoadedDetails details) {
                      setState(() {
                        _totalPages = details.document.pages.count;
                      });
                      _restoreLastReadPosition();
                    },
                    onPageChanged: (PdfPageChangedDetails details) {
                      setState(() {
                        _currentPage = details.newPageNumber;
                      });
                      _saveReadPosition(details.newPageNumber);
                    },
                  )
                : SfPdfViewer.network(
                    widget.ebook.downloadUrl,
                    key: _pdfViewerKey,
                    controller: _pdfViewerController,
                    onDocumentLoaded: (PdfDocumentLoadedDetails details) {
                      setState(() {
                        _totalPages = details.document.pages.count;
                      });
                      _restoreLastReadPosition();
                    },
                    onPageChanged: (PdfPageChangedDetails details) {
                      setState(() {
                        _currentPage = details.newPageNumber;
                      });
                      _saveReadPosition(details.newPageNumber);
                    },
                    onDocumentLoadFailed: (PdfDocumentLoadFailedDetails details) {
                      setState(() {
                        _errorMessage = 'Failed to load PDF online: ${details.description}';
                      });
                    },
                  ),
          ),

          // Hover Floating Controls for Fullscreen Mode
          if (_isFullscreen)
            Positioned(
              top: 24.0,
              right: 16.0,
              child: FloatingActionButton.small(
                backgroundColor: Colors.black54,
                foregroundColor: Colors.white,
                child: const Icon(Icons.fullscreen_exit_rounded),
                onPressed: () {
                  setState(() {
                    _isFullscreen = false;
                  });
                },
              ),
            ),

          // Zoom controls helper floats
          if (_zoomLevel > 1.0)
            Positioned(
              bottom: 80.0,
              right: 16.0,
              child: FloatingActionButton.small(
                backgroundColor: Colors.black.withOpacity(0.8),
                foregroundColor: Colors.tealAccent,
                child: const Icon(Icons.youtube_searched_for_rounded),
                tooltip: 'Reset zoom',
                onPressed: _resetZoom,
              ),
            )
        ],
      ),
      bottomNavigationBar: _isFullscreen
          ? null
          : BottomAppBar(
              color: const Color(0xFF1E1E1E),
              elevation: 8.0,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white70),
                      onPressed: _currentPage > 1
                          ? () => _pdfViewerController.previousPage()
                          : null,
                    ),
                    
                    GestureDetector(
                      onTap: _showJumpToPageDialog,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(20.0),
                        ),
                        child: Text(
                          'Page $_currentPage of $_totalPages',
                          style: const TextStyle(
                            color: Colors.tealAccent,
                            fontSize: 14.0,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),

                    IconButton(
                      icon: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70),
                      onPressed: _currentPage < _totalPages
                          ? () => _pdfViewerController.nextPage()
                          : null,
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
