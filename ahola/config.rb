require 'yaml'

module Ahola
  class Config

    def self.config
      @config ||= YAML.load_file('config.yml') if File.exists?('config.yml')
    end

    def [](key)
      key = "#{key}"
      ENV[key.upcase] || config[key]
    end
  end
end

