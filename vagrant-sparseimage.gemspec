$:.unshift File.expand_path("../lib", __FILE__)
require 'version.rb'

Gem::Specification.new do |s|
	s.name			= 'vagrant-sparseimage'
	s.version		= SparseImage::VERSION
	s.platform		= Gem::Platform::RUBY
	s.authors		= ['Alan Garfield', 'Daniel Bryan']
	s.license		= 'MIT'
	s.email			= ['alan.garfield@learnosity.com', 'danbryan@gmail.com']
	s.homepage		= 'https://github.com/Learnosity/vagrant-sparseimage'
	s.summary		= %q{A vagrant plugin to create a mount sparse images into the guest VM.}
	s.description	= %q{A vagrant plugin to create a mount sparse images into the guest VM.}
	s.files = ['lib/vagrant-sparseimage.rb']
	s.require_paths = ['lib']

	s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=

	if s.respond_to? :specification_version
		current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
		s.specification_version = 2
	end
	
	s.add_development_dependency 'bundler', '>= 1.2.0'
	s.add_development_dependency 'vagrant', '>= 1.2'

end
