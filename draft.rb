require 'logger'
require 'json'
require 'net/http'
require 'csv'

log = Logger.new('results.log')

class Draft
  def initialize

  end
end

class PlayerList
  @@players = {}

  def initialize(list)
    list.each do |player|
      Player.new(player)
    end
  end

end

class Player
  def initialize(player)
    @first = player[:first]
    @last = player[:last]
    @value = player[:val]
    @percent = player[:ps]
    @pos = player[:pos]
    @id = lookup(player)
  end

  def lookup(player)
    response = NET::HTTP.get_response(
        URI.parse("http://draft.gnmerritt.net/api/v1/search/name/#{player[:last]}/pos/#{player[:pos]}"))
    list = JSON(response.body)
    puts list
  end
end

players = []

CSV.foreach('players.csv', :headers => true, :header_converters => :symbol, :converters => :all) do |row|
  players << Hash[row.headers[0..-1].zip(row.fields[0..-1])]
end

loop do
  pl = PlayerList.new(players)
  log.debug('Woo')
  sleep(60)
end