import 'dart:math';
import 'package:flutter/material.dart';
import '../models/ebook.dart';
import 'ebook_card.dart';

class BookshelfView extends StatelessWidget {
  final List<Ebook> ebooks;
  final Function(Ebook) onBookTap;
  final Function(Ebook) onDownloadTap;
  final Function(Ebook) onDeleteTap;

  const BookshelfView({
    super.key,
    required this.ebooks,
    required this.onBookTap,
    required this.onDownloadTap,
    required this.onDeleteTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        // Determine book size and spacing
        const double bookWidth = 85.0;
        const double bookHeight = 125.0;

        // Calculate number of books that can fit on one shelf
        // Account for margins and spacing
        int booksPerShelf = (screenWidth / (bookWidth + 24.0)).floor().clamp(
          2,
          8,
        );

        // Chunk the ebooks list into shelves
        final List<List<Ebook>> shelves = [];
        if (ebooks.isEmpty) {
          shelves.addAll([[], [], []]);
        } else {
          for (int i = 0; i < ebooks.length; i += booksPerShelf) {
            int end = min(i + booksPerShelf, ebooks.length);
            shelves.add(ebooks.sublist(i, end));
          }
        }

        return Container(
          // Wooden wall panel background color
          color: const Color(0xFF2E1C0C),
          child: Stack(
            children: [
              // Subtle background vertical wood grain lines
              Positioned.fill(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(
                    max(1, (screenWidth / 60.0).floor()),
                    (index) => Container(
                      width: 1.0,
                      color: Colors.black.withOpacity(0.08),
                    ),
                  ),
                ),
              ),

              // Shelves List
              ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 24.0),
                itemCount: shelves.length,
                itemBuilder: (context, shelfIndex) {
                  final shelfBooks = shelves[shelfIndex];

                  return Column(
                    children: [
                      // 1. Books row
                      Container(
                        height: bookHeight + 10.0,
                        padding: const EdgeInsets.symmetric(horizontal: 20.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: List.generate(booksPerShelf, (bookIndex) {
                            if (bookIndex < shelfBooks.length) {
                              final ebook = shelfBooks[bookIndex];
                              return GestureDetector(
                                onLongPress: () =>
                                    _showBookOptions(context, ebook),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6.0,
                                  ),
                                  child: Hero(
                                    tag: 'book_cover_${ebook.id}',
                                    child: EbookCard(
                                      ebook: ebook,
                                      width: bookWidth,
                                      height: bookHeight,
                                      onTap: () => onBookTap(ebook),
                                    ),
                                  ),
                                ),
                              );
                            } else {
                              // Empty placeholder spacer to keep formatting consistent
                              return const SizedBox(
                                width: bookWidth + 12.0,
                                height: bookHeight,
                              );
                            }
                          }),
                        ),
                      ),

                      // 2. 3D Wooden Shelf Board
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Column(
                          children: [
                            // Shelf Top (wood polish highlight)
                            Container(
                              height: 10.0,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF9E6B38),
                                    Color(0xFF865123),
                                  ],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                                borderRadius: BorderRadius.circular(2.0),
                              ),
                            ),
                            // Shelf Front (thick wood depth with shadow)
                            Container(
                              height: 12.0,
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Color(0xFF5E340E),
                                    Color(0xFF3F2108),
                                  ],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black54,
                                    blurRadius: 6.0,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 35.0), // Spacing between shelves
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // Display options menu on long press
  void _showBookOptions(BuildContext context, Ebook ebook) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.0)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: 20.0,
              horizontal: 16.0,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    EbookCard(
                      ebook: ebook,
                      width: 50.0,
                      height: 75.0,
                      showSpine: false,
                    ),
                    const SizedBox(width: 16.0),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ebook.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16.0,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4.0),
                          Text(
                            ebook.author,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 13.0,
                              fontStyle: FontStyle.italic,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24.0),
                const Divider(color: Colors.white10, height: 1.0),
                const SizedBox(height: 8.0),
                ListTile(
                  leading: const Icon(
                    Icons.chrome_reader_mode_rounded,
                    color: Colors.amberAccent,
                  ),
                  title: const Text(
                    'Read Book',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    onBookTap(ebook);
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.download_for_offline_rounded,
                    color: Colors.tealAccent,
                  ),
                  title: const Text(
                    'Download Ebook File',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    onDownloadTap(ebook);
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.delete_forever_rounded,
                    color: Colors.redAccent,
                  ),
                  title: const Text(
                    'Delete from Library',
                    style: TextStyle(color: Colors.redAccent),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    onDeleteTap(ebook);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
