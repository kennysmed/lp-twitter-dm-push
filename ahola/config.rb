require 'yaml'

module Ahola
  class Config

    def config
      @config ||= YAML.load_file('config.yml') if File.exists?('config.yml')
    end

    def [](key)
      key = "#{key}"
      ENV[key.upcase] || self.config[key]
    end
  end
end

