require 'sinatra'

class ApplicationController < Sinatra::Base
  configure do
  	set :views, "app/views"
  	set :public_dir, "public"
  end

  get "/" do
  	erb :index
    @company_name = params["cname"]
    # raise
    p @company_name
  end

  get "/about" do
  	erb :about
  end
end
