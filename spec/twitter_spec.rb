require 'spec_helper'
require 'ahola/twitter'


describe "Twitter" do

  it "returns an OAuth Consumer" do
    expect(Ahola::Twitter.consumer).to be_an_instance_of(OAuth::Consumer)
  end

  it "returns a TweetStream Client" do
    expect(Ahola::Twitter.client).to be_an_instance_of(TweetStream::Client)
  end

end
