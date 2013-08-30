require 'spec_helper'
require 'ahola/frontend'

describe "Frontend" do
  def app
    Ahola::Frontend
  end

  describe "Get /" do
    before :each do
      get '/'
    end
    it "returns 200" do
      last_response.status.should == 200
    end
    it "contains the correct content" do
      last_response.body.should include(format_title)
    end
  end

  describe "Favicon" do
    it "returns 410" do
      get '/favicon.ico'
      last_response.status.should == 410
    end
  end

  describe "Helpers" do
    describe "format_title" do
      it "returns the correct title" do
        format_title.should eq("Little Printer Twitter Direct Message Publication")
      end
    end
  end
end


