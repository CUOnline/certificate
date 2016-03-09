require 'wolf'

class CertificateApp < Wolf::Base
  set :root, File.dirname(__FILE__)
  self.setup
end
