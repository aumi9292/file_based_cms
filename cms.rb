require 'sinatra'
require 'sinatra/reloader'
require 'tilt/erubis'
require 'sinatra/content_for'
require 'redcarpet'
require 'yaml'
require 'bcrypt'

configure do 
  enable :sessions 
  set :session_secret, "secret"
end 

before do 
  session ||= {}
end 

helpers do 

  def txt?(file)
    file.match(/[^.]+$/).to_s == "txt"
  end 

  def md?(file)
    file.match(/[^.]+$/).to_s == "md"
  end 

  def render_markdown(str)
    markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
    markdown.render(str)
  end 
end 

def data_path 
  path = ENV["RACK_ENV"] == "test" ? "../test/data" : "../data"
  File.expand_path(path, __FILE__)
end 

def format_txt_md(file, txt_arr)
  if txt?(file)
    headers["Content-Type"] = "text/plain" 
    txt_arr
  elsif md?(file)
    erb :md 
  end 
end 

#get index
get "/" do 
  pattern = File.join(data_path, "*")
  @files = Dir.glob(pattern).map { |fl| File.basename(fl) }
  erb :index
end 

#get user signin page
get "/users/signin" do
  erb :signin
end 

def load_user_credentials
  credentials_path = if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/config.yml", __FILE__)
  else
    File.expand_path("../config.yml", __FILE__)
  end
  YAML.load_file(credentials_path)
end

def encrypt_pw(pw)
  pw = BCrypt::Password.new(pw)
end 

def valid_uname_pword?(username, password)
  credentials = load_user_credentials
  if credentials.member?(username)
    encrypted = encrypt_pw(credentials[username])
    encrypted == password
  else
    false
  end 
end 

#user signin logic
post "/users/signin" do 
  @username = params[:username]
  password = params[:password]
  if valid_uname_pword?(@username, password)
    session[:user] = @username
    session[:success] = "Welcome #{@username}"
    redirect "/"
  else 
    session[:error] = "Invalid Credentials."
    status 422
    erb :signin
  end 
end 

#user log out
post "/users/signout" do 
  session.delete(:user)
  session[:success] = "You have been signed out."
  redirect "/"
end 

def redirect_guests
  return if session[:user]
  session[:error] = "You must be signed in to do that"
  redirect "/"
end 

#display new doc page
get "/new" do 
  redirect_guests
  erb :new_data
end 

#create new doc page
post "/new" do 
  redirect_guests
  new_file = params[:new_data]
  if new_file.empty? 
    session[:error] = "A name is required"
    erb :new_data    
  else
    new_file += ".txt" if File.extname(new_file).empty? 
    pattern = File.join(data_path, new_file)
    File.open(pattern, 'w')
    session[:success] = "#{new_file} was created!"
    redirect "/"
  end 
end 

get "/:data" do 
  file = params[:data] 
  pattern = File.join(data_path, file)
  
  if File.exist?(pattern)  
    @txt_arr = IO.readlines(pattern)
    format_txt_md(file, @txt_arr)
  else 
    session[:error] = "#{file} does not exist"
    redirect "/"
  end 
end 

#display edit document page
get "/:data/edit" do 
  redirect_guests
  @file = params[:data] 
  pattern = File.join(data_path, @file)
  @txt_arr = IO.readlines(pattern)
  erb :edit_data
end 

#edit document 
post "/:data/edit" do 
  redirect_guests
  @file = params[:data]
  path = File.join(data_path, @file)
  File.open(path, 'w') { |f| f.write params[:edit_file]}
  session[:success] = "#{@file} has been edited." unless params[:cancel]
  redirect "/"
end 

#delete document 
post "/delete" do 
  redirect_guests
  @file = params[:delete_data]
  path = File.join(data_path, @file)

  File.delete(path)
  session[:success] = "#{@file} has been deleted."
  redirect "/"
end 
