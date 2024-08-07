# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |spec|
  spec.name    = 'fluent-plugin-elastic-log'
  spec.version = '0.5.3'
  spec.authors = ['Thomas Tych']
  spec.email   = ['thomas.tych@gmail.com']

  spec.summary       = "fluentd plugins to process elastic logs.'"
  spec.homepage      = 'https://gitlab.com/ttych/fluent-plugin-elastic-log'
  spec.license       = 'Apache-2.0'

  spec.required_ruby_version = '>= 2.4.0'

  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (f == __FILE__) || f.match(%r{\A(?:(?:test|spec|features)/|\.(?:git|travis|circleci)|appveyor)})
    end
  end
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  # commented dependency use blocked old versions
  # for compatibility with ruby 2.4.10
  # for old version of td-agent

  spec.add_development_dependency 'bump', '~> 0.10.0'
  spec.add_development_dependency 'bundler', '~> 2.2'
  spec.add_development_dependency 'byebug', '~> 11.1', '>= 11.1.3'
  spec.add_development_dependency 'rake', '~> 13.0.6'
  spec.add_development_dependency 'reek', '~> 6.0.6' # < 6.1.x to work with ruby 2.4.10
  spec.add_development_dependency 'rubocop', '~> 1.12.1' # < 1.13.x to work with ruby 2.4.10
  spec.add_development_dependency 'rubocop-rake', '~> 0.5.1' # < 0.6.x to work with ruby 2.4.10
  spec.add_development_dependency 'test-unit', '~> 3.5.7'

  spec.add_runtime_dependency 'fluentd', ['>= 0.14.10', '< 2']

  spec.metadata['rubygems_mfa_required'] = 'true'
end
