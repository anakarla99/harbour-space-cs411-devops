require 'sinatra'
require 'json'

set :port, 4444

get '/' do
  content_type :json
  {
    Name: 'Hello',
    Description: 'World',
    Url: request.host_with_port
  }.to_json
end
