require 'pry'
# frozen_string_literal: true

require 'sinatra'
require 'sinatra/content_for'
require 'sinatra/reloader' if development?
require 'tilt/erubis'

configure do
  enable :sessions
  set :session_secret, 'secret'
  set :erb, :escape_html => true
end

before do
  session[:lists] ||= [
    { name: 'Today',
      todos: [{ id: 0, name: 'Workout', completed: false },
              { id: 1, name: 'Do loundry', completed: false },
              { id: 2, name: 'Eat ice cream', completed: false }] }
  ]
end

# Validating list exists - redirect if not
def load_list(index)
  list = session[:lists][index] if index && session[:lists][index]
  return list if list

  session[:error] = 'The list could not be found'
  redirect '/lists'
end

#####################################################################################
################################# Displayed Routes ##################################
#####################################################################################

get '/' do
  redirect '/lists'
end

# View all the lists
get '/lists' do
  @lists = session[:lists]

  erb :lists, layout: :layout
end

# View "new list" form
get '/lists/new' do
  erb :new_list, layout: :layout
end

# View specific list
get '/lists/:list_id' do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
  @todos = @list[:todos]

  erb :list, layout: :layout
end

# View "edit list" form
get '/lists/:list_id/edit' do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
  erb :edit_list, layout: :layout
end

#####################################################################################
################## Handling addeding and removing behind the scenes #################
#####################################################################################

# Create new list
post '/lists' do
  list_name = params[:list_name].strip
  
  error = list_name_error(list_name)
  if error
    session[:error] = error
    erb :new_list, layout: :layout
  else
    session[:lists] << { name: list_name, todos: [] }
    session[:success] = 'The list has been created.'
    redirect '/lists'
  end
end

# Update a todo list name
post '/lists/:list_id/edit' do
  @id = params[:list_id].to_i
  @list = load_list(@list_id)
  list_name = params[:list_name].strip

  error = list_name_error(list_name)
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

# Permanently delete list
post '/lists/:id/delete' do
  id = params[:id].to_i
  list_name = session[:lists][id][:name]
  session[:lists].delete_at(id)

  # If ajax request
  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    '/lists'
  else
    session[:success] = "The list \"#{list_name}\" has been removed"
    redirect '/lists'
  end
end

# generate next id_num for todo's in todolist
def next_todo_id(todos)
  max = todos.map { |todo| todo[:id] }.max || 0
  max + 1
end

# Add todo's to to a list
post '/lists/:list_id/todos' do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
  @todos = @list[:todos]
  text = params[:todo].strip

  error = todo_name_error(text)
  if error
    session[:error] = error
    erb :list, layout: :layout
  else
    id = next_todo_id(@list[:todos])
    
    @list[:todos] << { id: id, name: text, completed: false }
    session[:success] = 'The todo was added.'
    redirect "/lists/#{@list_id}"
  end
end

# Toggle todo "completed" on or off
post '/lists/:list_id/todos/:todo_id' do
  list_id = params[:list_id].to_i
  list = load_list(list_id)
  todo_id = params[:todo_id].to_i
  todo = list[:todos].find { |todo| todo[:id] == todo_id }

  is_completed = params[:completed] == 'true'
  todo[:completed] = is_completed
  session[:success] = 'Todo has been updated.'

  redirect "/lists/#{list_id}"
end

# Toggle all todo's complete or uncomplete
post '/lists/:list_id/check_all' do
  list_id = params[:list_id].to_i
  todos = session[:lists][list_id][:todos]
  todos.each { |todo| todo[:completed] = true }
  session[:success] = 'All todos has been completed.'

  redirect "/lists/#{list_id}"
end

# Permanently delete todo from list
post '/lists/:list_id/todos/:todo_id/delete' do
  list_id = params[:list_id].to_i
  list = load_list(list_id)
  todo_id = params[:todo_id].to_i

  list[:todos].delete_if do |todo|
    todo[:id] == todo_id
  end

  # If ajax request
  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    status 204
  else
    session[:success] = 'The todo has been deleted'
    redirect "/lists/#{list_id}"
  end
end

#####################################################################################
################################## Helper Methods ###################################
#####################################################################################

helpers do
  # Return error messsage if name is invalid - else return nil
  def list_name_error(list_name)
    if !valid_length?(list_name)
      'List name must be between 1 and 100 characters.'
    elsif !valid_name?(list_name)
      'List name must be unique.'
    end
  end

  def todo_name_error(name)
    'Todo name must be between 1 and 100 characters.' unless valid_length?(name)
  end

  def valid_name?(list_name)
    session[:lists].none? { |list| list[:name] == list_name }
  end

  def valid_length?(list_name)
    (1..100).cover?(list_name.size)
  end

  # toggles checkbox on or off for todo
  def toggle_check_box(todo)
    case todo[:completed]
    when true then todo[:completed] = false
    when false then todo[:completed] = true
    end
  end

  def completed_todos(list)
    list[:todos].count { |todo| todo[:completed] == true }
  end

  def list_class(list)
    list_class = []
    list_class << 'complete' if list_completed?(list)
    list_class.join(' ')
  end

  def todo_class(todo)
    todo_class = []
    todo_class << 'complete' if todo[:completed] == true
    todo_class.join(' ')
  end

  def list_completed?(list)
    return false if list[:todos].empty?
    list[:todos].all? { |todo| todo[:completed] == true }
  end

  def sort_lists(lists)
    completed_lists, incompleted_lists = lists.partition { |list| list_completed?(list) }

    incompleted_lists.each { |list| yield list, lists.index(list) }
    completed_lists.each { |list| yield list, lists.index(list) }
  end

  def sort_todos(todos)
    completed_todos, incompleted_todos = todos.partition { |todo| todo[:completed] }

    incompleted_todos.each { |todo| yield todo, todos.index(todo) }
    completed_todos.each { |todo| yield todo, todos.index(todo) }
  end
end
