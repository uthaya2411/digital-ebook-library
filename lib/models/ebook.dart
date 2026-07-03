class Ebook {
  final int id;
  final String title;
  final String author;
  final String fileType;
  final int fileSize;
  final String coverColorStart;
  final String coverColorEnd;
  final DateTime createdAt;
  final String? fileName;
  final String downloadUrl;
  final String? coverUrl;

  Ebook({
    required this.id,
    required this.title,
    required this.author,
    required this.fileType,
    required this.fileSize,
    required this.coverColorStart,
    required this.coverColorEnd,
    required this.createdAt,
    this.fileName,
    required this.downloadUrl,
    this.coverUrl,
  });

  factory Ebook.fromJson(Map<String, dynamic> json) {
    return Ebook(
      id: json['id'] as int,
      title: json['title'] as String,
      author: json['author'] as String,
      fileType: json['file_type'] as String,
      fileSize: json['file_size'] as int,
      coverColorStart: json['cover_color_start'] as String? ?? '#2C3E50',
      coverColorEnd: json['cover_color_end'] as String? ?? '#3498DB',
      createdAt: DateTime.parse(json['created_at'] as String),
      fileName: json['file_name'] as String?,
      downloadUrl: json['download_url'] as String,
      coverUrl: json['cover_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'author': author,
      'file_type': fileType,
      'file_size': fileSize,
      'cover_color_start': coverColorStart,
      'cover_color_end': coverColorEnd,
      'created_at': createdAt.toIso8601String(),
      'file_name': fileName,
      'download_url': downloadUrl,
      'cover_url': coverUrl,
    };
  }
}
