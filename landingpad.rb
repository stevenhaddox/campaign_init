require 'rubygems'
require 'sinatra/base'
require 'uri'
require 'mongo'
require 'erb'
require 'json'

class LandingPad < Sinatra::Base
  set :static, true
  set :public_folder, 'public'

  configure do
    # Admin settings - used to access contacts
    $admin_acct_name = ENV['haddox4house_username']
    $admin_acct_passwd = ENV['haddox4house_password']

    # Page settings - used to configure your landing page
    $page_title     = 'Steven Haddox for House of Representatives, MD-8'
    $home_link      = 'Haddox4House'
    $app_title      = 'Steven Haddox for Congress'
    $app_summary    = '#haddox4house'
    $fec_disclaimer = "Paid for by Steven Haddox, MD-8 Libertarian Candidate for Congress"

    # Social media
    $twitter_url  = 'http://twitter.com/haddox4house'
    $facebook_url = 'http://facebook.com/haddox4house'
    $telephone    = '(240) 285-9823'
    $address      = 'P.O. Box 1425, Frederick, MD 21702'

    #your google analyics tracking key, if applicable
    $google_analytics_key = 'UA-48247659-1'
    $google_analytics_domain = 'haddox4house.com'

    $bg_color = '#2B2F3D'
    $app_title_color = '#FFFFFF'
    #see http://code.google.com/webfonts for available fonts
    #$app_title_font = 'Philosopher'
    $app_title_font = 'Lato:300,400,900'

    # Database settings - do NOT change these
    uri = URI.parse(ENV['MONGOHQ_URL'])
    conn = Mongo::Connection.from_uri(ENV['MONGOHQ_URL'])
    db = conn.db(uri.path.gsub(/^\//, ''))
    $collection = db.collection("contacts")
  end

  helpers do
    def protected!
      unless authorized?
        response['WWW-Authenticate'] = %(Basic realm="Restricted Area")
        throw(:halt, [401, "Not authorized\n"])
      end
    end

    def authorized?
      @auth ||=  Rack::Auth::Basic::Request.new(request.env)
      @auth.provided? && @auth.basic? && @auth.credentials && @auth.credentials == [$admin_acct_name, $admin_acct_passwd]
    end
  end

  get '/' do
    erb :index
  end

  get '/contacts' do
    protected!
    @contacts = $collection.find()
    erb :contacts
  end

  get '/contacts.json' do
    protected!
    content_type :json
    @contacts = $collection.find()
    @results = @contacts.to_a();
    JSON.dump(@results)
  end

  post '/subscribe' do
    content_type :json
    contact = params[:contact]
    contact_type = contact.start_with?("@") ||
                  !contact.include?("@") ? "Twitter" : "Email"

    doc = {
      "name"    => contact,
      "type"    => contact_type,
      "referer" => request.referer,
    }

    $collection.insert(doc)
      {"success" => true, "type" => contact_type}.to_json
    end
end
