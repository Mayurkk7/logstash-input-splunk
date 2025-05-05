# encoding: utf-8
require "logstash/inputs/base"
require "stud/interval"
require 'net/http'
require 'uri'
require 'openssl'
require 'json'

class LogStash::Inputs::Splunk < LogStash::Inputs::Base

  config_name "splunk"

  config :splunk_url, :validate => :string, :required => true
  config :username, :validate => :string, :required => true
  config :password, :validate => :string, :required => true
  config :index, :validate => :string, :required => true
  config :fetch_offset_limit, :validate => :number, :default => 50
  config :max_fetch_size_in_mb, :validate => :number, :default => 10

  public
  def register

    url = URI.parse("#{@splunk_url}/services/auth/login")
    @http = Net::HTTP.new(url.host, url.port)
    @http.use_ssl = true
    @http.verify_mode = OpenSSL::SSL::VERIFY_NONE

    request = Net::HTTP::Post.new(url.path)
    request.set_form_data({
      'username' => @username,
      'password' => @password
    })

    response = @http.request(request)
    @token = response.body.match(/<sessionKey>(.+)<\/sessionKey>/)[1]

  end

  def run(queue)

    state_file_path = File.join(ENV['LOGSTASH_HOME'], 'data/plugins/inputs/file/state.dat')

    loop do

      state = {}

      if File.exist?(state_file_path)
        File.open(state_file_path, 'rb') do |file|
          state = Marshal.load(file)
        end
      end

      if state[@index]
        @indextime_mark = state[@index][0]
        @bucket_id_mark = state[@index][1]
        @offset_mark = state[@index][2]
      else
        @indextime_mark = 0
        @bucket_id_mark = 0
        @offset_mark = 0
        state[@index] = [@indextime_mark, @bucket_id_mark, @offset_mark]
      end

      trappable_signals = %w[
        HUP INT TERM ABRT TSTP TTIN TTOU
      ]

      trappable_signals.each do |signal|
        trap(signal) do
          File.open(state_file_path, 'wb') do |file|
              state[@index] = [@indextime_mark, @bucket_id_mark, @offset_mark]
              Marshal.dump(state, file)
          end
          exit
        end
      end

      search_query = "search index=#{@index} | eval extracted_cd=split(_cd,\":\") | eval bucket_id=tonumber(mvindex(extracted_cd,0)) | eval offset=tonumber(mvindex(extracted_cd,1)) | where ((_indextime > #{@indextime_mark}) OR (_indextime = #{@indextime_mark} AND (bucket_id > #{@bucket_id_mark} OR (bucket_id = #{@bucket_id_mark} AND offset > #{@offset_mark})))) | sort _indextime, bucket_id, offset | head #{@fetch_offset_limit}"

      search_url = URI.parse("#{@splunk_url}/services/search/jobs")
      search_request = Net::HTTP::Post.new(search_url.path)
      search_request['Authorization'] = "Splunk #{@token}"
      search_request.set_form_data({
        'search' => search_query,
        'output_mode' => 'json'
      })

      search_response = @http.request(search_request)
      sid = JSON.parse(search_response.body)["sid"]

      loop do
        status_url = URI.parse("#{@splunk_url}/services/search/jobs/#{sid}?output_mode=json")
        status_request = Net::HTTP::Get.new(status_url)
        status_request['Authorization'] = "Splunk #{@token}"

        status_response = @http.request(status_request)
        content = JSON.parse(status_response.body)

        if content["entry"][0]["content"]["isDone"]
          break
        else
          sleep 2
        end
      end

      results_url = URI.parse("#{@splunk_url}/services/search/jobs/#{sid}/results?output_mode=json")
      results_request = Net::HTTP::Get.new(results_url)
      results_request['Authorization'] = "Splunk #{@token}"

      results_response = @http.request(results_request)
      results = JSON.parse(results_response.body)

      max_bytes_size = @max_fetch_size_in_mb * 1024 * 1024
      current_bytes_size = 0

      results["results"].each do |doc|
        if doc
          indextime_value = doc["_indextime"].to_i
          bucket_id_value = doc["bucket_id"].to_i
          offset_value = doc["offset"].to_i
          @indextime_mark = [@indextime_mark, indextime_value].max
          @bucket_id_mark = [@bucket_id_mark, bucket_id_value].max
          @offset_mark = [@offset_mark, offset_value].max

          event_json = doc.to_json
          size_bytes = event_json.bytesize

          if(current_bytes_size + size_bytes > max_bytes_size)
            break
          end

          current_bytes_size = current_bytes_size + size_bytes
          
          event = LogStash::Event.new(doc)
          queue << event
        end
      end

      File.open(state_file_path, 'wb') do |file|
        state[@index] = [@indextime_mark, @bucket_id_mark, @offset_mark]
        Marshal.dump(state, file)
      end

      sleep 1
    end
  end 
end
