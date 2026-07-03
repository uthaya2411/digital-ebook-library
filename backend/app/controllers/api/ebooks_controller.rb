class Api::EbooksController < ApplicationController
  before_action :set_ebook, only: [:show, :download, :destroy]

  # GET /api/ebooks
  # GET /api/ebooks/search?q=keyword
  def index
    # Apply search filter
    @ebooks = Ebook.all
    @ebooks = @ebooks.search_by_query(params[:q]) if params[:q].present?

    # Apply file type filter (PDF / EPUB)
    if params[:file_type].present?
      mime_type = params[:file_type].downcase == "epub" ? "application/epub+zip" : "application/pdf"
      @ebooks = @ebooks.where(file_type: mime_type)
    end

    # Apply sorting
    sort_by = params[:sort_by]
    sort_order = params[:sort_order] == "desc" ? "DESC" : "ASC"

    case sort_by
    when "title"
      @ebooks = @ebooks.order(title: sort_order)
    when "author"
      @ebooks = @ebooks.order(author: sort_order)
    else # Default to recently uploaded
      @ebooks = @ebooks.order(created_at: :desc)
    end

    render json: @ebooks.map { |ebook| serialize_ebook(ebook) }
  end

  # GET /api/ebooks/search?q=keyword
  def search
    index
  end

  # GET /api/ebooks/:id
  def show
    render json: serialize_ebook(@ebook)
  end

  # POST /api/ebooks
  def create
    @ebook = Ebook.new(ebook_params)

    if @ebook.save
      render json: serialize_ebook(@ebook), status: :created
    else
      render json: { errors: @ebook.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # GET /api/ebooks/:id/download
  def download
    if @ebook.file.attached?
      send_data @ebook.file.download,
                filename: @ebook.file.filename.to_s,
                type: @ebook.file.content_type,
                disposition: "attachment"
    else
      render json: { error: "File not found on storage" }, status: :not_found
    end
  end

  # DELETE /api/ebooks/:id
  def destroy
    @ebook.destroy
    render json: { message: "Ebook successfully deleted" }, status: :ok
  rescue => e
    render json: { error: "Failed to delete ebook: #{e.message}" }, status: :internal_server_error
  end

  private

  def set_ebook
    @ebook = Ebook.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Ebook not found" }, status: :not_found
  end

  def ebook_params
    # Accept metadata inputs along with the file and cover attachments
    params.permit(:file, :cover, :title, :author)
  end

  def serialize_ebook(ebook)
    {
      id: ebook.id,
      title: ebook.title,
      author: ebook.author,
      file_type: ebook.file_type,
      file_size: ebook.file_size,
      cover_color_start: ebook.cover_color_start,
      cover_color_end: ebook.cover_color_end,
      created_at: ebook.created_at,
      file_name: ebook.file.attached? ? ebook.file.filename.to_s : nil,
      download_url: api_ebook_download_url(ebook),
      cover_url: ebook.cover.attached? ? Rails.application.routes.url_helpers.rails_blob_url(ebook.cover, host: request.base_url) : nil
    }
  end

  # Helpers for URL paths
  def api_ebook_download_url(ebook)
    # Return full download URL
    Rails.application.routes.url_helpers.download_api_ebook_url(ebook, host: request.base_url)
  end
end
