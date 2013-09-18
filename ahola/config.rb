require 'yaml'

module Ahola
  class Config

    def config
      if ENV['RACK_ENV'] == 'test'
        file_name = 'config.yml.test'
      else
        file_name = 'config.yml'
      end
      @config ||= YAML.load_file(file_name) if File.exists?(file_name)
    end

    def [](key)
      key = "#{key}"
      if self.config
        self.config[key]
      else
        ENV[key.upcase]
      end
    end
  end
end

