require "sinatra"
require "sinatra/reloader"

#We will take a crack at building this :

get("/") do
  "
  <h1>Welcome to your Sinatra App!</h1>
  <p>Define some routes in app.rb</p>
  "
end
