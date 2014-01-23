class Fluent::GcmOutput < Fluent::BufferedOutput
  SUCCESS=200
  PLUGIN_ERROR=999

  Fluent::Plugin.register_output('gcm', self)
  
  config_param :api_key, :string
  config_param :app_name, :string
  config_param :result_tag_prefix, :string, :default => nil
  config_param :result_tag_suffix, :string, :default => '.gcm.result'

  include Fluent::SetTagKeyMixin
  config_set_default :include_tag_key, false

  include Fluent::SetTimeKeyMixin
  config_set_default :include_time_key, true

  def initialize
    super
    require 'msgpack'
    require 'gcm'
    require File.dirname(__FILE__) + '/gcm/gcm_util'
  end

  def configure(conf)
    super
  end

  def start
    super
    @gcm_util = GcmUtil.new
    @gcm_client = GCM.new(@api_key)
  end

  def shutdown
    super
  end

  def format(tag, time, record)
    [tag, time, record].to_msgpack
  end

  def format_result_tag(tag)
    "#{@result_tag_prefix}#{tag}#{@result_tag_suffix}"
  end

  def write(chunk)
    records_s = 0
    records_f = 0

    chunk.msgpack_each do |records|
        tag, time, record = records
        new_tag = format_result_tag(tag)
        dests, x_headers, msg = @gcm_util.unpack(record)

        begin 
            code, results, response = @gcm_util.send(@gcm_client, dests, msg)
        rescue => e
            records_f += dests.size if dests
            transfer_record = { "status_code" => PLUGIN_ERROR, 
                                "app_name" => @app_name, 
                                "error" => e.to_s , 
                                "registration_id" => dests}.merge(x_headers)
            Fluent::Engine.emit(new_tag, time, transfer_record)
            $log.error(e)
            next
        end

        if code == SUCCESS
            results.each do | id , result |
                if error_object = @gcm_util.build_error_message(@app_name, id, x_headers, result)
                    records_f+=1
                    Fluent::Engine.emit(new_tag, time, error_object)
                else
                    records_s+=1
                end
            end
        else
            records_f += dests.size if dests
            transfer_record = { "status_code" => code, 
                                "app_name" => @app_name, 
                                "error" => response, 
                                "registration_id" => dests}.merge(x_headers)
            Fluent::Engine.emit(new_tag, time, transfer_record)
        end
    end
    $log.debug("[gcm_summary] app:#{@app_name}; success:#{records_s}; failure:#{records_f}")
  end
end

