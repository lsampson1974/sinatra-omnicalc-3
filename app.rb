require "sinatra"
require "sinatra/reloader"

require "http"
require "json"
require "uri"

#We will take a crack at building this :

get("/") do
  redirect("/umbrella")
end

get("/umbrella") do

end
