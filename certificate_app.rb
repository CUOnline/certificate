require 'wolf'

class CertificateApp < Wolf::Base
  set :quiz_id, 1234
  set :root, File.dirname(__FILE__)
  self.setup

  post '/' do
    headers 'X-Frame-Options' => "ALLOW_FROM #{settings.canvas_url}"

    query_string = %{
      SELECT score, user_dim.name
      FROM quiz_submission_dim
      JOIN user_dim
        ON user_dim.id = quiz_submission_dim.user_id
      WHERE user_dim.canvas_id = ?
        AND quiz_submission_dim.quiz_id = ? }

    cursor = settings.db.prepare(query_string)
    cursor.execute(params['custom_canvas_user_id'], settings.quiz_id)

    scores = []
    while row = cursor.fetch_hash
      scores << row['score']
      name ||= row['name']
    end

    if scores.select{|s| s.to_i > 90}.any?
      @pass = true
      Resque.enqueue(CertificateWorker, name)
    end

    slim :index
  end

  get '/' do
    headers 'Content-Type' => 'text/xml'
    slim :lti_config
  end
end
