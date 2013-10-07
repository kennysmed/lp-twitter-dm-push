module Twitstream
  module FrontendHelpers
    def format_title
      "Little Printer Twitter Direct Message Publication"
    end

    def check_berg_urls(return_url, error_url)
      halt 400, 'No return_url parameter was provided' if !return_url
      halt 400, 'No error_url parameter was provided' if !error_url
      parsed_return_url = ::URI.parse(return_url)
      halt 403 unless parsed_return_url.host.end_with?('bergcloud.com')
      parsed_error_url = ::URI.parse(error_url)
      halt 403 unless parsed_error_url.host.end_with?('bergcloud.com')
      return return_url, error_url
    end
  end
end
