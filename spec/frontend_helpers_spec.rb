require 'spec_helper'
require 'ahola/frontend_helpers'

class TestHelpers
  include Ahola::FrontendHelpers
end


describe "Helpers" do
  let(:helpers) { TestHelpers.new }

  before :each do
    helpers.stub(:halt).and_throw(:halt)
  end

  describe "format_title" do
    it "returns the correct title" do
      helpers.format_title.should eq("Little Printer Twitter Direct Message Publication")
    end
  end

  describe "check_berg_urls" do
    before :all do
      @return_url = 'http://remote.bergcloud.com/publications/145/subscription_configuration_return'
      @error_url = 'http://remote.bergcloud.com/publications/145/subscription_configuration_failure'
    end

    it "returns the urls if valid" do
      checked_return_url, checked_error_url = helpers.check_berg_urls(@return_url, @error_url)
      checked_return_url.should eq(@return_url)
      checked_error_url.should eq(@error_url)
    end

    it "halts if return_url is invalid" do
      expect {
        helpers.check_berg_urls('http://example.com/test/', @error_url)
      }.to raise_exception
    end

    it "halts if error_url is invalid" do
      expect {
        helpers.check_berg_urls(@return_url, 'http://example.com/test/')
      }.to raise_exception
    end
  end
end
