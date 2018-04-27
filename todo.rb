# frozen_string_literal: true

require 'bundler/setup'
require 'sinatra'
require 'sinatra/content_for'
require 'sinatra/reloader'
require 'tilt/erubis'

require 'pry'

disable :logging # Output to terminal more readable (no double logging entries)

configure do
  enable :sessions
  set :session_secret, 'secret'
end

before do
  session[:lists] ||= [{name: "Today", todos: ["Run away", "Dance on a dragon", "Fly into the kraken"]}]
end

get '/' do
  redirect '/lists'
end

# GET  /lists          -> view all lists
# GET  /lists/new      -> new list form
# POST /lists          -> create new list
# GET  /lists/1 -> view specific list and todos

# View all the lists
get '/lists' do
  @lists = session[:lists]

  erb :lists, layout: :layout
end

# Will render the "new list" form
get '/lists/new' do
  erb :new_list, layout: :layout
end

# View specific list
get '/lists/:id' do
  @id = params[:id].to_i
  @list = session[:lists][@id]
  
  erb :list, layout: :layout
end

# Will render "edit list" form
get '/lists/:id/edit' do
  @id = params[:id].to_i
  @list = session[:lists][@id]
  erb :edit_list, layout: :layout
end

# Create new list
post '/lists' do
  list_name = params[:list_name].strip
  
  error = list_name_error?(list_name)
  if error
    session[:error] = error
    erb :new_list, layout: :layout
  else
    session[:lists] << { name: list_name, todos: [] }
    session[:success] = 'The list has been created.'
    redirect '/lists'
  end
end

# Update an existing todo list
post '/lists/:id/edit' do
  @id = params[:id].to_i
  @list = session[:lists][@id]
  list_name = params[:list_name].strip
  
  error = list_name_error?(list_name)
  if error
    @list = session[:lists][@id]
    @id = params[:id].to_i
    session[:error] = error
    erb :edit_list, layout: :layout
  else
    @list[:name] = list_name
    session[:success] = 'The list name has been changed.'
    redirect "/lists/#{@id}"
  end
end

# Permanently deletes a list from lists
post '/lists/:id/delete' do
  @id = params[:id].to_i
  list_name = session[:lists][@id][:name]
  session[:lists].delete_at(@id)

  session[:success] = "The list \"#{list_name}\" has been removed"
  redirect '/lists'
end


helpers do
  # Return error messsage if name is invalid - else return nil
  def list_name_error?(list_name)
    if !valid_length?(list_name)
      'List name must be between 1 and 100 characters.'
    elsif !valid_name?(list_name)
      'List name must be unique.'
    end
  end

  def valid_name?(list_name)
    session[:lists].none? { |list| list[:name] == list_name }
  end

  def valid_length?(list_name)
    (1..100).cover?(list_name.size)
  end
end
