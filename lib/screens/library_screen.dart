import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/ebook.dart';
import '../services/api_service.dart';
import '../widgets/bookshelf_view.dart';
import '../widgets/ebook_card.dart';
import '../widgets/ebook_grid_view.dart';
import '../widgets/ebook_list_view.dart';
import '../widgets/upload_dialog.dart';
import 'reader_screen.dart';

enum ViewMode { bookshelf, grid, list }

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _ReaderDownloadProgress {
  final int bookId;
  final double progress;
  _ReaderDownloadProgress(this.bookId, this.progress);
}

class _LibraryScreenState extends State<LibraryScreen> {
  List<Ebook> _ebooks = [];
  bool _isLoading = true;
  String? _errorMessage;
  ViewMode _viewMode = ViewMode.bookshelf;

  // Search & Sorting controls
  final _searchController = TextEditingController();
  Timer? _debounceTimer;
  String _searchQuery = '';
  String _sortBy = 'recent'; // 'recent', 'title', 'author'
  String _sortOrder = 'desc'; // 'asc', 'desc'
  String _fileTypeFilter = 'all'; // 'all', 'pdf', 'epub'

  // Downloading state
  _ReaderDownloadProgress? _downloadState;
  List<Ebook> _recentlyReadEbooks = [];

  @override
  void initState() {
    super.initState();
    _fetchBooks();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  // Load books from Rails API
  Future<void> _fetchBooks({String? query}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final books = await ApiService.fetchEbooks(
        query: query ?? _searchQuery,
        sortBy: _sortBy,
        sortOrder: _sortOrder,
        fileType: _fileTypeFilter == 'all' ? null : _fileTypeFilter,
      );
      setState(() {
        _ebooks = books;
        _isLoading = false;
      });
      _loadRecentlyRead();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  // Debounced search on change
  void _onSearchChanged(String query) {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      setState(() {
        _searchQuery = query;
      });
      _fetchBooks(query: query);
    });
  }

  // Handle Download Action
  Future<void> _downloadBook(Ebook ebook) async {
    setState(() {
      _downloadState = _ReaderDownloadProgress(ebook.id, 0.0);
    });

    try {
      final localPath = await ApiService.downloadEbook(
        ebook,
        onProgress: (progress) {
          setState(() {
            _downloadState = _ReaderDownloadProgress(ebook.id, progress);
          });
        },
      );

      setState(() {
        _downloadState = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Downloaded "${ebook.title}" successfully to offline storage!',
            ),
            backgroundColor: Colors.teal,
            action: SnackBarAction(
              label: 'READ NOW',
              textColor: Colors.white,
              onPressed: () => _openReader(ebook),
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _downloadState = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to download ebook: ${e.toString().replaceAll('Exception: ', '')}',
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  // Confirm delete book dialog
  void _confirmDelete(Ebook ebook) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text(
            'Delete Ebook',
            style: TextStyle(color: Colors.white),
          ),
          content: Text(
            'Are you sure you want to permanently delete "${ebook.title}" from the library? This cannot be undone.',
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white54),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _deleteBook(ebook);
              },
              child: const Text(
                'Delete',
                style: TextStyle(color: Colors.redAccent),
              ),
            ),
          ],
        );
      },
    );
  }

  // Call API delete and refresh list
  Future<void> _deleteBook(Ebook ebook) async {
    setState(() {
      _isLoading = true;
    });

    try {
      await ApiService.deleteEbook(ebook.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Deleted "${ebook.title}" successfully.'),
            backgroundColor: Colors.blueGrey,
          ),
        );
      }
      _fetchBooks();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete book: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  // Open PDF Reader Screen
  Future<void> _openReader(Ebook ebook) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> list =
          prefs.getStringList('recently_read_books') ?? [];
      list.remove(ebook.id.toString());
      list.insert(0, ebook.id.toString());
      if (list.length > 5) {
        list.removeRange(5, list.length);
      }
      await prefs.setStringList('recently_read_books', list);
    } catch (e) {
      debugPrint('Failed to save recently read: $e');
    }

    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ReaderScreen(ebook: ebook)),
    );

    _loadRecentlyRead();
  }

  // Load recently read books from SharedPreferences
  Future<void> _loadRecentlyRead() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> ids = prefs.getStringList('recently_read_books') ?? [];
      final parsedIds = ids
          .map((id) => int.tryParse(id))
          .whereType<int>()
          .toList();

      if (parsedIds.isEmpty) {
        setState(() {
          _recentlyReadEbooks = [];
        });
        return;
      }

      final List<Ebook> recentlyRead = [];
      for (final id in parsedIds) {
        final book = _ebooks.firstWhere(
          (b) => b.id == id,
          orElse: () => null as dynamic,
        );
        if (book != null) {
          recentlyRead.add(book);
        }
      }

      setState(() {
        _recentlyReadEbooks = recentlyRead;
      });
    } catch (e) {
      debugPrint('Failed to load recently read: $e');
    }
  }

  // Visual widget for Continue Reading section
  Widget _buildRecentlyReadSection() {
    return Container(
      padding: const EdgeInsets.only(top: 12.0, bottom: 12.0),
      color: const Color(0xFF181818),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            child: Row(
              children: [
                Icon(
                  Icons.history_rounded,
                  color: Colors.tealAccent,
                  size: 18.0,
                ),
                SizedBox(width: 8.0),
                Text(
                  'Continue Reading',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13.0,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8.0),
          SizedBox(
            height: 90.0,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              scrollDirection: Axis.horizontal,
              itemCount: _recentlyReadEbooks.length,
              separatorBuilder: (context, index) => const SizedBox(width: 12.0),
              itemBuilder: (context, index) {
                final ebook = _recentlyReadEbooks[index];
                return GestureDetector(
                  onTap: () => _openReader(ebook),
                  child: Container(
                    width: 240.0,
                    padding: const EdgeInsets.all(8.0),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(8.0),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.06),
                        width: 1.0,
                      ),
                    ),
                    child: Row(
                      children: [
                        // Small cover thumbnail (height 74.0)
                        SizedBox(
                          width: 48.0,
                          height: 74.0,
                          child: EbookCard(
                            ebook: ebook,
                            width: 48.0,
                            height: 74.0,
                            showSpine: false,
                            onTap: () => _openReader(ebook),
                          ),
                        ),
                        const SizedBox(width: 12.0),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                ebook.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12.0,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 3.0),
                              Text(
                                ebook.author,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.5),
                                  fontSize: 10.0,
                                ),
                              ),
                              const SizedBox(height: 4.0),
                              Row(
                                children: [
                                  Icon(
                                    Icons.chrome_reader_mode_rounded,
                                    size: 11.0,
                                    color: Colors.white.withOpacity(0.3),
                                  ),
                                  const SizedBox(width: 4.0),
                                  Text(
                                    ebook.fileType
                                        .split('/')
                                        .last
                                        .toUpperCase(),
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.3),
                                      fontSize: 9.0,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Open Upload Sheet Dialog
  void _showUploadDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return UploadDialog(
          onUploadSuccess: (newBook) {
            _fetchBooks();
          },
        );
      },
    );
  }

  // Sort change selection sheet
  void _showSortOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.0)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Sort Ebooks By',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16.0),

                    RadioListTile<String>(
                      title: const Text(
                        'Recently Uploaded',
                        style: TextStyle(color: Colors.white),
                      ),
                      value: 'recent',
                      groupValue: _sortBy,
                      activeColor: Colors.tealAccent,
                      onChanged: (val) {
                        setModalState(() => _sortBy = val!);
                        setState(() => _sortBy = val!);
                        Navigator.pop(context);
                        _fetchBooks();
                      },
                    ),
                    RadioListTile<String>(
                      title: const Text(
                        'Title',
                        style: TextStyle(color: Colors.white),
                      ),
                      value: 'title',
                      groupValue: _sortBy,
                      activeColor: Colors.tealAccent,
                      onChanged: (val) {
                        setModalState(() => _sortBy = val!);
                        setState(() => _sortBy = val!);
                        Navigator.pop(context);
                        _fetchBooks();
                      },
                    ),
                    RadioListTile<String>(
                      title: const Text(
                        'Author',
                        style: TextStyle(color: Colors.white),
                      ),
                      value: 'author',
                      groupValue: _sortBy,
                      activeColor: Colors.tealAccent,
                      onChanged: (val) {
                        setModalState(() => _sortBy = val!);
                        setState(() => _sortBy = val!);
                        Navigator.pop(context);
                        _fetchBooks();
                      },
                    ),
                    const Divider(color: Colors.white10, height: 24.0),

                    const Text(
                      'Sort Order',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8.0),

                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text('Ascending')),
                            selected: _sortOrder == 'asc',
                            selectedColor: Colors.teal.withOpacity(0.3),
                            labelStyle: TextStyle(
                              color: _sortOrder == 'asc'
                                  ? Colors.tealAccent
                                  : Colors.white60,
                            ),
                            backgroundColor: Colors.white.withOpacity(0.05),
                            onSelected: (selected) {
                              if (selected) {
                                setModalState(() => _sortOrder = 'asc');
                                setState(() => _sortOrder = 'asc');
                                Navigator.pop(context);
                                _fetchBooks();
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 12.0),
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text('Descending')),
                            selected: _sortOrder == 'desc',
                            selectedColor: Colors.teal.withOpacity(0.3),
                            labelStyle: TextStyle(
                              color: _sortOrder == 'desc'
                                  ? Colors.tealAccent
                                  : Colors.white60,
                            ),
                            backgroundColor: Colors.white.withOpacity(0.05),
                            onSelected: (selected) {
                              if (selected) {
                                setModalState(() => _sortOrder = 'desc');
                                setState(() => _sortOrder = 'desc');
                                Navigator.pop(context);
                                _fetchBooks();
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const Divider(color: Colors.white10, height: 24.0),

                    const Text(
                      'Filter by File Type',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8.0),

                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text('All')),
                            selected: _fileTypeFilter == 'all',
                            selectedColor: Colors.teal.withOpacity(0.3),
                            labelStyle: TextStyle(
                              color: _fileTypeFilter == 'all'
                                  ? Colors.tealAccent
                                  : Colors.white60,
                            ),
                            backgroundColor: Colors.white.withOpacity(0.05),
                            onSelected: (selected) {
                              if (selected) {
                                setModalState(() => _fileTypeFilter = 'all');
                                setState(() => _fileTypeFilter = 'all');
                                Navigator.pop(context);
                                _fetchBooks();
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8.0),
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text('PDF')),
                            selected: _fileTypeFilter == 'pdf',
                            selectedColor: Colors.teal.withOpacity(0.3),
                            labelStyle: TextStyle(
                              color: _fileTypeFilter == 'pdf'
                                  ? Colors.tealAccent
                                  : Colors.white60,
                            ),
                            backgroundColor: Colors.white.withOpacity(0.05),
                            onSelected: (selected) {
                              if (selected) {
                                setModalState(() => _fileTypeFilter = 'pdf');
                                setState(() => _fileTypeFilter = 'pdf');
                                Navigator.pop(context);
                                _fetchBooks();
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8.0),
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text('EPUB')),
                            selected: _fileTypeFilter == 'epub',
                            selectedColor: Colors.teal.withOpacity(0.3),
                            labelStyle: TextStyle(
                              color: _fileTypeFilter == 'epub'
                                  ? Colors.tealAccent
                                  : Colors.white60,
                            ),
                            backgroundColor: Colors.white.withOpacity(0.05),
                            onSelected: (selected) {
                              if (selected) {
                                setModalState(() => _fileTypeFilter = 'epub');
                                setState(() => _fileTypeFilter = 'epub');
                                Navigator.pop(context);
                                _fetchBooks();
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Render content according to active view mode
  Widget _buildContent() {
    if (_isLoading && _ebooks.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.tealAccent),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 50.0,
                color: Colors.redAccent,
              ),
              const SizedBox(height: 16.0),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 14.0),
              ),
              const SizedBox(height: 24.0),
              ElevatedButton.icon(
                onPressed: () => _fetchBooks(),
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_ebooks.isEmpty) {
      if (_viewMode == ViewMode.bookshelf) {
        return Stack(
          children: [
            BookshelfView(
              ebooks: const [],
              onBookTap: (_) {},
              onDownloadTap: (_) {},
              onDeleteTap: (_) {},
            ),
            Positioned.fill(
              child: Container(color: Colors.black.withOpacity(0.35)),
            ),
            IgnorePointer(child: _buildEmptyState()),
          ],
        );
      }
      return _buildEmptyState();
    }

    Widget mainListing;
    switch (_viewMode) {
      case ViewMode.bookshelf:
        mainListing = BookshelfView(
          ebooks: _ebooks,
          onBookTap: _openReader,
          onDownloadTap: _downloadBook,
          onDeleteTap: _confirmDelete,
        );
        break;
      case ViewMode.grid:
        mainListing = EbookGridView(
          ebooks: _ebooks,
          searchQuery: _searchQuery,
          onBookTap: _openReader,
          onDownloadTap: _downloadBook,
          onDeleteTap: _confirmDelete,
        );
        break;
      case ViewMode.list:
        mainListing = EbookListView(
          ebooks: _ebooks,
          searchQuery: _searchQuery,
          onBookTap: _openReader,
          onDownloadTap: _downloadBook,
          onDeleteTap: _confirmDelete,
        );
        break;
    }

    if (_recentlyReadEbooks.isNotEmpty && _searchQuery.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildRecentlyReadSection(),
          Expanded(child: mainListing),
        ],
      );
    }

    return mainListing;
  }

  // Visual template for empty state
  Widget _buildEmptyState() {
    final bool isSearch = _searchQuery.isNotEmpty;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSearch ? Icons.search_off_rounded : Icons.library_books_rounded,
              size: 72.0,
              color: Colors.white.withOpacity(0.2),
            ),
            const SizedBox(height: 20.0),
            Text(
              isSearch ? 'No Results Found' : 'Your Library is Empty',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18.0,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8.0),
            Text(
              isSearch
                  ? 'No ebooks match your query "$_searchQuery". Try checking for typos or searching a different term.'
                  : 'Start building your library by uploading PDF or EPUB files. They will sit right here on the shelf.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 13.0,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24.0),
            if (!isSearch)
              ElevatedButton.icon(
                onPressed: _showUploadDialog,
                icon: const Icon(Icons.add),
                label: const Text('Add Your First Book'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20.0),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20.0,
                    vertical: 12.0,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        elevation: 4.0,
        title: const Text(
          'Sagar Fab E-Library',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18.0,
          ),
        ),
        actions: [
          // Filter Sort Actions
          IconButton(
            icon: const Icon(Icons.sort_rounded, color: Colors.white70),
            tooltip: 'Sort options',
            onPressed: _showSortOptions,
          ),

          // View Mode Selector
          PopupMenuButton<ViewMode>(
            icon: const Icon(Icons.grid_view_rounded, color: Colors.white70),
            tooltip: 'Change view',
            onSelected: (mode) {
              setState(() {
                _viewMode = mode;
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: ViewMode.bookshelf,
                child: Row(
                  children: [
                    Icon(Icons.menu_book_rounded, size: 18.0),
                    SizedBox(width: 8.0),
                    Text('Bookshelf View'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: ViewMode.grid,
                child: Row(
                  children: [
                    Icon(Icons.grid_on_rounded, size: 18.0),
                    SizedBox(width: 8.0),
                    Text('Grid View'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: ViewMode.list,
                child: Row(
                  children: [
                    Icon(Icons.list_rounded, size: 18.0),
                    SizedBox(width: 8.0),
                    Text('List View'),
                  ],
                ),
              ),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60.0),
          child: Padding(
            padding: const EdgeInsets.only(
              left: 16.0,
              right: 16.0,
              bottom: 12.0,
            ),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search by title, author, or file name...',
                hintStyle: TextStyle(
                  color: Colors.white.withOpacity(0.3),
                  fontSize: 14.0,
                ),
                prefixIcon: const Icon(Icons.search, color: Colors.white54),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.white54),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.black.withOpacity(0.2),
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 12.0,
                  horizontal: 20.0,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30.0),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          // Main dynamic listing
          RefreshIndicator(
            color: Colors.tealAccent,
            backgroundColor: const Color(0xFF1E1E1E),
            onRefresh: () => _fetchBooks(),
            child: _buildContent(),
          ),

          // Downloading progress overlay indicator
          if (_downloadState != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                color: Colors.black.withOpacity(0.9),
                padding: const EdgeInsets.symmetric(
                  vertical: 12.0,
                  horizontal: 20.0,
                ),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 20.0,
                      height: 20.0,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.0,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.tealAccent,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16.0),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Downloading file...',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13.0,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4.0),
                          LinearProgressIndicator(
                            value: _downloadState!.progress,
                            backgroundColor: Colors.white10,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Colors.tealAccent,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16.0),
                    Text(
                      '${(_downloadState!.progress * 100).toInt()}%',
                      style: const TextStyle(
                        color: Colors.tealAccent,
                        fontSize: 13.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showUploadDialog,
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Add Ebook',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
