require 'spec_helper'
require 'twitterpush/twitter'


describe "Twitter" do

  it "returns an OAuth Consumer" do
    expect(TwitterPush::Twitter.consumer).to be_an_instance_of(OAuth::Consumer)
  end

  it "returns a TweetStream Client" do
    expect(TwitterPush::Twitter.client).to be_an_instance_of(TweetStream::Client)
  end

end

