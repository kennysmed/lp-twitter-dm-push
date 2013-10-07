require 'spec_helper'
require 'twitstream/twitter'


describe "Twitter" do

  it "returns an OAuth Consumer" do
    expect(Twitstream::Twitter.consumer).to be_an_instance_of(OAuth::Consumer)
  end

  it "returns a TweetStream Client" do
    expect(Twitstream::Twitter.client).to be_an_instance_of(TweetStream::Client)
  end

end
