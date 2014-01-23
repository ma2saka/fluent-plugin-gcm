require 'helper'

class GcmOutputTest < Test::Unit::TestCase
  def setup
    Fluent::Test.setup
    RR.reset
  end

  CONFIG = %[
  ]

  def create_driver(conf = CONFIG, tag = 'test.test')
    Fluent::Test::BufferedOutputTestDriver.new(Fluent::GcmOutput, tag).configure(conf)
  end

  def test_configure_with_all_params
    d = create_driver %[
        api_key Gray
        app_name SoldierQueey
        result_tag_suffix .hello
        result_tag_prefix yahoo.
    ]
    assert_equal 'Gray' , d.instance.api_key
    assert_equal 'SoldierQueey' , d.instance.app_name
    assert_equal '.hello' , d.instance.result_tag_suffix
    assert_equal 'yahoo.' , d.instance.result_tag_prefix
  end
  def test_configure_with_require_params
    d = create_driver %[
        api_key Gray
        app_name Roza
    ]
    assert_equal 'Gray' , d.instance.api_key
    assert_equal 'Roza' , d.instance.app_name
    assert_equal '.gcm.result' , d.instance.result_tag_suffix
    assert_equal nil , d.instance.result_tag_prefix
  end

  def test_configure_without_params
    assert_raise(Fluent::ConfigError) do
        d = create_driver %[
            app_name Dandy
        ]
    end
  end

  def test_format
    d = create_driver %[
        api_key Jango
        app_name TreasureStar
    ]

    time = Time.parse("2011-01-02 13:14:15 UTC").to_i
    d.emit({"a"=>"abc1"}, time)
    d.emit({"a"=>"abc2"}, time + 1)
    d.emit({"a"=>"abc3"}, time + 2)

    d.expect_format ["test.test" , time,  { "a" => "abc1", "time"=> "2011-01-02T13:14:15Z"}].to_msgpack
    d.expect_format ["test.test" , time + 1,  { "a" => "abc2", "time"=> "2011-01-02T13:14:15Z"}].to_msgpack
    d.expect_format ["test.test" , time + 2,  { "a" => "abc3", "time"=> "2011-01-02T13:14:15Z"}].to_msgpack
  end

  def test_write_miss1
    d = create_driver %[
        api_key Marry
        app_name JumpingJackFlash
    ]

    any_instance_of(::Fluent::GcmOutput::GcmUtil) do |k|
      stub(k).send.with_any_args{|*args|
        [ 200, { "a"=> {"error" => "death star"} , "b" => "b_result"} , {} ]
      }
    end
    
    mock(Fluent::Engine).emit.with_any_args{|*args|
        assert_equal 'test.test.gcm.result', args[0]
        assert_equal Fixnum, args[1].class
        assert_equal 200, args[2]["status_code"]
        assert_equal "death star", args[2]["error"]
        assert_equal "a", args[2]["registration_id"]
        assert_equal "JumpingJackFlash", args[2]["app_name"]
    }

    time = Time.parse("2011-01-02 13:14:15 UTC").to_i

    d.emit({"registration_id" => [ "a", "b"], "body" => { "data" => { :message => "hello world" }}}, time)
    d.run
  end

  def test_write_miss2
    d = create_driver %[
        api_key Marry
        app_name JumpingJackFlash
        result_tag_suffix .result
    ]

    any_instance_of(::Fluent::GcmOutput::GcmUtil) do |k|
      stub(k).send.with_any_args{|*args|
        [ 200, { "a"=> {"error" => "death star"} , "b" => { "error" => "x wing"}} , {} ]
      }
    end
    
    mock(Fluent::Engine).emit.with_any_args{|*args|
        assert_equal 'test.test.result', args[0]
        assert_equal Fixnum, args[1].class
        assert_equal 200, args[2]["status_code"]
        assert_equal "death star", args[2]["error"]
        assert_equal "a", args[2]["registration_id"]
        assert_equal "JumpingJackFlash", args[2]["app_name"]
    }

    mock(Fluent::Engine).emit.with_any_args{|*args|
        assert_equal 'test.test.result', args[0]
        assert_equal Fixnum, args[1].class
        assert_equal 200, args[2]["status_code"]
        assert_equal "x wing", args[2]["error"]
        assert_equal "b", args[2]["registration_id"]
        assert_equal "JumpingJackFlash", args[2]["app_name"]
    }

    time = Time.parse("2011-01-02 13:14:15 UTC").to_i

    d.emit({"registration_id" => [ "a", "b"], "body" => { "data" => { :message => "hello world" }}}, time)
    d.run
  end

  def test_write_not_success
    d = create_driver %[
        api_key Marry
        app_name JumpingJackFlash
    ]

    any_instance_of(::Fluent::GcmOutput::GcmUtil) do |k|
      stub(k).send.with_any_args{|*args|
        [ 401, { "a"=> {"error" => "death star"} , "b" => { "error" => "x wing"}} , "Leia" ]
      }
    end
    
    mock(Fluent::Engine).emit.with_any_args{|*args|
        assert_equal 'test.test.gcm.result', args[0]
        assert_equal Fixnum, args[1].class
        assert_equal 401, args[2]["status_code"]
        assert_equal String, args[2]["error"].class
        assert_equal "Leia", args[2]["error"]
        assert_equal ["a","b"], args[2]["registration_id"]
        assert_equal "JumpingJackFlash", args[2]["app_name"]
        assert_equal "Java", args[2]["x-gcm-title"]
    }

    time = Time.parse("2011-01-02 13:14:15 UTC").to_i

    d.emit({"x-gcm-title" => "Java",  "registration_id" => [ "a", "b"], "body" => {"data" => { :message => "hello world" }}}, time)
    d.run
  end

  def test_write_http_error
    d = create_driver %[
        api_key Marry
        app_name JumpingJackFlash
        result_tag_prefix sonorama.
    ]

    any_instance_of(::Fluent::GcmOutput::GcmUtil) do |k|
      mock(k).send.with_any_args{|*args|
          require 'httparty'
          raise HTTParty::ResponseError.new("response")
      }
    end
    
    mock(Fluent::Engine).emit.with_any_args{|*args|
        assert_equal 'sonorama.test.test.gcm.result', args[0]
        assert_equal Fixnum, args[1].class
        assert_equal 999, args[2]["status_code"]
        assert_equal String, args[2]["error"].class
        assert_equal "HTTParty::ResponseError", args[2]["error"]
        assert_equal ["a","b"], args[2]["registration_id"]
        assert_equal "JumpingJackFlash", args[2]["app_name"]
        assert_equal "c3po", args[2]["x-gcm-user"]
    }

    time = Time.parse("2011-01-02 13:14:15 UTC").to_i

    d.emit({"x-gcm-user" => "c3po" ,"registration_id" => [ "a", "b"], "body" => {"data" => { "message" => "Use the force!" }}}, time)
    d.run
  end

  def test_write_success
    d = create_driver %[
        api_key Marry
        app_name JumpingJackFlash
    ]

    any_instance_of(::Fluent::GcmOutput::GcmUtil) do |k|
      mock(k).send.with_any_args{|*args|
        assert_equal GCM, args[0].class
        assert_equal ["a", "b"] , args[1]
        assert_equal Hash , args[2].class
        assert_equal nil , args[2]["x-gcm-user"]
        assert_equal "Use the force!" , args[2]["data"]["message"]

        [ 200, { "a"=> "a_result" , "b" => "b_result"} , {} ]
      }
    end
    
    dont_allow(Fluent::Engine).emit

    time = Time.parse("2011-01-02 13:14:15 UTC").to_i

    d.emit({"x-gcm-user" => "c3po" ,"registration_id" => [ "a", "b"], "body" => { "data" => { "message" => "Use the force!" }}}, time)
    d.run
  end

  def test_write_success_with_result_suffix_prefix
    d = create_driver %[
        api_key Marry
        app_name JumpingJackFlash
        result_tag_suffix .gcm
        result_tag_prefix sonorama.
    ]

    any_instance_of(::Fluent::GcmOutput::GcmUtil) do |k|
      mock(k).send.with_any_args{|*args|
        assert_equal GCM, args[0].class
        assert_equal ["a", "b"] , args[1]
        assert_equal Hash , args[2].class
        assert_equal nil , args[2]["x-gcm-user"]
        assert_equal "Use the force!" , args[2]["data"]["message"]

        [ 200, { "a"=> "a_result" , "b" => "b_result"} , {} ]
      }
    end
    
    dont_allow(Fluent::Engine).emit

    time = Time.parse("2011-01-02 13:14:15 UTC").to_i

    d.emit({"x-gcm-user" => "c3po" ,"registration_id" => [ "a", "b"], "body" => { "data" => { "message" => "Use the force!" }}}, time)
    d.run
  end
end

