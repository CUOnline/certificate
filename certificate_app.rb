require 'bundler/setup'
require 'wolf_core'
require 'time'

require_relative './certificate_worker'

class CertificateApp < WolfCore::App
  set :title, 'Certificate Generator'
  set :email_subject, 'Canvas Certificate'
  set :root, File.dirname(__FILE__)
  set :api_cache, ActiveSupport::Cache::RedisStore.new(redis_options.merge({:expires_in => 300}))

  helpers do
    def errors_for_param(key, params)
      errors = []
      formatted_key = key.gsub('_', ' ').capitalize
      if params[key].nil? || params[key].empty?
        errors << "#{formatted_key} is required"
      elsif params[key].to_i <= 0
        errors << "#{formatted_key} must be a positive integer"
      end
      errors
    end

    def quiz_exists?(quiz_id)
      canvas_data("SELECT id FROM quiz_dim WHERE canvas_id = ?", quiz_id).any?
    end
  end

  post '/' do
    @invalid_request = !valid_lti_request?(request, params)

    url = "courses/#{params['custom_canvas_course_id']}"\
          "/quizzes/#{params['custom_quiz_id']}/submissions?per_page=100"

    response = canvas_api.get(url)
    if response.status == 404
      @invalid_quiz = true
    end

    halt 400 if @invalid_request || @invalid_quiz

    submissions = response.body['quiz_submissions']
    pages = parse_pages(response.headers[:link] || '')
    while pages['next']
      response = canvas_api.get(pages['next'])
      submissions += response.body['quiz_submissions']
      pages = parse_pages(response.headers[:link])
    end

    passed_quizzes = submissions.select do |s|
      s['user_id'].to_s == params['custom_canvas_user_id'] &&
      s['kept_score'].to_i >= params['custom_score_req'].to_i
    end

    if passed_quizzes && passed_quizzes.any?
      @pass = true
      @user_name = params['lis_person_name_full']

      quiz_time = passed_quizzes.first['finished_at'] || passed_quizzes.first['started_at']
      @timestamp = Time.parse(quiz_time).strftime("%B %e, %Y")

      Resque.enqueue( CertificateWorker, (slim :certificate, :layout => false),
                      params['lis_person_contact_email_primary'] )
    end

    slim :index, :layout => false
  end

  get '/generate-config' do
    slim :generate_config
  end

  post '/generate-config' do
    errors = [
      errors_for_param('quiz_id', params),
      errors_for_param('score_requirement', params)
    ].flatten

    # Only check quiz existence if ID format validation passes
    if errors.empty? && !quiz_exists?(params['quiz_id'])
      errors << "Quiz with specified ID not found. Note that it may take up to 48 "\
                "hours for a newly created quiz to show up in the database."
    end

    if errors.any?
      flash[:danger] = errors.join("\n<br/>")
      redirect "#{mount_point}/generate-config"
    else
      redirect "#{mount_point}/lti_config/#{params['quiz_id']}/#{params['score_requirement']}"
    end
  end

  get '/lti_config/:quiz_id/:score_req' do
    if params[:quiz_id].to_i < 1 || params[:score_req].to_i < 1
      halt 400
    end

    headers 'Content-Type' => 'text/xml'
    slim :lti_config, :layout => false
  end

  error 400 do
    slim :config_error, :layout => false
  end

  before do
    headers 'X-Frame-Options' => "ALLOW-FROM #{settings.canvas_url}"
  end
end
