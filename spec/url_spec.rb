# frozen_string_literal: true

require 'spec_helper'

# https://github.com/thoiberg/cli-test
describe SL::URL do
  subject(:url) do
    SL::SearchLink.new({ echo: true} )
    SL::URL
  end

  describe '#valid_link?' do
    context 'when given a full URL' do
      it 'validates link' do
        expect(url.valid_link?('https://brettterpstra.com')).to be_truthy
      end
    end

    context 'when given an invalid URL' do
      it 'fails link validation' do
        expect(url.valid_link?('https://brettterpstra.com/topic/aw43tta342t')).not_to be_truthy
      end
    end
  end

  describe '#url?' do
    context 'when given a valid url' do
      it 'recognizes link' do
        expect(url.url?('https://brettterpstra.com')).to be_truthy
      end
    end

    context 'when given an incomplete url' do
      it 'fails to recognize link' do
        expect(url.url?('brettterpstra.com')).to be_truthy
      end
    end
  end

  describe '#only_url?' do
    context 'when given text with only a link' do
      it 'recognizes url only' do
        expect(url.only_url?('https://brettterpstra.com')).to be_truthy
      end
    end

    context 'when given text containing more than a url' do
      it 'recognizes non-link content' do
        expect(url.only_url?('https://brettterpstra.com and some text')).not_to be_truthy
      end
    end
  end

  describe '#ref_title_for_url' do
    context 'when given a url' do
      it 'creates an appropriate reference title' do
        expect(url.ref_title_for_url('https://brettterpstra.com')).to match(/^brettterpstra$/)
      end
    end
  end

  describe '#url_to_link' do
    context 'when given a url' do
      it 'creates a title and url for url' do
        expect(url.url_to_link('https://brettterpstra.com', :inline)).to eq(['https://brettterpstra.com', 'BrettTerpstra.com'])
      end
    end
  end

  describe '#get_title' do
    context 'when given a valid url' do
      it 'collects the correct title' do
        expect(url.get_title('https://brettterpstra.com')).to match(/BrettTerpstra.com/)
      end
    end
  end
end
