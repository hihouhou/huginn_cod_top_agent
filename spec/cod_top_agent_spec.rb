require 'rails_helper'
require 'huginn_agent/spec_helper'

describe Agents::CodTopAgent do
  before(:each) do
    @valid_options = Agents::CodTopAgent.new.default_options
    @checker = Agents::CodTopAgent.new(:name => "CodTopAgent", :options => @valid_options)
    @checker.user = users(:bob)
    @checker.save!
  end

  pending "add specs here"
end
