import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/ebook.dart';
import 'ebook_card.dart';
import 'highlighted_text.dart';

class EbookGridView extends StatelessWidget {
  final List<Ebook> ebooks;
  final String searchQuery;
  final Function(Ebook) onBookTap;
  final Function(Ebook) onDownloadTap;
  final Function(Ebook) onDeleteTap;

  const EbookGridView({
    super.key,
    required this.ebooks,
    this.searchQuery = '',
    required this.onBookTap,
    required this.onDownloadTap,
    required this.onDeleteTap,
  });

  @override
  Widget build(BuildContext context) {
    // Determine number of columns based on screen width
    double width = MediaQuery.of(context).size.width;
    int columns = (width / 140.0).floor().clamp(2, 6);

    return GridView.builder(
      padding: const EdgeInsets.all(18.0),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        childAspectRatio: 0.64,
        crossAxisSpacing: 18.0,
        mainAxisSpacing: 22.0,
      ),
      itemCount: ebooks.length,
      itemBuilder: (context, index) {
        final ebook = ebooks[index];
        final uploadDate = DateFormat('MMM d, yyyy').format(ebook.createdAt);

        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10.0),
            color: Colors.white.withOpacity(0.02),
            border: Border.all(
              color: Colors.white.withOpacity(0.04),
              width: 1.0,
            ),
          ),
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
          child: Column(
            children: [
              // Ebook Cover
              Expanded(
                child: Hero(
                  tag: 'book_cover_${ebook.id}',
                  child: EbookCard(
                    ebook: ebook,
                    width: double.infinity,
                    height: double.infinity,
                    showSpine: true,
                    onTap: () => onBookTap(ebook),
                  ),
                ),
              ),
              const SizedBox(height: 8.0),

              // Actions strip below cover
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        HighlightedText(
                          text: ebook.title,
                          query: searchQuery,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12.0,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        HighlightedText(
                          text: ebook.author,
                          query: searchQuery,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 10.0,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        const SizedBox(height: 2.0),
                        Text(
                          uploadDate,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.3),
                            fontSize: 8.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        onTap: () => onDownloadTap(ebook),
                        borderRadius: BorderRadius.circular(12.0),
                        child: const Padding(
                          padding: EdgeInsets.all(4.0),
                          child: Icon(
                            Icons.download_for_offline_rounded,
                            color: Colors.tealAccent,
                            size: 18.0,
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: () => onDeleteTap(ebook),
                        borderRadius: BorderRadius.circular(12.0),
                        child: const Padding(
                          padding: EdgeInsets.all(4.0),
                          child: Icon(
                            Icons.delete_sweep_rounded,
                            color: Colors.redAccent,
                            size: 18.0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
