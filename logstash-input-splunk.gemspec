Gem::Specification.new do |s|
  s.name          = 'logstash-input-splunk'
  s.version       = '0.1.0'
  s.licenses      = ['Apache-2.0']
  s.summary       = 'Logstash input plugin for Splunk'
  s.description   = 'Input plugin for Splunk'
  s.homepage      = 'https://github.com'
  s.authors       = ['Consultadd']
  s.email         = 'consultadd@gmail.com'
  s.require_paths = ['lib']

  s.files = Dir['lib/**/*','spec/**/*','vendor/**/*','*.gemspec','*.md','CONTRIBUTORS','Gemfile','LICENSE','NOTICE.TXT']

  s.test_files = s.files.grep(%r{^(test|spec|features)/})

  s.metadata = { "logstash_plugin" => "true", "logstash_group" => "input" }

  s.add_runtime_dependency "logstash-core-plugin-api", "~> 2.0"
  s.add_runtime_dependency 'logstash-codec-plain'
  s.add_runtime_dependency 'stud', '>= 0.0.22'
  s.add_development_dependency 'logstash-devutils', '>= 0.0.16'
end
