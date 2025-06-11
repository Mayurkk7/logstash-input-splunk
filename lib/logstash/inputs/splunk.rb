# encoding: utf-8
require "logstash/inputs/base"
require 'net/http'
require 'uri'
require 'openssl'
require 'json'

module LogStash

  module Inputs

    class Splunk < LogStash::Inputs::Base

      config_name "splunk"

      config :splunk_url, :validate => :string, :required => true
      config :username, :validate => :string, :default => ""
      config :password, :validate => :string, :default => ""
      config :token, :validate => :string, :default => ""
      config :index, :validate => :string, :required => true
      config :fetch_offset_limit, :validate => :number, :default => 50
      config :max_fetch_size_in_mb, :validate => :number, :default => 10
      config :splunk_api_url, :validate => :string, :default => ""

      @@indextime_mark = 0
      @@bucket_id_mark = 0
      @@offset_mark = 0

      def self.indextime_mark
        @@indextime_mark
      end
    
      def self.indextime_mark=(val)
        @@indextime_mark = val
      end

      def self.bucket_id_mark
        @@bucket_id_mark
      end
    
      def self.bucket_id_mark=(val)
        @@bucket_id_mark = val
      end

      def self.offset_mark
        @@offset_mark
      end
    
      def self.offset_mark=(val)
        @@offset_mark = val
      end

      public
      def register

        url = URI.parse("#{@splunk_url}/services/auth/login")
        @http = Net::HTTP.new(url.host, url.port)
        @http.use_ssl = true
        @http.verify_mode = OpenSSL::SSL::VERIFY_NONE

        if(@token.strip.empty?)
            splunkAuthenticator = SplunkAuthenticator.new
            @token = splunkAuthenticator.Authenticate(@http, url, @username, @password)
        end

      end

      def run(queue)

        loop do

          splunkStateManager = SplunkStateManager.new
          state = splunkStateManager.getState

          if state[@index]
            @@indextime_mark = state[@index][0]
            @@bucket_id_mark = state[@index][1]
            @@offset_mark = state[@index][2]
          else
            @@indextime_mark = 0
            @@bucket_id_mark = 0
            @@offset_mark = 0
            state[@index] = [@@indextime_mark, @@bucket_id_mark, @@offset_mark]
          end

          splunkStateManager.trapSignals(state, @index)

          splunkSearchProcessor = SplunkSearchProcessor.new
          splunkSearchProcessor.resultProcessor(queue, @http, @splunk_url, @token, state, @index, @splunk_api_url, @max_fetch_size_in_mb, @fetch_offset_limit)

          sleep 1
          
        end

      end

    end

    class SplunkAuthenticator

      def Authenticate(http, url, username, password)

        request = Net::HTTP::Post.new(url.path)
        request.set_form_data({
          'username' => username,
          'password' => password
        })

        response = http.request(request)
        token = response.body.match(/<sessionKey>(.+)<\/sessionKey>/)[1]
        return token

      end

    end

    class SplunkStateManager

      def initialize()
        @state_file_path = ::File.join(ENV['LOGSTASH_HOME'], 'data/plugins/inputs/file/state.dat')
      end

      def getState()

        state = {}

        if ::File.exist?(@state_file_path)
            ::File.open(@state_file_path, 'rb') do |file|
              state = Marshal.load(file)
            end
        end
        
        return state

      end

      def setState(state, index)

        ::File.open(@state_file_path, 'wb') do |file|
            state[index] = [Splunk.indextime_mark, Splunk.bucket_id_mark, Splunk.offset_mark]
            Marshal.dump(state, file)
        end

      end

      def trapSignals(state, index)

        trappable_signals = %w[
            HUP INT TERM ABRT TSTP TTIN TTOU
        ]

        trappable_signals.each do |signal|
            trap(signal) do
                self.setState(state, index)
                exit
            end
        end
    
      end

    end

    class SplunkSearchProcessor

      def resultProcessor(queue, http, splunk_url, token, state, index, splunk_api_url, max_fetch_size_in_mb, fetch_offset_limit)

        search_query = "search index=#{index} | eval extracted_cd=split(_cd,\":\") | eval bucket_id=tonumber(mvindex(extracted_cd,0)) | eval offset=tonumber(mvindex(extracted_cd,1)) | where ((_indextime > #{Splunk.indextime_mark}) OR (_indextime = #{Splunk.indextime_mark} AND (bucket_id > #{Splunk.bucket_id_mark} OR (bucket_id = #{Splunk.bucket_id_mark} AND offset > #{Splunk.offset_mark})))) | sort _indextime, bucket_id, offset | head #{fetch_offset_limit}"

        search_url = URI.parse("#{splunk_url}/services/search/jobs/export")
        if(!splunk_api_url.strip.empty?)
            search_url = URI.parse("#{splunk_url}/#{splunk_api_url}")
        end
        search_request = Net::HTTP::Post.new(search_url.path)
        search_request['Authorization'] = "Splunk #{token}"
        search_request["Content-Type"] = "application/x-www-form-urlencoded"
        search_request.set_form_data({
            'search' => search_query,
            'output_mode' => 'json',
            "search_mode" => "normal"
        })

        max_bytes_size = max_fetch_size_in_mb * 1024 * 1024
        current_bytes_size = 0

        stop_streaming = false

        http.request(search_request) do |response|
            buffer = ""
            response.read_body do |chunk|
                break if stop_streaming
                buffer << chunk

                while line = buffer.slice!(/.+\r?\n/)
                    begin
                        json = JSON.parse(line)
                        if json["result"]
                            doc = json["result"]

                            indextime_value = doc["_indextime"].to_i
                            bucket_id_value = doc["bucket_id"].to_i
                            offset_value = doc["offset"].to_i
                            Splunk.indextime_mark = [Splunk.indextime_mark, indextime_value].max
                            Splunk.bucket_id_mark = [Splunk.bucket_id_mark, bucket_id_value].max
                            Splunk.offset_mark = [Splunk.offset_mark, offset_value].max
                            event_json = doc.to_json
                            size_bytes = event_json.bytesize

                            if current_bytes_size + size_bytes > max_bytes_size
                                stop_streaming = true
                                break
                            end

                            current_bytes_size += size_bytes

                            event = LogStash::Event.new(doc)
                            queue << event
                        end
                    rescue JSON::ParserError => e
                        puts "Failed to parse line: #{line.strip}"
                    end
                end
            end
        end

        splunkStateManager = SplunkStateManager.new
        splunkStateManager.setState(state, index)

      end

    end

  end

end