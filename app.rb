require "sinatra"
require "sinatra/reloader"

require "http"
require "json"
require "uri"
require "sqlite3"

# Let's include all our keys :

google_maps_key = ENV.fetch("GMAPS_KEY")
pirate_weather_key = ENV.fetch("PIRATE_WEATHER_KEY")
open_ai_api_key = ENV.fetch("OPEN_AI_KEY")

# Let's setup our chat history DB :

begin
    
  db = SQLite3::Database.open "chat_history.db"

  setups = [
    'drop table if exists chat_history',
    'create table chat_history(username text, message text)'
  ]

  for action in setups
    db.execute action
  end



#puts "\nSelecting from both tables - ALL possible records"
#db.execute( "select * from chat_history" ) do |row|
#    puts row
#end


    #'insert into chat_history values ("someuser","Hello","202401190527")'
    #'insert into chat_history values ("computeuser", "Hi how are you ?","202401190528")'

  
rescue SQLite3::Exception => excp  
  puts "Issue with DB : #{excp} "
  
ensure
  db.close if db
end




get("/") do
  redirect("/umbrella")
end


#==========================================================

get("/umbrella") do
  erb(:umbrella)
end

#------------------

post("/process_umbrella") do

  @user_location = params.fetch("user_location")

  uri_encoded_location = URI.encode_uri_component(@user_location)

  google_maps_url = "https://maps.googleapis.com/maps/api/geocode/json?address=#{uri_encoded_location}&key=#{google_maps_key}"

  parsed_map_data = JSON.parse(HTTP.get(google_maps_url), object_class: OpenStruct)

  @location_latitude = parsed_map_data.results[0].geometry.location.lat
  @location_longitude = parsed_map_data.results[0].geometry.location.lng

  pirate_weather_url = "https://api.pirateweather.net/forecast/#{pirate_weather_key}/#{@location_latitude},#{@location_longitude}"

  weather_data = JSON.parse(HTTP.get(pirate_weather_url), object_class: OpenStruct)

  @current_temperature = weather_data.currently.temperature

  percentagePrecipProbability = weather_data.hourly.data[0].precipProbability*100

  if percentagePrecipProbability >= 10.0
    @umbrella_message = "You should take an umbrella."
  
  else 
    @umbrella_message = "You probably won't need an umbrella."
  
  end
  
  @summary = weather_data.currently.summary

  erb(:umbrella_result)

end

#==========================================================

get ("/message") do
  erb(:gtp_single_message)
end

#------------------

post ("/process_single_message") do

  @user_message = params.fetch("the_message")

  request_headers_hash = {
  "Authorization" => "Bearer #{open_ai_api_key}",
  "content-type" => "application/json"}

  request_body_hash = {
    "model" => "gpt-3.5-turbo",
    "messages" => [
      {
        "role" => "system",
        "content" => "You are a helpful assistant who talks like Shakespeare."
      },
      {
        "role" => "user",
        "content" => "#{@user_message}"
      }
    ]
  }

  request_body_json = JSON.generate(request_body_hash)

  raw_response = HTTP.headers(request_headers_hash).post(
    "https://api.openai.com/v1/chat/completions",
    :body => request_body_json
  ).to_s

  parsed_response = JSON.parse(raw_response, object_class: OpenStruct)

  @response_message = parsed_response.choices[0].message.content

  erb(:gtp_response)
  
end

#==========================================================

get ("/chat") do
  erb(:chat)
end

#------------------

post("/chat_response") do
 
  user_message = params.fetch("user_message")
  
  begin
    
    db = SQLite3::Database.open "chat_history.db"

    insert_records = [
      "insert into chat_history values ('user', '#{user_message}')",
      "insert into chat_history values ('assistant','answer')"
    ]
  
    for insert_record in insert_records
      db.execute insert_record
    end
  
    puts "\nSelecting from both tables - ALL possible records"
    db.execute( "select * from chat_history" ) do |row|
       puts row
    end
    
  rescue SQLite3::Exception => excp
    
    puts "Issue with DB : #{excp} "
    
  ensure
    db.close if db
  end
  
end
