import 'package:flutter/material.dart';
import '../models/ebook.dart';

class EbookCard extends StatelessWidget {
  final Ebook ebook;
  final double width;
  final double height;
  final bool showSpine;
  final VoidCallback? onTap;

  const EbookCard({
    super.key,
    required this.ebook,
    this.width = 110.0,
    this.height = 160.0,
    this.showSpine = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Parse hex colors safely, fallback if malformed
    Color startColor = _parseColor(ebook.coverColorStart);
    Color endColor = _parseColor(ebook.coverColorEnd);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.only(
            topRight: Radius.circular(8.0),
            bottomRight: Radius.circular(8.0),
            topLeft: Radius.circular(4.0),
            bottomLeft: Radius.circular(4.0),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.35),
              blurRadius: 8.0,
              offset: const Offset(4.0, 5.0),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topRight: Radius.circular(8.0),
            bottomRight: Radius.circular(8.0),
            topLeft: Radius.circular(4.0),
            bottomLeft: Radius.circular(4.0),
          ),
          child: Stack(
            children: [
              // 1. Cover Background (Gradient fallback or Network Image)
              Positioned.fill(
                child: ebook.coverUrl != null && ebook.coverUrl!.isNotEmpty
                    ? Image.network(
                        ebook.coverUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [startColor, endColor],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                        ),
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [startColor, endColor],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: const Center(
                              child: SizedBox(
                                width: 16.0,
                                height: 16.0,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white30),
                                ),
                              ),
                            ),
                          );
                        },
                      )
                    : Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [startColor, endColor],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                      ),
              ),

              // 2. Leather/Textured Overlay Sheen (Glossy effect)
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: const Alignment(1.5, 1.5),
                    colors: [
                      Colors.white.withOpacity(0.12),
                      Colors.white.withOpacity(0.02),
                      Colors.transparent,
                      Colors.black.withOpacity(0.1),
                      Colors.black.withOpacity(0.25),
                    ],
                    stops: const [0.0, 0.25, 0.45, 0.7, 1.0],
                  ),
                ),
              ),

              // 3. Gold/Silver Foil Framing or Styling
              Positioned.fill(
                child: Container(
                  margin: const EdgeInsets.all(6.0),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Colors.white.withOpacity(0.1),
                      width: 1.0,
                    ),
                    borderRadius: BorderRadius.circular(4.0),
                  ),
                ),
              ),

              // 4. Book Spine / Spine Highlight (Left Spine Shadow)
              if (showSpine) ...[
                // Dark spine shadow line
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: 10.0,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.black.withOpacity(0.35),
                          Colors.black.withOpacity(0.0),
                        ],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                    ),
                  ),
                ),
                // Light spine binding stripe
                Positioned(
                  left: 10.0,
                  top: 0,
                  bottom: 0,
                  width: 3.0,
                  child: Container(
                    color: Colors.white.withOpacity(0.15),
                  ),
                ),
                // Inner page fold shadow
                Positioned(
                  left: 13.0,
                  top: 0,
                  bottom: 0,
                  width: 5.0,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.black.withOpacity(0.18),
                          Colors.black.withOpacity(0.0),
                        ],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                    ),
                  ),
                ),
              ],

              // 5. Book Cover Content (Title and Author)
              Positioned.fill(
                left: showSpine ? 18.0 : 8.0,
                right: 8.0,
                top: 8.0,
                bottom: 8.0,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Book Format Tag (PDF/EPUB) at the top
                    Align(
                      alignment: Alignment.topRight,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5.0, vertical: 2.0),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(3.0),
                        ),
                        child: Text(
                          ebook.fileType.split('/').last.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 8.0,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    if (height >= 100.0) ...[
                      const Spacer(),
                      // Book Title
                      Text(
                        ebook.title,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'serif', // Serif for classical ebook feel
                          fontSize: 12.0,
                          fontWeight: FontWeight.bold,
                          height: 1.1,
                          shadows: [
                            Shadow(
                              color: Colors.black45,
                              blurRadius: 4.0,
                              offset: Offset(1.0, 1.0),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6.0),
                      // Book Author
                      Text(
                        ebook.author,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 9.0,
                          fontStyle: FontStyle.italic,
                          shadows: const [
                            Shadow(
                              color: Colors.black45,
                              blurRadius: 2.0,
                              offset: Offset(0.5, 0.5),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(flex: 2),
                    ] else
                      const Spacer(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Parse hex color safely
  Color _parseColor(String hexString) {
    try {
      final buffer = StringBuffer();
      if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
      buffer.write(hexString.replaceFirst('#', ''));
      return Color(int.parse(buffer.toString(), radix: 16));
    } catch (_) {
      return Colors.blueGrey;
    }
  }
}
