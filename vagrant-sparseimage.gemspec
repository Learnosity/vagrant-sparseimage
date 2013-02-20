# -*- encoding: utf-8 -*-
require File.expand_path('../lib/vagrant-sparseimage/version', __FILE__)

Gem::Specification.new do |s|
	s.name			= "vagrant-sparseimage"
	s.version		= VagrantSparseimage::VERSION
	s.platform		= Gem::Platform::RUBY
	s.author		= ["Alan Garfield"]
	s.email			= ["alan.garfield@learnosity.com"]
	s.license		= 'MIT'
	s.homepage		= "https://github.com/learnosity/vagrant-sparseimage"
	s.summary		= %q{A Vagrant plugin that will create and mount a sparseimage image into the guest VM}
	s.description	= %q{A Vagrant plugin that automatically creates and mounts sparseimage for guest VMs}

	s.required_rubygems_version = ">= 1.3.6"

	s.add_development_dependency "bundler", ">= 1.2.0"

	s.files = Dir["lib/**/*.*"]
	s.require_paths = ["lib"]
end
