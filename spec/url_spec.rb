# frozen_string_literal: true

require 'spec_helper'

# https://github.com/thoiberg/cli-test
describe SL::URL do
  subject(:url) do
    SL::SearchLink.new({ echo: true} )
    SL::URL
  end

  describe '.valid_link?' do
    it 'validates link' do
      expect(url.valid_link?('https://brettterpstra.com')).to be_truthy
    end
  end

  describe '.url?' do
    it 'recognizes link' do
      expect(url.url?('https://brettterpstra.com')).to be_truthy
    end
  end

  describe '.only_url?' do
    it 'recognizes non-link matter' do
      expect(url.only_url?('https://brettterpstra.com')).to be_truthy
      expect(url.only_url?('https://brettterpstra.com and some text')).not_to be_truthy
    end
  end

  describe '.ref_title_for_url' do
    it 'creates an appropriate reference title' do
      expect(url.ref_title_for_url('https://brettterpstra.com')).to match(/^brettterpstra$/)
    end
  end

  describe '.url_to_link' do
    it 'creates a title and url for url' do
      expect(url.url_to_link('https://brettterpstra.com', 'inline')).to eq(['https://brettterpstra.com', 'BrettTerpstra.com'])
    end
  end

  describe '.get_title' do
    it 'collects the correct title' do
      expect(url.get_title('https://brettterpstra.com')).to match(/BrettTerpstra.com/)
    end
  end
end
