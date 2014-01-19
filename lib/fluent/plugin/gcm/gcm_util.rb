module Fluent
    class GcmOutput::GcmUtil
        def unpack(record)
            dests = [ record['registration_id'] ].flatten
            dests.compact!

            headers = {}
            record.each{|k,v| k.to_s.start_with?('x-gcm-') && headers[k] = v }
            msg = record['body']
            [dests, headers, msg]
        end

        def send(gcm, dests, msg)
            if gcm == nil
                raise 'parameter <gcm> is required.'
            end

            if dests == nil || dests.class != Array || dests.size == 0
                raise 'parameter <dests> needs for not empty array.'
            end

            if msg == nil || msg.class != Hash || msg.size == 0
                raise 'parameter <msg> needs for not empty Hash.'
            end

            response = gcm.send_notification(dests , msg) || { :status_code => -1 , :response => 'response is empty.'}
            return [response[:status_code] , {} , response[:response]] if response[:status_code] != 200

            body = JSON.parse(response[:body] || '{}')
            body_results = body['results'] || []

            [ response[:status_code] , Hash[dests.zip(body_results)], response[:response] ]
        end

        def build_error_message(app_name, id, x_headers, result)
            app_name ||= 'Unknown App'
            
            if id && result['error']
                result["status_code"] = 200
                result['app_name'] = app_name
                result['registration_id'] = id
                if x_headers && x_headers.size > 0
                    result.merge!(x_headers)
                end

                return result
            end
            nil
        end
    end
end
