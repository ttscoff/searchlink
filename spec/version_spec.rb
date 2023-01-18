# frozen_string_literal: true

require 'spec_helper'

# https://github.com/thoiberg/cli-test
describe 'Version' do
  describe 'Version check is successful' do
    it 'returns false' do
      expect(SL::new_version?).not_to be_truthy
    end
  end
end
