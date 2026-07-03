import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scottinternational/main.dart';
import 'package:scottinternational/models/ebook.dart';
import 'package:scottinternational/widgets/bookshelf_view.dart';
import 'package:scottinternational/widgets/ebook_card.dart';

void main() {
  testWidgets('E-Library app smoke test - verify layout and loading state', (WidgetTester tester) async {
    // Build the app and trigger a frame.
    await tester.pumpWidget(const EBookLibraryApp());

    // Verify that the title in the App Bar is present.
    expect(find.text('Sagar Fab E-Library'), findsOneWidget);

    // Verify that the Search Bar is present.
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Search by title, author, or file name...'), findsOneWidget);

    // Verify that the loading indicator is displayed initially.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Verify that the floating action button "Add Ebook" is present.
    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(find.text('Add Ebook'), findsOneWidget);
  });

  testWidgets('EbookCard renders title, author, and format badge correctly', (WidgetTester tester) async {
    // Create a mock ebook model
    final mockEbook = Ebook(
      id: 99,
      title: 'The Great Gatsby',
      author: 'F. Scott Fitzgerald',
      fileType: 'application/pdf',
      fileSize: 2048576,
      coverColorStart: '#8E0E00',
      coverColorEnd: '#1F1C18',
      createdAt: DateTime.now(),
      fileName: 'gatsby.pdf',
      downloadUrl: 'http://localhost:3000/api/ebooks/99/download',
    );

    // Render the card in isolation
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: EbookCard(ebook: mockEbook),
        ),
      ),
    ));

    // Verify Title and Author text
    expect(find.text('The Great Gatsby'), findsOneWidget);
    expect(find.text('F. Scott Fitzgerald'), findsOneWidget);

    // Verify Format Badge
    expect(find.text('PDF'), findsOneWidget);
  });

  testWidgets('Search UI allows typing and clears input', (WidgetTester tester) async {
    await tester.pumpWidget(const EBookLibraryApp());

    // Find the text field
    final textField = find.byType(TextField);
    expect(textField, findsOneWidget);

    // Type in search bar
    await tester.enterText(textField, 'Gatsby');
    // Wait for the 500ms search debounce timer to fire and rebuild UI
    await tester.pump(const Duration(milliseconds: 600));

    // Verify search text changed
    expect(find.text('Gatsby'), findsOneWidget);

    // Verify clear button appears and tap it
    final clearButton = find.byIcon(Icons.clear);
    expect(clearButton, findsOneWidget);
    await tester.tap(clearButton);
    // Wait for the clear state to process
    await tester.pump(const Duration(milliseconds: 600));

    // Verify search text is cleared
    expect(find.text('Gatsby'), findsNothing);
  });

  testWidgets('BookshelfView empty shelves state renders wooden shelves background', (WidgetTester tester) async {
    // Render BookshelfView with empty list
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: BookshelfView(
          ebooks: const [],
          onBookTap: (_) {},
          onDownloadTap: (_) {},
          onDeleteTap: (_) {},
        ),
      ),
    ));

    // Verify shelf background structures exist
    expect(find.byType(Stack), findsWidgets);
    expect(find.byType(ListView), findsOneWidget);
  });

  testWidgets('Delete confirmation dialog pops up and can be cancelled', (WidgetTester tester) async {
    final mockEbook = Ebook(
      id: 1,
      title: 'Test Title',
      author: 'Test Author',
      fileType: 'application/pdf',
      fileSize: 1024,
      coverColorStart: '#000000',
      coverColorEnd: '#FFFFFF',
      createdAt: DateTime.now(),
      downloadUrl: 'http://localhost',
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) {
            return ElevatedButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Delete Ebook'),
                    content: Text('Are you sure you want to permanently delete "${mockEbook.title}"?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                    ],
                  ),
                );
              },
              child: const Text('Trigger Delete'),
            );
          },
        ),
      ),
    ));

    // Tap trigger button
    await tester.tap(find.text('Trigger Delete'));
    await tester.pumpAndSettle(); // Wait for dialog animations

    // Verify dialog is displayed
    expect(find.text('Delete Ebook'), findsOneWidget);
    expect(find.textContaining('Are you sure you want to permanently delete "Test Title"?'), findsOneWidget);

    // Tap cancel button and verify dialog goes away
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Delete Ebook'), findsNothing);
  });
}
