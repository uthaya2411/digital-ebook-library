# This file seeds the development library with default books using our sample PDF fixture.
sample_pdf_path = Rails.root.join("test/fixtures/files/sample.pdf")

if File.exist?(sample_pdf_path)
  books_data = [
    {
      title: "The Great Gatsby",
      author: "F. Scott Fitzgerald",
      cover_color_start: "#1A365D",
      cover_color_end: "#2A4365",
      file_name: "the_great_gatsby.pdf"
    },
    {
      title: "Dracula",
      author: "Bram Stoker",
      cover_color_start: "#800000",
      cover_color_end: "#2D0000",
      file_name: "dracula.pdf"
    },
    {
      title: "Pride and Prejudice",
      author: "Jane Austen",
      cover_color_start: "#1C3D32",
      cover_color_end: "#0D211A",
      file_name: "pride_and_prejudice.pdf"
    }
  ]

  books_data.each do |data|
    # Skip if already exists
    next if Ebook.exists?(title: data[:title])

    ebook = Ebook.new(
      title: data[:title],
      author: data[:author],
      cover_color_start: data[:cover_color_start],
      cover_color_end: data[:cover_color_end]
    )

    ebook.file.attach(
      io: File.open(sample_pdf_path),
      filename: data[:file_name],
      content_type: "application/pdf"
    )

    if ebook.save
      puts "Seeded: #{ebook.title} by #{ebook.author}"
    else
      puts "Failed to seed #{data[:title]}: #{ebook.errors.full_messages.join(', ')}"
    end
  end
else
  puts "Seed PDF fixture not found at #{sample_pdf_path}. Skipping ebook seeds."
end
