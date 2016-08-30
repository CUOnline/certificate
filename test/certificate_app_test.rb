require_relative './test_helper'

class CertificateAppTest < Minitest::Test
  def teardown
    # Should be true for every request
    assert_equal "ALLOW-FROM https://ucdenver.test.instructure.com",
                  last_response.header['X-Frame-Options']
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
    course_id = '123'
    user_id = '456'
    quiz_id = '789'
    contact_email = 'test@gmail.com'
    api_response = {
      "quiz_submissions" => [{
        'user_id' => user_id,
        'kept_score' => 16,
        'finished_at' => '2016-04-06T19:42:43Z'
      }]
    }.to_json

    response = mock()
    response.stubs(:body).returns(api_response)
    response.stubs(:headers).returns({:link => ''})

    Resque.expects(:enqueue).with(CertificateWorker, anything, contact_email)
    app.any_instance.expects(:valid_lti_request?).returns(true)
    api_url = "courses/#{course_id}/quizzes/#{quiz_id}/submissions"
    app.any_instance.expects(:canvas_api)
                    .with(:get, api_url, {:raw => true})
                    .returns(response)

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
    course_id = '123'
    user_id = '456'
    quiz_id = '789'
    contact_email = 'test@gmail.com'

    api_response = {
      "quiz_submissions" => [{
        'user_id' => user_id,
        'kept_score' => 14,
        'finished_at' => '2016-04-06T19:42:43Z'
      }]
    }.to_json

    response = mock()
    response.stubs(:body).returns(api_response)
    response.stubs(:headers).returns({:link => ''})

    Resque.expects(:enqueue).never
    app.any_instance.expects(:valid_lti_request?).returns(true)

    api_url = "courses/#{course_id}/quizzes/#{quiz_id}/submissions"
    app.any_instance.expects(:canvas_api)
                    .with(:get, api_url, {:raw => true})
                    .returns(response)

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
    contact_email = 'test@gmail.com'

    Resque.expects(:enqueue).never
    app.any_instance.expects(:valid_lti_request?).returns(true)
    api_url = "courses/#{course_id}/quizzes/#{quiz_id}/submissions"
    app.any_instance.expects(:canvas_api)
                    .with(:get, api_url, {:raw => true})
                    .raises(RestClient::ResourceNotFound)

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
    contact_email = 'test@gmail.com'
    api_response = {
      "quiz_submissions" => [{
        'user_id' => user_id,
        'kept_score' => 14,
        'finished_at' => '2016-04-06T19:42:43Z'
      }]
    }.to_json

    response = mock()
    response.stubs(:body).returns(api_response)
    response.stubs(:headers).returns({:link => ''})

    Resque.expects(:enqueue).never
    app.any_instance.expects(:valid_lti_request?).returns(false)
    api_url = "courses/#{course_id}/quizzes/#{quiz_id}/submissions"
    app.any_instance.expects(:canvas_api)
                    .with(:get, api_url, {:raw => true})
                    .returns(response)

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
    contact_email = 'test@gmail.com'
    api_response = {
      "quiz_submissions" => [{
        'user_id' => user_id,
        'kept_score' => 6,
        'finished_at' => '2015-01-05T19:40:40Z'
      }]
    }.to_json
    first_response = mock()
    first_response.stubs(:body).returns(api_response)
    first_response.stubs(:headers).returns({:link => '<page1>; rel="current", <page2>; rel="next"'})

    api_response = {
      "quiz_submissions" => [{
        'user_id' => user_id,
        'kept_score' => 16,
        'finished_at' => '2016-04-06T19:42:43Z'
      }]
    }.to_json
    second_response = mock()
    second_response.stubs(:body).returns(api_response)
    second_response.stubs(:headers).returns({:link => ''})

    Resque.expects(:enqueue).with(CertificateWorker, anything, contact_email)
    app.any_instance.expects(:valid_lti_request?).returns(true)
    app.any_instance.expects(:canvas_api).twice
                    .returns(first_response).then.returns(second_response)

    post '/', {
      'custom_canvas_course_id' => course_id,
      'custom_canvas_user_id' => user_id,
      'custom_quiz_id' => '789',
      'custom_score_req' => '15',
      'lis_person_contact_email_primary' => contact_email
    }

    assert_equal 200, last_response.status
    assert_match /Your certificate is being generated/, last_response.body
  end

end
