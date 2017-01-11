ENV['RACK_ENV'] ||= 'test'

require_relative '../certificate_app'
require 'minitest'
require 'minitest/autorun'
require 'minitest/rg'
require 'mocha/mini_test'
require 'rack/test'
require 'webmock/minitest'

# Turn on SSL for all requests
class Rack::Test::Session
  def default_env
    { 'rack.test' => true,
      'REMOTE_ADDR' => '127.0.0.1',
      'HTTPS' => 'on'
    }.merge(@env).merge(headers_for_env)
  end
end

class Minitest::Test

  include Rack::Test::Methods

  def app
    CertificateApp
  end

  def setup
    @canvas_url = 'https://canvasurl.com'
    app.settings.stubs(:canvas_url).returns(@canvas_url)
    app.settings.stubs(:api_cache).returns(false)

    WebMock.enable!
    WebMock.disable_net_connect!(allow_localhost: true)
    WebMock.reset!

    CertificateApp.settings.stubs(:mount).returns('')
  end

  def login(session_params = {})
    defaults = {
      'user_id' => '123',
      'user_roles' => ['AccountAdmin'],
      'user_email' => 'test@gmail.com'
    }

    env 'rack.session', defaults.merge(session_params)
  end
end
