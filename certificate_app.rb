require 'bundler/setup'
require 'wolf_core'
require 'time'

class CertificateApp < WolfCore::App
  set :root, File.dirname(__FILE__)
  self.setup

  set :quiz_id, 1234
  set :email_subject, 'Academic Integrity Certificate'

  post '/' do
    @course_id = params['custom_canvas_course_id']
    url = "courses/#{@course_id}/quizzes/#{settings.quiz_id}/submissions"

    passed_quizzes = canvas_api(:get, url)["quiz_submissions"].select do |s|
      s['user_id'].to_s == params['custom_canvas_user_id'] &&
      s['kept_score'].to_i >= 14
    end

    if passed_quizzes.any?
      @pass = true
      @name = params['lis_person_name_full']
      @timestamp = Time.parse(passed_quizzes.first['finished_at'])
      Resque.enqueue(CertificateWorker, (slim :certificate, :layout => false),
                     params['lis_person_contact_email_primary'])
    end

    headers 'X-Frame-Options' => "ALLOW_FROM #{settings.canvas_url}"
    slim :index, :layout => false
  end

  get '/' do
    headers 'Content-Type' => 'text/xml'
    slim :lti_config, :layout => false
  end
end
