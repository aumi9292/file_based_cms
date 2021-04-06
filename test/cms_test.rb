ENV["RACK_ENV"] = "test"

require 'fileutils'
require 'minitest/autorun'
require 'rack/test'
require_relative '../cms'

class CMSTest < Minitest::Test 
  include Rack::Test::Methods

  def app 
    Sinatra::Application 
  end 

  def setup 
    FileUtils.mkdir_p(data_path)
    create_document("about.md", partial_about_contents)
    create_document("history.txt", history_contents)
  end 

  def teardown
    FileUtils.rm_rf(data_path)
  end 

  def create_document(name, content="") 
    File.open(File.join(data_path, name), "w") do |file|
      file.write(content)
    end 
  end 

  def session 
    last_request.env["rack.session"]
  end 

  def sign_in_admin 
    { "rack.session" => { user: 'admin' } }
  end 

  def history_contents
    ["1993 - Yukihiro Matsumoto dreams up Ruby.\n", "1995 - Ruby 0.95 released.\n", "1996 - Ruby 1.0 released.\n", "1998 - Ruby 1.2 released.\n", "1999 - Ruby 1.4 released.\n", "2000 - Ruby 1.6 released.\n", "2003 - Ruby 1.8 released.\n", "2007 - Ruby 1.9 released.\n", "2013 - Ruby 2.0 released.\n", "2013 - Ruby 2.1 released.\n", "2014 - Ruby 2.2 released.\n", "2015 - Ruby 2.3 released."].join
  end

  def partial_about_contents
    <<-MD
# Contribute

Want to show Sinatra some love? Help out by contributing!

## Found a bug?

Log it in our [issue tracker][ghi] or send a note to the [mailing list][ml].
Be sure to include all relevant information, like the versions of Sinatra and
Ruby you're using. A [gist](http://gist.github.com/) of the code that caused
the issue as well as any error messages are also very helpful.
  MD
  end

  def test_files_i_ivar
    path = File.join(data_path, "*")
    files = Dir.glob(path).map { |fl| File.basename(fl) }.sort
    assert_equal ['about.md', 'history.txt'], files
  end 

  def test_index_not_logged_in
    get "/"
    assert_equal 200, last_response.status
    assert last_response.ok? 
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
  end 

  def test_index_logged_in_as_user
    get "/", {}, {"rack.session" => {user: "admin" } }
    assert_equal "admin", session[:user]
  end 

  def test_get_history  
    get "/history.txt"
    assert last_response.ok? 
    assert_equal 200, last_response.status
    assert_equal 328, last_response["Content-Length"].to_i
    assert_equal "text/plain", last_response["Content-Type"]
    assert_includes last_response.body, history_contents
  end 

  def test_invalid_path
    post "/"
    assert_equal 404, last_response.status
  end 

  def test_invalid_resource 
      get "/xYf5LP"
      assert_equal 302, last_response.status
      assert_equal "xYf5LP does not exist", session[:error]
  end 

  def test_format_txt_md
    get "/about.md" 
    assert last_response.ok?
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_match "<h1>Contribute</h1>", last_response.body

    get "/history.txt"
    assert_equal "text/plain", last_response["Content-Type"]
  end 

  def test_get_edit_data
    get "/history.txt/edit", {}, sign_in_admin
    assert last_response.ok? 
    assert_includes last_response.body, "<textarea id=\"edit_file\""
  end

  def test_post_edit
    post "/history.txt/edit", { edit_file: "hello" }, sign_in_admin
    assert_equal "history.txt has been edited.", session[:success]

    get "/history.txt"
    assert_equal 200, last_response.status
    assert_includes last_response.body, "hello"
  end 

  def test_show_new_data_name
    get "/new", {}, sign_in_admin
    assert_equal 200, last_response.status
    assert_includes last_response.body, "<input"
  end

  def test_new_data_creates_file
    new_file_name = "abc.txt"
    post "/new", { new_data: new_file_name }, sign_in_admin
    assert_equal 302, last_response.status

    path = File.join(data_path, "*")
    files = Dir.glob(path).map { |fl| File.basename(fl) }.sort
    assert_includes files, new_file_name

    full_path = File.join(data_path, new_file_name)
    assert File.exist?(full_path), "#{full_path}"
  end 

  def test_new_data_success_message 
    post "/new", { new_data: "abc.txt" }, sign_in_admin
    assert_equal "abc.txt was created!", session[:success]
  end 

  def test_new_data_error_message 
    post "/new", { new_data: "" }, sign_in_admin
    assert_includes last_response.body, "A name is required"
  end 

  def test_delete_data_post
    to_delete = "about.md"
    post "/delete", { delete_data: to_delete }, sign_in_admin
    assert_equal 302, last_response.status

    path = File.join(data_path, "*")
    files = files = Dir.glob(path).map { |fl| File.basename(fl) }.sort
    refute_includes files, to_delete

    assert_equal "about.md has been deleted.", session[:success]
  end

  def test_show_signin
    get "/users/signin"
    assert_equal 200, last_response.status
    assert_equal "hi", last_response.headers
    assert_includes last_response.body, "<form class=\"signin\" action=\"/users/signin\""
  end

  def test_post_signin_success
    post "/users/signin", username: "admin", password: "secret"
    assert_equal 302, last_response.status
    assert_equal "admin", session[:user]
    assert_equal "Welcome admin", session[:success]

    get last_response["Location"]
    assert_equal 200, last_response.status
    assert_includes last_response.body, "<p>Signed in as"
  end

  def test_post_signin_error
    post "/users/signin", username: "wrong", password: "x"
    refute session[:user]
    assert_includes last_response.body, "Invalid Credentials."
  end 

  def test_sign_out
    post "/users/signout", {}, { "rack.session" => { user: "admin" } }
    refute session[:user]
    assert_equal "You have been signed out.", session[:success]
  end 

  def test_new_guest_redirect 
    get "/new"
    assert_equal "You must be signed in to do that", session[:error]
    assert_equal 302, last_response.status
  end 
end 
