require 'bundler/setup'
require 'wolf_core'
require 'time'
require './certificate_worker'

class CertificateApp < WolfCore::App
  set :root, File.dirname(__FILE__)
  set :views, ["#{root}/views", settings.base_views]

  set :title, 'Certificate Generator'
  set :email_subject, 'Canvas Certificate'

  post '/' do
    @invalid_request = !valid_lti_request?(request, params)

    url = "courses/#{params['custom_canvas_course_id']}"\
          "/quizzes/#{params['custom_quiz_id']}/submissions"

    begin
      response = canvas_api(:get, url)
      submissions = response['json']['quiz_submissions']

      pages = parse_pages(response['headers'][:link])
      while pages['next']
        response = canvas_api(:get, '', {:url => pages['next']})
        submissions += response['json']['quiz_submissions']
        pages = parse_pages(response['headers'][:link])
      end

      passed_quizzes = submissions.select do |s|
        s['user_id'].to_s == params['custom_canvas_user_id'] &&
        s['kept_score'].to_i >= params['custom_score_req'].to_i
      end
    rescue RestClient::ResourceNotFound
      @invalid_quiz = true
    end

    if passed_quizzes && passed_quizzes.any?
      @pass = true
      @user_name = params['lis_person_name_full']
      @timestamp = Time.parse(passed_quizzes.first['finished_at']).strftime("%B %e, %Y")
      Resque.enqueue( CertificateWorker, (slim :certificate, :layout => false),
                      params['lis_person_contact_email_primary'] )
    end

    if @invalid_quiz || @invalid_request
      halt 400
    else
      slim :index, :layout => false
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
