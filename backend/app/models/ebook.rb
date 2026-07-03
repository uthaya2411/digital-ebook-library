class Ebook < ApplicationRecord
  has_one_attached :file
  has_one_attached :cover

  validates :title, presence: true
  validates :file_type, presence: true
  validates :file_size, presence: true, numericality: { greater_than: 0 }

  validate :correct_file_mime_type

  scope :search_by_query, ->(query) {
    return all if query.blank?
    left_outer_joins(file_attachment: :blob)
      .where("ebooks.title LIKE :q OR ebooks.author LIKE :q OR active_storage_blobs.filename LIKE :q", q: "%#{query}%")
  }

  before_validation :extract_metadata_and_set_defaults, on: :create

  private

  # Palette of premium gradient start/end color combinations
  COLOR_PALETTES = [
    { start: "#8E0E00", end: "#1F1C18" }, # Sunset Crimson / Dark Leather
    { start: "#000428", end: "#004e92" }, # Deep Ocean / Royal Blue
    { start: "#0F2027", end: "#203A43" }, # Charcoal Gray / Slate
    { start: "#134E5E", end: "#71B280" }, # Sage Forest / Teal Green
    { start: "#4A0E4E", end: "#120C1F" }, # Velvet Plum / Black Onyx
    { start: "#D66D75", end: "#E29587" }, # Antique Rose / Warm Sand
    { start: "#F28241", end: "#9C4216" }, # Terracotta / Clay
    { start: "#2C3E50", end: "#3498DB" }, # Slate Blue / Sky Blue
    { start: "#1D976C", end: "#93F9B9" }, # Emerald Green / Mint
    { start: "#43C6AC", end: "#191654" }  # Turquoise / Midnight Navy
  ].freeze

  def extract_metadata_and_set_defaults
    # Ensure a file is actually attached before processing
    return unless file.attached?

    # Set file size and type if not already provided
    self.file_size = file.byte_size if file_size.blank? || file_size.zero?
    self.file_type = file.content_type if file_type.blank?

    # Retrieve the temp file or IO from attachment changes before save
    change = attachment_changes["file"]
    io = nil
    if change
      attachable = change.attachable
      if attachable.is_a?(Hash)
        io = attachable[:io]
      elsif attachable.respond_to?(:tempfile)
        io = attachable.tempfile
      elsif attachable.respond_to?(:path)
        io = attachable
      end
    end

    # Extract Title and Author from PDF metadata if possible
    if file_type == "application/pdf" && io
      begin
        path = io.respond_to?(:path) ? io.path : nil
        reader = path ? PDF::Reader.new(path) : PDF::Reader.new(io)
        info = reader.info || {}
        
        if title.blank? && info[:Title].present?
          self.title = info[:Title].to_s.force_encoding("UTF-8").scrub.strip
        end
        
        if author.blank? && info[:Author].present?
          self.author = info[:Author].to_s.force_encoding("UTF-8").scrub.strip
        end
      rescue => e
        Rails.logger.warn "Failed to extract PDF metadata: #{e.message}"
      end
    end

    # Fallback to filename for title if it is still blank
    if title.blank?
      # Strip extension from the attached file's name
      self.title = File.basename(file.filename.to_s, ".*").titleize
    end

    # Fallback for author
    self.author = "Unknown Author" if author.blank?

    # Set up random bookshelf cover colors if not already specified
    if cover_color_start.blank? || cover_color_end.blank?
      palette = COLOR_PALETTES.sample
      self.cover_color_start = palette[:start]
      self.cover_color_end = palette[:end]
    end
  end

  def correct_file_mime_type
    if file.attached?
      unless ["application/pdf", "application/epub+zip"].include?(file.content_type)
        errors.add(:file, "must be a PDF or EPUB document")
      end
      # Maximum 50MB
      if file_size.present? && file_size > 50.megabytes
        errors.add(:file, "is too large. Maximum allowed size is 50MB")
      end
    else
      errors.add(:file, "must be uploaded")
    end

    if cover.attached?
      unless ["image/jpeg", "image/png", "image/webp"].include?(cover.content_type)
        errors.add(:cover, "must be a JPEG, PNG, or WebP image")
      end
      if cover.byte_size > 5.megabytes
        errors.add(:cover, "is too large. Maximum cover size is 5MB")
      end
    end
  end
end
