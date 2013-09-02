require 'yaml'

module Ahola
  class Config

    def config
      @config ||= YAML.load_file('config.yml') if File.exists?('config.yml')
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

