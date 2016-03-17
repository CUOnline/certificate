require 'wolf'

class CertificateApp < Wolf::Base
  set :root, File.dirname(__FILE__)
  self.setup

  post '/' do
    headers 'X-Frame-Options' => "ALLOW_FROM #{settings.canvas_url}"
  end

  get '/' do
    headers 'Content-Type' => 'text/xml'
    slim :lti_config
  end
end
