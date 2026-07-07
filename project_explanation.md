# Digital Ebook Library Application - Technical Architecture Blueprint & File Walkthrough

This document provides a highly detailed explanation of the technology stack, software design patterns, end-to-end execution flows, and file-by-file code mappings of the Digital Ebook Library Application.

---

## 1. Core Technology Stack & Libraries

### **1.1. Backend API (Ruby on Rails 8)**
*   **Ruby on Rails 8.1.3:** Set up in API-only mode (`config.api_only = true` in `config/application.rb`) to strip out unnecessary middleware (cookies, session assets, flash alerts) for JSON streaming.
*   **SQLite3 (Database):** Embedded database engine. Stores ebook model fields (title, author, colors) while delegating binary storage links.
*   **Active Storage:** Handles uploading, hosting, and streaming binary attachments. It uses a relational database mapping (`active_storage_attachments` and `active_storage_blobs` tables) with local disk storage paths.
*   **Rack CORS (`rack-cors` gem):** Installed in `config/initializers/cors.rb` to permit Cross-Origin Resource Sharing (CORS), allowing the Flutter app to access endpoints from desktop localhosts or emulator proxies.
*   **pdf-reader Gem:** A lightweight Ruby library used to parse PDF syntax streams, inspect document catalog structures, and extract metadata tags (`/Title` and `/Author`).

### **1.2. Client Application (Flutter 3)**
*   **Flutter SDK 3.35.5 & Dart:** Framework for compiling UI code across Android, iOS, and Web.
*   **syncfusion_flutter_pdfviewer:** Used to render PDF structures. Supports canvas rendering, finger gestures, double-tap zoom, and scroll event listeners.
*   **shared_preferences:** Reads and writes key-value pairs locally. Used to store page scroll state indices and recently read book IDs.
*   **file_picker:** Coordinates platform-specific native file selectors to import PDF/EPUB documents.
*   **http package:** Serves as the HTTP client to send multipart form uploads, fetch JSON arrays, and stream download bytes.
*   **intl package:** Formats raw timestamps and file bytes into readable values (e.g. `2.4 MB`, `Jul 2, 2026`).

---

## 2. Design Patterns & Architectural Paradigms

1.  **MVC (Model-View-Controller) Pattern (Rails):**
    *   **Model (`Ebook`):** Handles validations, database access, and callbacks (automatic metadata parsing and color generator).
    *   **Controller (`EbooksController`):** Intercepts HTTP requests, handles parameters mapping, and returns JSON payloads.
2.  **Service-Oriented Client Pattern (Flutter):**
    *   **Service Layer (`ApiService`):** Isolates backend API HTTP requests. The UI screens never call the `http` package directly; they delegate all network actions to the `ApiService` static class, decoupling network configurations from UI rendering.
3.  **Debounce Pattern (Flutter):**
    *   Used in the search bar text field to prevent "HTTP request storms." Spawns a 500ms `Timer`. If the user types another character before the timer expires, the previous timer is cancelled, bundling network search requests.
4.  **State Machine View Controller (Flutter):**
    *   The `library_screen.dart` uses a switch-case state router mapping `ViewMode` enum (`bookshelf`, `grid`, `list`) to render the selected listing widget layout dynamically.
5.  **Offline Cache Interceptor (Flutter):**
    *   When opening a book, the reader intercepts the URL. If the file exists in the device's local application directory, it swaps the remote HTTP stream for a local file pointer, guaranteeing offline usability.

---

## 3. End-to-End Execution Flows

### **3.1. Upload Flow**
```
[User triggers Add Ebook] 
  --> Native FilePicker retrieves PDF 
  --> User clicks Upload (Optional manual Title/Author overrides)
  --> ApiService executes multipart POST request 
  --> Rails controller parses request parameters
  --> Ebook model checks before_validation hook:
      - Validates format (PDF/EPUB) and file size (<50MB)
      - If PDF and fields are blank, pdf-reader extracts /Title and /Author
      - Generates two color hex values for dynamic gradient bookshelf covers
  --> Saves record to SQLite database and uploads file binary to Active Storage
  --> Returns 201 Created JSON payload to Flutter client
  --> Flutter refreshes home page, rendering the book dynamically on the shelf
```

### **3.2. Reading & Position Memory Flow**
```
[User taps Ebook Cover]
  --> System checks SharedPreferences for page position matching book ID
  --> Checks if file was previously downloaded locally:
      - YES: SfPdfViewer opens local file in Offline Mode
      - NO: SfPdfViewer streams file from Rails Active Storage URL
  --> App shows SnackBar: "Resuming from page X" and jumps to that page
  --> User scrolls pages (onPageChanged trigger logs new page index to SharedPreferences)
  --> User exits (book ID added to SharedPreferences "Continue Reading" top list queue)
```

---

## 4. File-by-File Technical Blueprint

### **4.1. Backend Files**

#### **1. `backend/app/models/ebook.rb`**
*   **Technology/Gem:** Rails ActiveRecord + `pdf-reader` + Active Storage.
*   **Pattern:** Model Callbacks, File Validation.
*   **Details:**
    *   `has_one_attached :file`: Declares the Active Storage link.
    *   `has_one_attached :cover_image`: Declares the optional cover thumbnail upload link.
    *   `before_validation :extract_pdf_metadata`: Hook triggered before saving. Checks if the file is present. If it's a PDF, it parses it using `PDF::Reader` to extract `/Title` and `/Author` and assign them.
    *   `before_validation :generate_cover_colors`: Hook that assigns two color codes to `cover_color_start` and `cover_color_end` from a palette of gradient colors if not set.

#### **2. `backend/app/controllers/api/ebooks_controller.rb`**
*   **Technology/Gem:** Rails ActionController.
*   **Pattern:** MVC Controller, JSON Serializer.
*   **Details:**
    *   `index`: Supports query parameters `q` (ActiveRecord search by title/author/filename), `file_type` (filtering), and `sort_by` + `sort_order` (sorting records). Returns a JSON list of books.
    *   `create`: Receives multipart parameters, instantiates a new `Ebook` model, and saves the file.
    *   `download`: Retrieves the attachment using Rails Active Storage and streams it back to the client using `send_data` with attachment disposition headers.
    *   `destroy`: Triggers `@ebook.destroy!`, which cascades deletion to database rows and deletes files from local disk.

#### **3. `backend/config/routes.rb`**
*   **Pattern:** RESTful routing.
*   **Details:** Defines the API namespace routes mapping:
    ```ruby
    namespace :api do
      resources :ebooks do
        member do
          get :download
        end
      end
    end
    ```

---

### **4.2. Frontend Files (Flutter 3)**

#### **1. `lib/main.dart`**
*   **Pattern:** Application Root.
*   **Details:** Configures the Flutter app context, initializes a dark Material 3 theme (`ThemeData.dark()`), and sets the home screen page routing to the `LibraryScreen` widget.

#### **2. `lib/models/ebook.dart`**
*   **Pattern:** Data Transfer Object (DTO) / Factory.
*   **Details:** Translates the Rails API JSON payload into a Dart Ebook object.
    *   `factory Ebook.fromJson(...)`: Maps fields like `id`, `title`, `author`, `file_type`, `file_size`, `cover_color_start`, `cover_color_end`, `download_url`, `cover_url`, and `created_at`.

#### **3. `lib/services/api_service.dart`**
*   **Technology:** `http` package.
*   **Pattern:** Service Layer, Client-Server HTTP proxy.
*   **Details:**
    *   `fetchEbooks(...)`: Fetches books from the database using search, filter, and sorting query parameters.
    *   `uploadEbook(...)`: Sends a multipart HTTP POST request to upload documents and cover images.
    *   `downloadEbook(...)`: Streams bytes from the server, updates progress percentage callback indicators, and writes the file locally to the device's documentation folders.
    *   `deleteEbook(id)`: Sends a DELETE request to delete a book from the backend.

#### **4. `lib/screens/library_screen.dart`**
*   **Technology:** Flutter UI + `shared_preferences`.
*   **Pattern:** View Controller State, Search Debounce.
*   **Details:**
    *   `_fetchBooks()`: Invokes `ApiService.fetchEbooks()` and updates UI state variables.
    *   `_onSearchChanged(query)`: Uses a 500ms `Timer` to debounce keystrokes before calling `_fetchBooks()`.
    *   `_openReader(ebook)`: Saves the book ID to the "recently_read_books" SharedPreferences list, pushes the navigation to `ReaderScreen`, and refreshes the slider when returning.
    *   `_buildContent()`: Evaluates the `ViewMode` layout router (`bookshelf`, `grid`, `list`) to render the selected list view, and appends the horizontal **"Continue Reading"** slider at the top of the column if items exist in the queue.

#### **5. `lib/screens/reader_screen.dart`**
*   **Technology:** `syncfusion_flutter_pdfviewer` + `shared_preferences`.
*   **Pattern:** Screen Controller, Observer.
*   **Details:**
    *   `_checkLocalFileAndLoad()`: Checks if the file was downloaded locally. If so, updates state to use local file pointers.
    *   `_restoreLastReadPosition()`: Reads saved page position from `SharedPreferences` and triggers `_pdfViewerController.jumpToPage(savedPage)`.
    *   `_saveReadPosition(pageNumber)`: Triggered on scroll page changes inside `onPageChanged`, updating local shared preferences.
    *   `_isFullscreen` state: Hides app bars and status bars, giving a clean fullscreen view.
    *   `_zoomIn()` / `_zoomOut()` / `_resetZoom()`: Controls reader canvas scale attributes.

#### **6. `lib/widgets/bookshelf_view.dart`**
*   **Pattern:** Custom Painter UI grid widget.
*   **Details:** Divides books into rows dynamically depending on screen width constraints. Renders a physical 3D-painted wooden shelf board under each row using shadows and linear gradients.

#### **7. `lib/widgets/ebook_card.dart`**
*   **Pattern:** UI Presentation Widget.
*   **Details:** Renders individual books. Features spine shadows, page fold reflections, glossy overlays, and custom covers. Hides text if height < 100px to avoid RenderFlex layout overflows.

#### **8. `lib/widgets/ebook_grid_view.dart` & `ebook_list_view.dart`**
*   **Pattern:** UI Presentation Grid/List layouts.
*   **Details:** Renders book listings in list/grid views. Pass active search query queries to `HighlightedText` elements.

#### **9. `lib/widgets/highlighted_text.dart`**
*   **Pattern:** RichText matcher.
*   **Details:** Parses a text string. Splits matched characters from the search query case-insensitively and renders them inside a teal highlighted background box.

#### **10. `lib/widgets/upload_dialog.dart`**
*   **Technology:** `file_picker` package.
*   **Pattern:** Modal Dialog.
*   **Details:** The UI modal for ebook uploads. Allows choosing files and cover images. Displays size warnings if files exceed 50MB.
