require "sinatra"
require "sinatra/reloader"
require "tilt/erubis"
require "redcarpet"
require "yaml"
require "bcrypt"
# require "open-uri"

configure do
	enable :sessions
	set :session_secret, "7d260d1ca94e347151d7de84bc2a239ced9dcf23347b0d5e1562a0a45fdc295d"
end

def data_path
  if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/data", __FILE__)
  else
    File.expand_path("../data", __FILE__)
  end
end

def render_markdown(text)
  markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
  markdown.render(text)
end

def verify_user_signin
  if !session[:username]
    session[:message] = "You must be signed in to do that."
    redirect "/"
  end
end

get "/" do
  file_path = File.join(data_path, "*")
  @files = Dir.glob(file_path).map { |path| File.basename(path) }
  erb :index
end

# view new document form
get "/new" do
  verify_user_signin
  erb :new
end

# create new document
post "/create" do
  filename = params[:filename].to_s
  if filename.empty?
    session[:message] = "A file name is required."
    erb :new
  else
    file_path = File.join(data_path, filename)
    File.write(file_path, "")
    session[:message] = "#{filename} was created."
    redirect "/"
  end
end

# view sign in form
get "/users/signin" do
  erb :sign_in
end

def users_credentials
  path = if ENV["RACK_ENV"] == "test"
          File.expand_path("../test/users.yml", __FILE__)
        else
          File.expand_path("../data/users.yml", __FILE__)
        end
  YAML.load_file(path)
end

def valid_credentials?(username, password)
  credentials = users_credentials
  if credentials[username]
    encrypted_password = credentials[username]
    BCrypt::Password.new(encrypted_password) == password
  else
    false
  end
end

# user sign in
post "/users/signin" do
  username = params[:username]
  password = params[:password]

  if valid_credentials?(username, password)
    session[:username] = username
    session[:password] = password
    session[:message] = "Welcome!"
    redirect "/"
  else
    @user_input = username
    session[:message] = "Invalid credentials."
    erb :sign_in
  end
end

# user sign out
post "/users/signout" do
  session.delete(:username)
  session[:message] = "You have been signed out."
  redirect "/"
end

# view user sign up form
get "/signup" do
  erb :sign_up
end

# create new account
post "/signup" do
  username = params[:username]
  password = params[:password]

  if username.empty? || password.empty?
    session[:message] = "Please enter valid username and password."
    erb :sign_up
  elsif users_credentials.keys.include?(username)
    session[:message] = "Username already exists. Choose another username."
    erb :sign_up
  elsif password != params[:confirm_password]
    session[:message] = "Passwords do not match."
    erb :sign_up
  else
    file_path = File.join(data_path, "users.yml")
    encrypted_password = BCrypt::Password.create(password).to_s # why does calling `to_s` return just string object vs extra information?
    credentials = users_credentials
    credentials[username] = encrypted_password
    File.write(file_path, YAML.dump(credentials))
    session[:message] = "New account for user #{username} successfully created."
    redirect "/"
  end
end

# delete document
post "/:filename/delete" do
  verify_user_signin

  filename = params[:filename]
  file_path = File.join(data_path, filename)
  File.delete(file_path)
  session[:message] = "#{filename} has been deleted."
  redirect "/"
end

def load_file(path)
  if File.extname(path) == (".md")
    text = File.read(path)
    erb render_markdown(text)
  else
    headers["Content-Type"] = "text/plain"
    File.read(path)
  end
end

# view single document
get "/:filename" do
  path = File.join(data_path, File.basename(params[:filename]))

  if File.exist?(path)
    load_file(path)
  else
    session[:message] = "#{params[:filename]} does not exist."
    redirect "/"
  end
end

# view edit document page
get "/:filename/edit" do
  verify_user_signin

  path = File.join(data_path, params[:filename])
  @file = File.read(path)
  erb :edit_doc
end

# save changes to edited document
post "/:filename" do
  verify_user_signin

  text = params[:text_changes]
  path = File.join(data_path, params[:filename])

  File.write(path, text)
  session[:message] = "#{params[:filename]} has been updated."
  redirect "/"
end

# view duplicate document page
get "/:filename/duplicate" do
  verify_user_signin

  path = File.join(data_path, params[:filename])
  @file = File.read(path)
  erb :duplicate
end

# save duplicate document
post "/:filename/duplicate" do
  verify_user_signin

  if params[:new_name].strip.empty?
    # file must have name (works!)
    path = File.join(data_path, params[:filename])
    @file = File.read(path)
    session[:message] = "A file name is required."
    erb :duplicate
  elsif params[:new_name] == params[:filename]
    # warn user that duplicated file's name has not been changed.  This will overwrite the current file of the same name. continue?
    # if user chooses to continue, flash message document overwritten
    # otherwise, reload duplicate page
  else
    # new file created with changes saved (works!)
    path = File.join(data_path, params[:new_name])
    text = params[:text_changes]
    File.write(path, text)
    session[:message] = "#{params[:filename]} was duplicated."
    redirect "/"
  end
end

# fix: when deleting file when not signed in, message "you need to be signed in to do that" si not being displayed

# modify CMS so that each version of a document is preserved as changes are made to it

# fix: when clicking delete and not signed in, javascript message pops up; prioritize flash message sign in error
# if signed in user is admin, can view file with users and passwords
# rename document
# assign someone as admin
  # can view list of users
# must have file extensions to create file
# password requirements
# add home button
# capability of adding images
