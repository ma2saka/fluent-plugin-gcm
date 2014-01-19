require 'helper'
require 'rr'

class GcmUtilTest < Test::Unit::TestCase
  def setup
    super
  end

  def driver
    ::Fluent::GcmOutput::GcmUtil.new
  end

  def test_unpack_regid1
    g = driver

    results = g.unpack( {'registration_id' => "knight", "data" => "jedi", "x-gcm-title" => "return of the jedi"}  )

    assert_equal Array, results.class
    assert_equal Array, results[0].class
    assert_equal "knight", results[0][0]
  end

  def test_unpack_regid2
    g = driver

    results = g.unpack( {'registration_id' => ["dark", "knight"], "data" => "jedi", "x-gcm-title" => "return of the jedi"}  )

    assert_equal Array, results.class
    assert_equal Array, results[0].class
    assert_equal "dark", results[0][0]
    assert_equal "knight", results[0][1]
    assert_equal 2, results[0].size
  end

  def test_unpack_regid3
    g = driver

    results = g.unpack( {'registration_id' => nil, "data" => "jedi", "x-gcm-title" => "return of the jedi"}  )

    assert_equal Array, results.class
    assert_equal Array, results[0].class
    assert_equal 0, results[0].size
  end

  def test_unpack_header1
    g = driver

    results = g.unpack( {'registration_id' => "knight", "body" => { "data" => "jedi" }, "x-gcm-title" => "return of the jedi"}  )

    assert_equal Hash, results[1].class
    assert_equal 1, results[1].size
    assert_equal "return of the jedi", results[1]['x-gcm-title']
  end

  def test_unpack_header2
    g = driver

    results = g.unpack( {'registration_id' => "knight", "body"=> {"data" => "jedi"} , "x-gcm-title" => "return of the jedi" , "x-gcm-age" => 100}  )

    assert_equal Hash, results[1].class
    assert_equal 2, results[1].size
    assert_equal 100, results[1]['x-gcm-age']
  end

  def test_unpack_header3
    g = driver

    results = g.unpack( {'registration_id' => "knight", "body" => {"data" => "jedi", "age"=> 100}}  )

    assert_equal Hash , results[1].class
    assert_equal 0,  results[1].size
  end

  def test_unpack_msg1
    g = driver

    results = g.unpack( {'registration_id' => "knight", "body" => { "data" => "jedi", "age"=> 100}}  )

    assert_equal "jedi" , results[2]["data"]
  end

  def test_unpack_msg2
    g = driver

    results = g.unpack( {'registration_id' => "knight", "body" => { "data" => nil, "age"=> 100}}  )

    assert_equal nil , results[2]["data"]
  end

  def test_unpack_msg3
    g = driver

    results = g.unpack( {'registration_id' => "knight", "body" => { "data" => { :message => 'Leia'}}, "x-gcm-hogehoge"=> 100}  )

    assert_equal Hash , results[2].class
    assert_equal 1 , results[2].size
    assert_equal "Leia" , results[2]["data"][:message]
  end

  def test_unpack_msg4
    g = driver

    results = g.unpack( {'registration_id' => "knight", "x-gcm-hogehoge"=> 100}  )

    assert_equal nil , results[2]
  end

  def test_unpack_result
    g = driver
    dests, headers, data = g.unpack( {'registration_id' => "knight","body"=> { "data" => { :message => 'Leia'}}, "x-gcm-hogehoge"=> 100}  )

    assert_equal "knight" ,dests[0]
    assert_equal "Leia" ,data["data"][:message]
    assert_equal 100 ,headers["x-gcm-hogehoge"]
  end

  def client
    Object.new
  end

  def test_send_simple
    c = client
    g = driver
    mock(c).send_notification([1999], {:data=>"Falcon"}){ { :status_code => 200 , :body => '{"results" : [ 100 ] }', :response => "Han Solo"} }

    results = g.send(c, [1999] , { :data => "Falcon"})

    assert_equal Array, results.class
    assert_equal 3, results.size

    assert_equal 200, results[0]

    assert_equal Hash , results[1].class
    assert_equal 100 , results[1][1999]

    assert_equal "Han Solo",  results[2]
  end

  def test_send_id1
    c = client
    g = driver
    mock(c).send_notification([1999, 2000, "Millennium"], {:data=>"Falcon"}){ { :status_code => 200 , :body => '{"results" : [ 100 , 101, 102] }', :response => "Han Solo"} }

    results = g.send(c, [1999, 2000, "Millennium"] , { :data => "Falcon"})

    assert_equal Array, results.class
    assert_equal 3, results.size

    assert_equal 200, results[0]

    assert_equal Hash , results[1].class
    assert_equal 100 , results[1][1999]
    assert_equal 101 , results[1][2000]
    assert_equal 102 , results[1]["Millennium"]
    assert_equal 3, results[1].size

    assert_equal "Han Solo",  results[2]
  end


  def test_send_response1
    c = client
    g = driver
    mock(c).send_notification([1999, 2000, "Millennium"], {:data=>"Falcon"}){ { :status_code => 300 , :body => '{"results" : [ 100 , 101, 102] }', :response => "Han Solo"} }

    results = g.send(c, [1999,2000,"Millennium"] , { :data => "Falcon"})

    assert_equal Array, results.class
    assert_equal 3, results.size

    assert_equal 300, results[0]

    assert_equal Hash , results[1].class
    assert_equal 0, results[1].size

    assert_equal "Han Solo",  results[2]
  end

  def test_send_response2
    c = client
    g = driver
    mock(c).send_notification([1999, 2000, "Millennium"], {:data=>"Falcon"}){ { :status_code => 200 , :body => '{"results" : [ 100 , 101, 102] }', :response => nil} }

    results = g.send(c, [1999,2000,"Millennium"] , { :data => "Falcon"})

    assert_equal nil,  results[2]
  end

  def test_send_response3
    c = client
    g = driver
    mock(c).send_notification([1999, 2000, "Millennium"], {:data=>"Falcon"}){ { :status_code => 200 , :body => nil, :response => nil} }

    results = g.send(c, [1999,2000,"Millennium"] , { :data => "Falcon"})

    assert_equal Hash , results[1].class
    assert_equal nil , results[1][1999]
    assert_equal nil , results[1][2000]
    assert_equal nil , results[1]["Millennium"]
    assert_equal 3, results[1].size

    assert_equal nil,  results[2]
  end

  def test_send_response4
    c = client
    g = driver
    mock(c).send_notification([1999, 2000, "Millennium"], {:data=>"Falcon"}){ nil }

    results = g.send(c, [1999,2000,"Millennium"] , { :data => "Falcon"})

    assert_equal -1,  results[0]
    assert_equal( {}, results[1])
    assert_equal 'response is empty.', results[2]
  end

end
