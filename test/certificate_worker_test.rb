require_relative './test_helper'

class CertificateWorkerTest < Minitest::Test

  def setup
    tmp_dir = app.send(:tmp_dir) || '/tmp'
    app.set :tmp_dir, tmp_dir

    @cert_html = File.expand_path(File.join(tmp_dir, 'cert.html'))
    @cert_pdf = File.expand_path(File.join(tmp_dir, 'cert.pdf'))
    File.delete(@cert_html) if File.exists?(@cert_html)
    File.delete(@cert_pdf) if File.exists?(@cert_pdf)
  end

  def test_perform
    cert_body = "<body><p> You passed! </p></body>"
    mail = mock()
    mail.expects(:deliver!)

    CertificateWorker.expects(:compose_mail).returns(mail)
    CertificateWorker.expects(:convert_to_pdf)
    CertificateWorker.perform(cert_body, 'test@gmail.com')

    assert File.exists?(@cert_html)
    assert_equal cert_body, File.read(@cert_html)
  end

  def test_convert_to_pdf
    command = "xvfb-run wkhtmltopdf -T 0 -B 0 -L 0 -R 0 --page-size Letter -O Landscape #{@cert_html} #{@cert_pdf}"

    Open3.expects(:popen3).with(command)

    CertificateWorker.convert_to_pdf(@cert_html, @cert_pdf)
  end

  def test_convert_to_pdf_failure
    command = "xvfb-run wkhtmltopdf -T 0 -B 0 -L 0 -R 0 --page-size Letter -O Landscape #{@cert_html} #{@cert_pdf}"

    sterr = mock()
    sterr.stubs(:gets).returns("error!")
    Open3.expects(:popen3)
         .with(command)
         .yields([mock(), mock(), sterr, mock()])

    assert_raises RuntimeError do
      CertificateWorker.convert_to_pdf(@cert_html, @cert_pdf)
    end
  end

  def test_compose_mail
    email = 'test@gmail.com'
    File.open(File.expand_path(@cert_pdf), 'w+')

    mail = CertificateWorker.compose_mail(email, @cert_pdf)

    assert_equal [email], mail.to
    assert_equal ['donotreply@ucdenver.edu'], mail.from
    assert mail.has_attachments?
    assert_equal 'cert.pdf', mail.attachments.first.filename
  end

end

