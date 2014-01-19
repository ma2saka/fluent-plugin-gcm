class Fluent::GcmOutput < Fluent::BufferedOutput
  SUCCESS=200
  PLUGIN_ERROR=999

  Fluent::Plugin.register_output('gcm', self)

  attr_accessor :gcm_client
  
  config_param :api_key, :string
  config_param :app_name, :string

  include Fluent::SetTagKeyMixin
  config_set_default :include_tag_key, false

  include Fluent::SetTimeKeyMixin
  config_set_default :include_time_key, true

  def initialize
    super
    require 'msgpack'
    require 'gcm'
    require File.dirname(__FILE__) + '/gcm/gcm_util'
    @gcm_util = GcmUtil.new
  end

  def configure(conf)
    super
    @api_key = conf['api_key']
    @app_name = conf['app_name']
  end

  def start
    super
    @gcm_client = GCM.new(@api_key)
  end

  def shutdown
    super
    @gcm_util = nil
    @gcm_client = nil
  end

  def format(tag, time, record)
    [tag, time, record].to_msgpack
  end

  def format_result_tag(tag)
    "#{tag}.gcm.result"
  end

  def write(chunk)
    $log.info("write start!")
    records = []

    chunk.msgpack_each do |records|
        unless @gcm_client
            next
        end
        tag, time, record = records
        new_tag = format_result_tag(tag)
        dests, x_headers, msg = @gcm_util.unpack(record)
        begin 
            code, results, response = @gcm_util.send(@gcm_client, dests, msg)
        rescue => e
            transfer_record = { "status_code" => PLUGIN_ERROR, "app_name" => @app_name, "error" => e.to_s , "registration_id" => dests}.merge(x_headers)
            Fluent::Engine.emit(new_tag, time, transfer_record)
            $log.error(e)
            next
        end

        if code == SUCCESS
            results.each do | id , result |
                if error_object = @gcm_util.build_error_message(@app_name, id, x_headers, result)
                    Fluent::Engine.emit(new_tag, time, error_object)
                else
                    records << id
                end
            end
        else
            transfer_record = { "status_code" => code, "app_name" => @app_name, "error" => response, "registration_id" => dests}.merge(x_headers)
            Fluent::Engine.emit(new_tag, time, transfer_record)
        end
    end
    records
  end
end

