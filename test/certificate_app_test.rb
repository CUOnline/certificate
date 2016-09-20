require_relative './test_helper'

class CertificateAppTest < Minitest::Test
  def teardown
    # Should be true for every request
    assert_equal "ALLOW-FROM #{@canvas_url}", last_response.header['X-Frame-Options']
  end

  def test_get_lti_config
    get '/lti_config/123/15'
    assert_equal 200, last_response.status
    assert_equal 'text/xml', last_response.header['Content-Type']
  end

  def test_get_lti_config_invalid_quiz_id
    get '/lti_config/abc/15'
    assert_equal 400, last_response.status
  end

  def test_get_lti_config_invalid_score_req
    get '/lti_config/123/ab'
    assert_equal 400, last_response.status
  end

  def test_get_lti_config_invalid_params
    get '/lti_config/abc/ab'
    assert_equal 400, last_response.status
  end

  def test_post_passed_reqs
    WebMock.reset!
    course_id = '123'
    user_id = '456'
    quiz_id = '789'
    contact_email = 'test@example.com'
    response = {
      "quiz_submissions" => [{
        'user_id' => user_id,
        'kept_score' => 16,
        'finished_at' => '2016-04-06T19:42:43Z'
      }]
    }

    Resque.expects(:enqueue).with(CertificateWorker, anything, contact_email)
    app.any_instance.expects(:valid_lti_request?).returns(true)
    stub_request(:get, /courses\/#{course_id}\/quizzes\/#{quiz_id}\/submissions/)
      .to_return(:body => response.to_json, :headers => {'Content-Type' => 'application/json'}, :status => 200)

    post '/', {
      'custom_canvas_course_id' => course_id,
      'custom_canvas_user_id' => user_id,
      'custom_quiz_id' => quiz_id,
      'custom_score_req' => '15',
      'lis_person_contact_email_primary' => contact_email
    }

    assert_equal 200, last_response.status
    assert_match /Your certificate is being generated/, last_response.body
  end

  def test_post_failed_reqs
    WebMock.reset!
    course_id = '123'
    user_id = '456'
    quiz_id = '789'
    contact_email = 'test@example.com'

    response = {
      "quiz_submissions" => [{
        'user_id' => user_id,
        'kept_score' => 14,
        'finished_at' => '2016-04-06T19:42:43Z'
      }]
    }

    Resque.expects(:enqueue).never
    app.any_instance.expects(:valid_lti_request?).returns(true)

    stub_request(:get, /courses\/#{course_id}\/quizzes\/#{quiz_id}\/submissions/)
      .to_return(:body => response.to_json, :headers => {'Content-Type' => 'application/json'}, :status => 200)

    post '/', {
      'custom_canvas_course_id' => course_id,
      'custom_canvas_user_id' => user_id,
      'custom_quiz_id' => quiz_id,
      'custom_score_req' => '15',
      'lis_person_contact_email_primary' => contact_email
    }

    assert_equal 200, last_response.status
    assert_match /you must complete/, last_response.body
  end

  def test_post_invalid_quiz_id
    course_id = '123'
    user_id = '456'
    quiz_id = '789'
    contact_email = 'test@example.com'

    Resque.expects(:enqueue).never
    app.any_instance.expects(:valid_lti_request?).returns(true)
    stub_request(:get, /courses\/#{course_id}\/quizzes\/#{quiz_id}\/submissions/)
      .to_return(:status => 404)

    post '/', {
      'custom_canvas_course_id' => course_id,
      'custom_canvas_user_id' => user_id,
      'custom_quiz_id' => quiz_id,
      'custom_score_req' => '15',
      'lis_person_contact_email_primary' => contact_email
    }

    assert_equal 400, last_response.status
    assert_match /The certificate tool may be misconfigured/, last_response.body
  end

  def test_post_invalid_lti_request
    course_id = '123'
    user_id = '456'
    quiz_id = '789'
    contact_email = 'test@example.com'
    response = {
      "quiz_submissions" => [{
        'user_id' => user_id,
        'kept_score' => 14,
        'finished_at' => '2016-04-06T19:42:43Z'
      }]
    }

    Resque.expects(:enqueue).never
    app.any_instance.expects(:valid_lti_request?).returns(false)
    stub_request(:get, /courses\/#{course_id}\/quizzes\/#{quiz_id}\/submissions/)
      .to_return(:body => response.to_json)

    post '/', {
      'custom_canvas_course_id' => course_id,
      'custom_canvas_user_id' => user_id,
      'custom_quiz_id' => quiz_id,
      'custom_score_req' => '15',
      'lis_person_contact_email_primary' => contact_email
    }

    assert_equal 400, last_response.status
    assert_match /The certificate tool may be misconfigured/, last_response.body
  end

  def test_post_paginated_response
    course_id = '123'
    user_id = '456'
    quiz_id = '789'
    contact_email = 'test@example.com'
    first_page_response = {
      "quiz_submissions" => [{
        'user_id' => user_id,
        'kept_score' => 6,
        'finished_at' => '2015-01-05T19:40:40Z'
      }]
    }

    second_page_response = {
      "quiz_submissions" => [{
        'user_id' => user_id,
        'kept_score' => 16,
        'finished_at' => '2016-04-06T19:42:43Z'
      }]
    }

    Resque.expects(:enqueue).with(CertificateWorker, anything, contact_email)
    app.any_instance.expects(:valid_lti_request?).returns(true)

    stub_request(:get, /courses\/#{course_id}\/quizzes\/#{quiz_id}\/submissions/)
      .to_return(:body => first_page_response.to_json,
                 :headers => {
                   'Content-Type' => 'application/json',
                   'link' => '<page1>; rel="current", <page2>; rel="next"'
                  })


    stub_request(:get, /page2/)
      .to_return(:body => second_page_response.to_json,
                 :headers => {
                   'Content-Type' => 'application/json',
                   'link' => ''
                  })


    post '/', {
      'custom_canvas_course_id' => course_id,
      'custom_canvas_user_id' => user_id,
      'custom_quiz_id' => quiz_id,
      'custom_score_req' => '15',
      'lis_person_contact_email_primary' => contact_email
    }

    assert_equal 200, last_response.status
    assert_match /Your certificate is being generated/, last_response.body
  end

end
