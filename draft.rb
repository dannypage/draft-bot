require 'logger'
require 'json'
require 'net/http'

Dir.chdir('/Users/Danny/Projects/draft/')
log = Logger.new('results.log')

class Draft
  def initialize

  end
end

class PlayerList
  def initialize
    @wrs = download_list('WR')
  end

  def download_list(position)
    response = Net::HTTP.get_response(URI.parse("http://draft.gnmerritt.net/api/v1/nfl/position/#{position}"))
    list = JSON.parse(response.body)
    puts list
  end
end

class Player < PlayerList

end

loop do
  pl = PlayerList.new
  log.debug('Woo')
  sleep(60)
end