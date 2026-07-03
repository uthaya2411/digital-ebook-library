require "test_helper"

class Api::EbooksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @pdf_file = fixture_file_upload("sample.pdf", "application/pdf")
    
    # Create an initial book for tests
    @ebook = Ebook.new(title: "Existing Book", author: "Existing Author")
    @ebook.file.attach(
      io: File.open(Rails.root.join("test", "fixtures", "files", "sample.pdf")),
      filename: "existing.pdf",
      content_type: "application/pdf"
    )
    @ebook.save!
  end

  test "should get index" do
    get api_ebooks_url
    assert_response :success
    
    json = JSON.parse(response.body)
    assert_kind_of Array, json
    assert_equal 1, json.length
    assert_equal "Existing Book", json.first["title"]
    assert_not_nil json.first["download_url"]
  end

  test "should get index with search matching title" do
    get api_ebooks_url, params: { q: "Existing" }
    assert_response :success
    
    json = JSON.parse(response.body)
    assert_equal 1, json.length
  end

  test "should get index with search not matching" do
    get api_ebooks_url, params: { q: "NonexistentQuery" }
    assert_response :success
    
    json = JSON.parse(response.body)
    assert_equal 0, json.length
  end

  test "should get search endpoint" do
    get search_api_ebooks_url, params: { q: "Existing" }
    assert_response :success
    
    json = JSON.parse(response.body)
    assert_equal 1, json.length
  end

  test "should show ebook details" do
    get api_ebook_url(@ebook)
    assert_response :success
    
    json = JSON.parse(response.body)
    assert_equal @ebook.id, json["id"]
    assert_equal "Existing Book", json["title"]
  end

  test "should return 404 for non-existent ebook" do
    get api_ebook_url(-1)
    assert_response :not_found
    
    json = JSON.parse(response.body)
    assert_equal "Ebook not found", json["error"]
  end

  test "should create ebook with metadata extracted" do
    assert_difference("Ebook.count", 1) do
      post api_ebooks_url, params: { file: @pdf_file }
    end
    assert_response :created
    
    json = JSON.parse(response.body)
    assert_equal "Sample PDF Title", json["title"] # Extracted from PDF fixture
    assert_equal "Sample Author Name", json["author"] # Extracted from PDF fixture
    assert_equal "application/pdf", json["file_type"]
    assert_equal "sample.pdf", json["file_name"]
  end

  test "should create ebook with custom title override" do
    assert_difference("Ebook.count", 1) do
      post api_ebooks_url, params: { file: @pdf_file, title: "Custom Title Override", author: "Custom Author" }
    end
    assert_response :created
    
    json = JSON.parse(response.body)
    assert_equal "Custom Title Override", json["title"]
    assert_equal "Custom Author", json["author"]
  end

  test "should fail to create ebook if file is missing" do
    assert_no_difference("Ebook.count") do
      post api_ebooks_url, params: { title: "Title Only" }
    end
    assert_response :unprocessable_entity
    
    json = JSON.parse(response.body)
    assert_includes json["errors"], "File must be uploaded"
  end

  test "should download ebook file" do
    get download_api_ebook_url(@ebook)
    assert_response :success
    assert_equal "attachment; filename=\"existing.pdf\"; filename*=UTF-8''existing.pdf", response.headers["Content-Disposition"]
    assert_equal "application/pdf", response.headers["Content-Type"]
  end

  test "should delete ebook" do
    assert_difference("Ebook.count", -1) do
      delete api_ebook_url(@ebook)
    end
    assert_response :success
    
    json = JSON.parse(response.body)
    assert_equal "Ebook successfully deleted", json["message"]
  end
end
