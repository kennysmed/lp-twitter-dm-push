require 'spec_helper'
require 'ahola/twitter'


describe "Twitter" do

  it "returns an OAuth Consumer" do
    Ahola::Twitter.consumer.should be_an_instance_of(OAuth::Consumer)
  end

  it "returns a TweetStream Client" do
    oauth_token = 'NPcudxy0yU5T3tBzho7iCotZ3cnetKwcTIRlX0iwRl0'
    oauth_token_secret = 'veNRnAWe6inFuo8o2u8SLLZLjolYDmDP7SzL0YfYI'
    Ahola::Twitter.tweetstream(oauth_token, oauth_token_secret).should be_an_instance_of(TweetStream::Client)
  end

end
