require "sinatra"
require "sinatra/reloader"

require "http"
require "json"
require "uri"
require "sqlite3"

# Let's include all our keys :

google_maps_key = ENV.fetch("GMAPS_KEY")
pirate_weather_key = ENV.fetch("PIRATE_WEATHER_KEY")


#===========================================================
# Let's start off with a fresh DB or reset when the user 
# wants to clear the DB:

def set_reset_db

  begin
    
    db = SQLite3::Database.open "chat_history.db"

    setups = [
      'drop table if exists chat_history',
      'create table chat_history(username text, message text)'
    ]

    for action in setups
      db.execute action
    end
  
  rescue SQLite3::Exception => excp  
    puts "Issue with DB : #{excp} "
  
  ensure
    db.close if db
  end

end

#==========================================================
#Here's our function for responding to user messages to the 
# ChatGPT AI.  Let's have 2 modes : regular response or 
# "Shakespere" response.

def chat_response(user_message, mode = "regular")

  open_ai_api_key = ENV.fetch("OPEN_AI_KEY")

  request_headers_hash = {
    "Authorization" => "Bearer #{open_ai_api_key}",
    "content-type" => "application/json"}

  if mode == "shakespere" 

      request_body_hash = {
        "model" => "gpt-3.5-turbo",
        "messages" => [
        {
          "role" => "system",
          "content" => "You are a helpful assistant who talks like Shakespeare."
        },
        {
          "role" => "user",
          "content" => "#{user_message}"
        }
       ]
      }
   
  else

    request_body_hash = {
      "model" => "gpt-3.5-turbo",
      "messages" => [
      {
        "role" => "user",
        "content" => "#{user_message}"
      }
     ]
    }
  
  end


  request_body_json = JSON.generate(request_body_hash)

  raw_response = HTTP.headers(request_headers_hash).post(
        "https://api.openai.com/v1/chat/completions",
        :body => request_body_json
  ).to_s

  parsed_response = JSON.parse(raw_response, object_class: OpenStruct)

  return parsed_response.choices[0].message.content   

end # Of method


#==========================================================
#==========================================================
# Let's welcome the user to our application :

get("/") do

  set_reset_db()
  erb(:welcome_message)

end

#==========================================================
# Our first function is the classic "umbrella" application : 

get("/umbrella") do
  erb(:umbrella)
end


#---------------------------------------------

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
# Next. We have a single message response from ChatGPT to the
# user.  Here we'll set ChatGPT to send a "Shakespere" response :

get ("/message") do
  erb(:gtp_single_message)
end

#---------------------------------------------

post ("/process_single_message") do

  the_message = params.fetch("the_message")

  @response_message = chat_response(the_message, "shakespere")
  erb(:gtp_response)
  
end

#==========================================================
# Finally, we set up a simple chat with ChatGPT.  We will have
# to store the message and responses in the SQLlite DB so that we
# can recall and display the chat history to the user :
get ("/chat") do

  erb(:chat_response)

end

#---------------------------------------------

post("/chat_response") do
 
  user_message = params.fetch("user_message")

  response_message = chat_response(user_message)

  # Let's clean up our response message so that it can be
  # used by the sqlite DB :
  response_message = response_message.gsub("'", "''")

  
  begin
    
    db = SQLite3::Database.open "chat_history.db"

    insert_records = [
      "insert into chat_history values ('user', '#{user_message}')",
      "insert into chat_history values ('assistant','#{response_message}')"
    ]
  
    for insert_record in insert_records
      db.execute insert_record
    end
  
  # Just in case something crazy happens with our connection to the DB :
  rescue SQLite3::Exception => excp
  
    puts "Issue with DB : #{excp} "
    
  ensure
    db.close if db
  end

  redirect("/chat")
  
end

#==========================================================
# Let's erase the chat history and start over :

post ("/clear_chat") do

  set_reset_db()
  redirect("/chat")

end

#==========================================================
