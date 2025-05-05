source 'https://rubygems.org'
gemspec

logstash_path = ENV['LOGSTASH_PATH'] || '/Users/consultadd/Desktop/elasticsearch_course/logstash-8.17.2'

if Dir.exist?(logstash_path)
  gem 'logstash-core', :path => "#{logstash_path}/logstash-core"
  gem 'logstash-core-plugin-api', :path => "#{logstash_path}/logstash-core-plugin-api"
end