ENV["RACK_ENV"] = "test"

require "minitest/autorun"
require "rack/test"
require "fileutils"

require_relative "../cms"

class CMSTest < Minitest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def setup
    FileUtils.mkdir_p(data_path)
  end

  def teardown
    FileUtils.rm_r(data_path)
  end

  def create_document(name, content = "")
    File.open(File.join(data_path, name), "w") do |file|
      file.write(content)
    end
  end

  def session
    last_request.env["rack.session"]
  end

  def admin_session
    { "rack.session" => { username: "admin" } }
  end

  def test_index
    create_document "about.md"
    create_document "changes.txt"
    create_document "history.txt"

    get "/"

    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "about.md"
    assert_includes last_response.body, "changes.txt"
    assert_includes last_response.body, "history.txt"
  end

  def test_view_text_doc
    create_document "history.txt", "Ruby 2.6 released."

    get "/history.txt"

    assert_equal 200, last_response.status
    assert_equal "text/plain", last_response["Content-Type"]
    assert_includes last_response.body, "Ruby 2.6 released."
  end

  def test_nonexistent_file
    get "/something.txt"

    assert_equal 302, last_response.status
    
    assert_equal "something.txt does not exist.", session[:message]
  end

  def test_edit_document
    create_document "changes.txt"

    get "/changes.txt/edit", {}, admin_session

    assert_equal 200, last_response.status
    assert_includes last_response.body, "<textarea"
    assert_includes last_response.body, %q(<button type="submit")
  end

  def test_edit_document_signed_out
    create_document "changes.txt"

    get "/changes.txt/edit"

    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]
  end

  def test_document_edits_saved
    post "/changes.txt", {text_changes: "some change"}, admin_session

    assert_equal 302, last_response.status
    assert_equal "changes.txt has been updated.", session[:message]

    get "/changes.txt"
    assert_equal 200, last_response.status
    assert_includes last_response.body, "some change"
  end

  def test_document_edits_saved_signed_out
    post "/changes.txt", {text_changes: "some change"}, admin_session

    assert_equal 302, last_response.status
    assert_equal "changes.txt has been updated.", session[:message]

    get "/changes.txt"
    assert_equal 200, last_response.status
    assert_includes last_response.body, "some change"
  end

  def test_view_new_document_form
    get "/new", {}, admin_session

    assert_equal 200, last_response.status
    assert_includes last_response.body, %q(<button type="submit")
  end

  def test_view_new_document_form_signed_out
    get "/new"

    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]
  end

  def test_create_new_document
    post "/create", {filename: "new_doc.txt"}, admin_session
    assert_equal 302, last_response.status
    assert_equal "new_doc.txt was created.", session[:message]

    get "/"
    assert_includes last_response.body, "new_doc.txt"
  end

  def test_create_new_document_signed_out # failure in this test???
    post "/create", filename: "test.txt"

    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]
  end

  def test_create_new_document_without_filename
    post "/create", {filename: ""}, admin_session
    assert_equal 200, last_response.status
    assert_includes last_response.body, "A file name is required."
  end

  def test_delete_document
    create_document "document.txt"

    post "/document.txt/delete", {}, admin_session
    assert_equal 302, last_response.status
    assert_equal "document.txt has been deleted.", session[:message]

    get "/"
    refute_includes last_response.body, %q(href="/document.txt")
  end

  def test_delete_document_signed_out
    create_document "document.txt"

    post "/document.txt/delete"
    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]
  end

  def test_view_sign_in_form
    get "/users/signin"

    assert_equal 200, last_response.status
    assert_includes last_response.body, "<form"
    assert_includes last_response.body, %q(<button type="submit")
  end

  def test_sign_in_successful
    post "/users/signin", username: "admin", password: "secret"

    assert_equal 302, last_response.status
    assert_equal "Welcome!", session[:message]
    assert_equal "admin", session[:username]
    
    get last_response["Location"]
    assert_includes last_response.body, "Signed in as admin."
  end

  def test_sign_in_unsuccessful
    post "/users/signin", username: "uname", password: "pword"

    assert_equal 200, last_response.status
    assert_nil session[:username]
    assert_includes last_response.body, "Invalid credentials."
  end

  def test_signout
    get "/", {}, {"rack.session" => { username: "admin" } }
    assert_includes last_response.body, "Signed in as admin."

    post "/users/signout"
    assert_equal "You have been signed out.", session[:message]

    get last_response["Location"]
    assert_nil session[:username]
    assert_includes last_response.body, "Sign In"

    # post "/users/signin", username: "admin", password: "secret"
    # get last_response["Location"]
    # assert_includes last_response.body, "Welcome"

    # post "/users/signout"
    # get last_response["Location"]

    # assert_includes last_response.body, "You have been signed out"
    # assert_includes last_response.body, "Sign In"
  end
end
