require './certificate_app'

class CertificateWorker
  @queue = 'certificate'

  def self.perform(cert_html, email)
    infile = "tmp/cert.html"
    outfile = "tmp/cert.pdf"

    File.delete(infile) if File.exists?(infile)
    File.delete(outfile) if File.exists?(outfile)
    File.open(infile, 'w') { |f| f.write(cert_html) }

    system("wkhtmltopdf -T 0 -B 0 -L 0 -R 0 #{infile} #{outfile}")

    mail = Mail.new
    mail.from = CertificateApp.from_email
    mail.to = email
    mail.subject = CertificateApp.email_subject
    mail.body = "Your Academic Integrity certificate is attached. \n"
    mail.add_file outfile
    mail.deliver!
  end
end
