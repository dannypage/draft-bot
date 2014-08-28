require 'logger'
require 'json'
require 'net/http'
require 'csv'

$log = Logger.new('results.log')

class PlayerList

  def initialize(list)
    @players = []
    list.each do |player|
      @players << Player.new(player)
    end
  end

  def best_available(pos='any')
    @players.sort! { |a,b| b.value <=> a.value }
    if pos == 'any'
      @players.each do |player|
        if player.not_drafted
          return player
        end
      end
    else
      @players.each do |player|
        if player.not_drafted and player.pos == pos
          return player
        end
      end
    end

    nil #ruhroh, out of players?
  end
end

class Player
  attr_reader :first, :last, :value, :percent, :pos, :id
  attr_accessor :not_drafted

  def initialize(player)
    @first = player[:first]
    @last = player[:last]
    @value = player[:val]
    @percent = player[:ps]
    @pos = player[:pos]
    @id = get_id(player)
    @not_drafted = true
  end

  def get_id(player)

    response = Net::HTTP.get_response(
        URI.parse("http://draft.gnmerritt.net/api/v1/search/name/#{player[:last]}/pos/#{player[:pos]}"))
    list = JSON(response.body)
    if list and list['results'] and list['results'].count > 1
      found = list['results'].find { |x| x['first_name'] == player[:first] }
      if found and found['id']
        return found['id']
      else
        $log.debug(player.inspect)
        return nil
      end
    elsif list and list['results'] and list['results'].count == 1
      return list['results'][0]['id']
    else
      nil
    end
  end
end

class Draft
  def initialize(url)

  end
end

class Team

end

players = []

CSV.foreach('players.csv', :headers => true, :header_converters => :symbol, :converters => :all) do |row|
  players << Hash[row.headers[0..-1].zip(row.fields[0..-1])]
end

pl = PlayerList.new(players)

loop do
  puts pl.best_available
  $log.debug('Woo')
  sleep(60)
end