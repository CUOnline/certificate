require './certificate_app'

class CertificateWorker
  @queue = 'certificate'

  def self.perform
  end
end
