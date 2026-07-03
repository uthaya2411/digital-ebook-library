import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/ebook.dart';
import 'ebook_card.dart';
import 'highlighted_text.dart';

class EbookListView extends StatelessWidget {
  final List<Ebook> ebooks;
  final String searchQuery;
  final Function(Ebook) onBookTap;
  final Function(Ebook) onDownloadTap;
  final Function(Ebook) onDeleteTap;

  const EbookListView({
    super.key,
    required this.ebooks,
    this.searchQuery = '',
    required this.onBookTap,
    required this.onDownloadTap,
    required this.onDeleteTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16.0),
      itemCount: ebooks.length,
      separatorBuilder: (context, index) => const Divider(
        color: Colors.white10,
        height: 1.0,
      ),
      itemBuilder: (context, index) {
        final ebook = ebooks[index];
        final uploadDate = DateFormat('MMM d, yyyy').format(ebook.createdAt);
        final formattedSize = _formatBytes(ebook.fileSize, 2);

        return InkWell(
          onTap: () => onBookTap(ebook),
          borderRadius: BorderRadius.circular(8.0),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
            child: Row(
              children: [
                // Book thumbnail (Mini Cover)
                Hero(
                  tag: 'book_cover_${ebook.id}',
                  child: EbookCard(
                    ebook: ebook,
                    width: 50.0,
                    height: 75.0,
                    showSpine: true,
                  ),
                ),
                const SizedBox(width: 16.0),
                
                // Book Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                       HighlightedText(
                        text: ebook.title,
                        query: searchQuery,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15.0,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4.0),
                      HighlightedText(
                        text: ebook.author,
                        query: searchQuery,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 13.0,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(height: 6.0),
                      Wrap(
                        spacing: 12.0,
                        runSpacing: 6.0,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(4.0),
                            ),
                            child: Text(
                              ebook.fileType.split('/').last.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.amberAccent,
                                fontSize: 10.0,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Text(
                            formattedSize,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.4),
                              fontSize: 11.0,
                            ),
                          ),
                          Text(
                            uploadDate,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.4),
                              fontSize: 11.0,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Actions (Download & Delete)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.download_rounded, color: Colors.tealAccent),
                      tooltip: 'Download file',
                      onPressed: () => onDownloadTap(ebook),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                      tooltip: 'Delete book',
                      onPressed: () => onDeleteTap(ebook),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Format size helper
  String _formatBytes(int bytes, int decimals) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB"];
    var i = (log(bytes) / log(1024)).floor();
    return '${(bytes / pow(1024, i)).toStringAsFixed(decimals)} ${suffixes[i]}';
  }
}
