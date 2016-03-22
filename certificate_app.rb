require 'bundler/setup'
require 'wolf'

class CertificateApp < Wolf::Base
  set :quiz_id, 1234
  set :email_subject, 'Academic Integrity Certificate'
  set :root, File.dirname(__FILE__)
  self.setup

  post '/' do
    headers 'X-Frame-Options' => "ALLOW_FROM #{settings.canvas_url}"

    query_string = %{
      SELECT score, user_dim.name
      FROM quiz_submission_fact
      JOIN user_dim
        ON user_dim.id = quiz_submission_fact.user_id
      WHERE user_dim.canvas_id = ?
        AND quiz_submission_fact.quiz_id = ? }

    cursor = settings.db.prepare(query_string)
    cursor.execute(params['custom_canvas_user_id'], settings.quiz_id)

    scores = []
    while row = cursor.fetch_hash
      scores << row['score']
      @name ||= row['name']
    end

    if scores.select{|s| s.to_i > 90}.any?
      @pass = true
      Resque.enqueue(CertificateWorker, (slim :certificate, :layout => false),
                     params['lis_person_contact_email_primary'])
    end

    slim :index, :layout => false
  end

  get '/' do
    headers 'Content-Type' => 'text/xml'
    slim :lti_config, :layout => false
  end
end
