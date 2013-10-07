require 'twitterpush/config'


module TwitterPush 
  class Base

    def config
      @config ||= TwitterPush::Config.new
    end


    def log(str)
      if ENV['RACK_ENV'] != 'test'
        puts str
      end
    end

  end
end
