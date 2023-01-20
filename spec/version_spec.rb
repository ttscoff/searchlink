# frozen_string_literal: true

require 'spec_helper'

# https://github.com/thoiberg/cli-test
describe 'Version' do
  it 'returns false for new version' do
    expect(SL::new_version?).not_to be_truthy
  end
end
