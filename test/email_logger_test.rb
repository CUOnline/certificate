require_relative './test_helper'
require_relative '../email_logger'

class EmailLoggerTest < Minitest::Test
  LOG_DIR = File.expand_path('test/log')
  LOG_NAME = 'test_email_log'

  def app
    EmailLogger
  end

  def delete_dir(dir)
    if Dir.exist?(dir)
      Dir[File.join(dir, '*')].each do |f|
        File.delete(f)
      end

      Dir.delete(dir)
    end
  end

  def setup
    EmailLogger.settings.stubs(:email_log_dir).returns(LOG_DIR)
    EmailLogger.settings.stubs(:email_log_name).returns(LOG_NAME)

    @log_file = File.join(LOG_DIR, LOG_NAME)
  end

  def teardown
    delete_dir(LOG_DIR)
  end

  def test_write_existing_dir_no_log
    delete_dir(LOG_DIR)
    refute Dir.exist?(LOG_DIR)

    EmailLogger.write('test@example.com')

    assert Dir.exist?(LOG_DIR)
    assert File.exist?(@log_file)
    assert_match /test@example.com/, File.read(@log_file)
  end

  def test_write_existing_dir_and_log
    Dir.mkdir(LOG_DIR) unless Dir.exist?(LOG_DIR)
    FileUtils.touch(@log_file) unless File.exist?(@log_file)
    assert File.exist?(@log_file)

    EmailLogger.write('test@example.com')

    assert_match /test@example.com/, File.read(@log_file)
  end

  def test_write_nonexistent_dir
    delete_dir(LOG_DIR)
    refute Dir.exist?(LOG_DIR)
  end

  def test_get_logs
    login
    get '/logs'
    assert_equal 200, last_response.status
  end

  def test_get_logs_unauthenticated
    get '/logs'
    assert_equal 302, last_response.status
  end

  def test_get_logs_unauthorized
    login({'user_roles' => ['StudentEnrollment']})
    get '/logs'
    assert_equal 302, last_response.status
  end

  def test_get_log
    log_name = EmailLogger.settings.email_log_name
    assert !File.exist?(@log_file)
    Dir.mkdir(LOG_DIR)
    File.open(@log_file, 'w') do |f|
      f.write('test@example.com')
    end
    assert File.exist?(@log_file)

    login
    get "/log/#{log_name}"
    assert_equal 200, last_response.status
    assert_nil last_response.headers['Content-Disposition']
    assert_match /test@example.com/, last_response.body
    File.delete(@log_file)
  end

  def test_get_log_download
    log_name = EmailLogger.settings.email_log_name
    assert !File.exist?(@log_file)
    Dir.mkdir(LOG_DIR)
    File.open(@log_file, 'w') do |f|
      f.write('test@example.com')
    end
    assert File.exist?(@log_file)

    login
    get "/log/#{log_name}?download=1"
    assert_equal 200, last_response.status
    assert_equal "attachment;filename=#{log_name}", last_response.headers['Content-Disposition']
    assert_match /test@example.com/, last_response.body
    File.delete(@log_file)
  end

  def test_get_nonexistent_log
    File.delete(@log_file) if File.exist?(@log_file)
    assert !File.exist?(@log_file)

    login
    get '/log/blah'
    assert_equal 404, last_response.status
  end

  def test_get_log_unauthenticated
    get '/log/blah'
    assert_equal 302, last_response.status
  end

  def test_get_log_unauthorized
    login({'user_roles' => ['StudentEnrollment']})
    get '/logs'
    assert_equal 302, last_response.status
  end
end
