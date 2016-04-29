require './certificate_app'
require 'open3'

class CertificateWorker
  @queue = 'certificate'

  def self.perform(cert_html, email)
    html_path = File.expand_path("tmp/cert.html")
    pdf_path = File.expand_path("tmp/cert.pdf")

    File.open(html_path, 'w+') { |f| f.write(cert_html) }
    convert_to_pdf(html_path, pdf_path)

    mail = compose_mail(email, pdf_path)
    mail.deliver!
  end

  def self.convert_to_pdf(html_path, pdf_path)
    File.delete(pdf_path) if File.exists?(pdf_path)
    convert_command = "xvfb-run wkhtmltopdf -T 0 -B 0 -L 0 -R 0 " \
                      "--page-size Letter -O Landscape #{html_path} #{pdf_path}"

    Open3.popen3(convert_command) do |stdin, stdout, stderr, wait_thread|
      error = stderr.gets
      raise error if error
    end
  end

  def self.compose_mail(email, pdf_path)
    mail = Mail.new
    mail.from = CertificateApp.from_email
    mail.to = email
    mail.subject = CertificateApp.email_subject
    mail.body = "Your certificate is attached. \n"
    mail.add_file pdf_path
    mail
  end
end
