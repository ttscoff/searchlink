# frozen_string_literal: true

require 'spec_helper'

describe SL::SemVer do
  ver = '1.0.10'
  v = SL::SemVer.new(ver)

  context 'When given a valid semantic version' do
    it 'generates a semver object' do
      expect(v.maj).to eq(1)
      expect(v.min).to eq(0)
      expect(v.patch).to eq(10)
    end
  end

  context 'When given an older semantic version' do
    it 'detects an older version number' do
      new_ver = '1.0.9'
      expect(v.newer_than(new_ver)).to be_truthy
    end
  end

  context 'When given a newer semantic version' do
    it 'detects a newer version number' do
      new_ver = '1.1.0'
      expect(v.older_than(new_ver)).to be_truthy
    end
  end

  context 'When given an identical semantic version' do
    it 'detects equality' do
      new_ver = '1.0.10'
      expect(v.equal?(new_ver)).to be_truthy
    end
  end

  context 'When given a pre-release version' do
    it 'detects newer version' do
      new_ver = '1.0.10pre1'
      expect(v.equal?(new_ver)).not_to be_truthy
      expect(v.older_than(new_ver)).to be_truthy
    end
  end
end
