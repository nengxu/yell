# encoding: utf-8

require 'erb'
require 'yaml'

module Yell #:nodoc:

  # The Configuration can be used to setup Yell before
  # initializing an instance.
  class Configuration

    def self.load!( file )
      # parse through ERB
      yaml = ERB.new(File.read(file)).result

      # parse through YAML
      YAML.load(yaml)[Yell.env] || {}
    end

  end
end

