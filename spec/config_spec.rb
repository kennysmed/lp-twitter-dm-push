require 'spec_helper'
require 'ahola/config'


describe "Config" do

  before :all do
    @config = Ahola::Config.new
  end

  it "returns config settings" do
    expect(@config[:bergcloud_consumer_key]).to eq('abcdefghABCDEFGH12345')
  end

  it "returns nothing for wrong config settings" do
    expect(@config[:nothing_here]).to eq(nil)
  end

  it "returns ENV variables when necessary" do
    # So it doesn't load config values from the config file.
    File.stub(:exists?).and_return(false)
    ENV.stub(:[]).with('TEST_ENV_KEY').and_return('testENVvalue')
    ENV.stub(:[]).with('RACK_ENV').and_return('test')

    expect(@config[:test_env_key]).to eq('testENVvalue')
  end
end
