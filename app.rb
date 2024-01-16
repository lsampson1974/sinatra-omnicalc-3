require "sinatra"
require "sinatra/reloader"

require "http"
require "json"
require "uri"

# We will take a crack at building this :
google_maps_key = ENV.fetch("GMAPS_KEY")
pirate_weather_key = ENV.fetch("PIRATE_WEATHER_KEY")
open_ai_api_key = ENV.fetch("OPEN_AI_KEY")


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
