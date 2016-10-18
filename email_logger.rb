class EmailLogger < WolfCore::App
  set :email_log_dir, 'log'
  set :email_log_name, 'email_log'
  set :root, File.dirname(__FILE__)
  set :auth_paths, [/log(s)?/]

  def self.log_file
    File.join(settings.email_log_dir, settings.email_log_name)
  end

  def self.create_log_file
    unless Dir.exist?(settings.email_log_dir)
      Dir.mkdir(settings.email_log_dir)
    end

    unless File.exist?(self.log_file)
      File.open(self.log_file, 'w') {|f| f.write('')}
    end
  end

  def self.write(email)
    begin
      self.create_log_file
      logger = Logger.new(self.log_file)
      logger.info(email)
    rescue StandardError => e
      STDERR.puts "Error logging certificate email: #{email}:\n"
      STDERR.puts e.inspect
    end
  end

  get '/logs' do
    log_files = Dir["#{EmailLogger.log_file}*"]
    if params['search-term'] && !params['search-term'].empty?
      logs = []
      log_files.each do |log|
        File.foreach(log) do |line|
          logs << log if line =~/#{params['search-term']}/
        end
      end
    end

    logs ||= log_files
    slim :logs, :locals => {:logs => logs.uniq.map{|l| l.split('/').last}}
  end

  get '/log/:log_name' do
    log_name = URI.decode(params[:log_name])
    file = File.join(settings.email_log_dir, log_name)

    if File.exist?(file)
      content_type 'text/plain'
      if params['download']
        response.headers['Content-Disposition'] = "attachment;filename=#{log_name}"
      end

      send_file file
    else
      status 404
    end
  end
end
