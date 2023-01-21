# module SL
#   class SearchLink
#     def google(terms, define = false)
#       uri = URI.parse("http://ajax.googleapis.com/ajax/services/search/web?v=1.0&filter=1&rsz=small&q=#{ERB::Util.url_encode(terms)}")
#       req = Net::HTTP::Get.new(uri.request_uri)
#       req['Referer'] = 'http://brettterpstra.com'
#       res = Net::HTTP.start(uri.host, uri.port) { |http| http.request(req) }
#       body = if RUBY_VERSION.to_f > 1.9
#                res.body.force_encoding('utf-8')
#              else
#                res.body
#              end

#       json = JSON.parse(body)
#       return ddg(terms, false) unless json['responseData']

#       result = json['responseData']['results'][0]
#       return false if result.nil?

#       output_url = result['unescapedUrl']
#       output_title = if define && output_url =~ /dictionary/
#                        result['content'].gsub(/<\/?.*?>/, '')
#                      else
#                        result['titleNoFormatting']
#                      end
#       [output_url, output_title]
#     rescue StandardError
#       ddg(terms, false)
#     end
#   end
# end
