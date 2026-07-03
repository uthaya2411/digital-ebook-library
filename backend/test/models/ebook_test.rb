require "test_helper"

class EbookTest < ActiveSupport::TestCase
  test "should be valid with attached pdf file" do
    ebook = Ebook.new
    ebook.file.attach(
      io: File.open(Rails.root.join("test", "fixtures", "files", "sample.pdf")),
      filename: "sample.pdf",
      content_type: "application/pdf"
    )

    assert ebook.valid?
    assert_equal "Sample PDF Title", ebook.title
    assert_equal "Sample Author Name", ebook.author
    assert_not_nil ebook.cover_color_start
    assert_not_nil ebook.cover_color_end
  end

  test "should fallback to filename titleized if pdf has no metadata" do
    # Create a mock text file but name it pdf (or write non-metadata pdf)
    temp_pdf = Tempfile.new(["empty_meta", ".pdf"])
    temp_pdf.write("%PDF-1.4\n%EOF")
    temp_pdf.rewind

    ebook = Ebook.new
    ebook.file.attach(
      io: temp_pdf,
      filename: "my_cool_book.pdf",
      content_type: "application/pdf"
    )

    assert ebook.valid?
    assert_equal "My Cool Book", ebook.title
    assert_equal "Unknown Author", ebook.author
  ensure
    temp_pdf.close
    temp_pdf.unlink
  end

  test "should require a file attachment" do
    ebook = Ebook.new(title: "No File Book")
    assert_not ebook.valid?
    assert_includes ebook.errors[:file], "must be uploaded"
  end

  test "should validate file format" do
    ebook = Ebook.new
    ebook.file.attach(
      io: StringIO.new("fake text file contents"),
      filename: "test.txt",
      content_type: "text/plain"
    )

    assert_not ebook.valid?
    assert_includes ebook.errors[:file], "must be a PDF or EPUB document"
  end

  test "should validate file size" do
    ebook = Ebook.new(file_size: 51.megabytes)
    # Simulate a file size larger than 50MB
    ebook.file.attach(
      io: StringIO.new("fake contents"),
      filename: "large.pdf",
      content_type: "application/pdf"
    )
    
    assert_not ebook.valid?
    assert_includes ebook.errors[:file], "is too large. Maximum allowed size is 50MB"
  end
end
