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

  def toggle_drafts(selected)
    @players.each do |player|
      if player.id == selected
        player.not_drafted = false
        return
      end
    end
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
  attr_reader :rounds, :time
  attr_accessor :teams, :selections

  def initialize(url)
    response = Net::HTTP.get_response(URI.parse(url))
    list = JSON(response.body)

    @rounds = list['roster']['slots']
    @teams = []
    @time = list['time_per_pick_s']
    @selections = []

    list['teams'].each do |team|
      @teams << Team.new(team)
    end
  end

  def update(url, pl)
    response = Net::HTTP.get_response(URI.parse(url))
    list = JSON(response.body)
    if list['selections'] != @selections
      diff = list['selections']-@selections
      diff.each do |selected|
        player = pl.toggle_drafts(selected)
        $log.info("#{player.first} #{player.last} was drafted.")
      end
    end
  end

  def find_team(team_name)
    @teams.each do |team|
      if team.name == team_name
        return team
      end
    end
  end
end

class Team
  attr_reader :name, :id, :picks, :email
  attr_accessor :selections

  def initialize(team)
    @selections = []
    @email = team['email']
    @picks = []
    @id = team['id']
    @name = team['name']
    team['picks'].each do |pick|
      @picks << pick['starts']['utc']
    end
  end

  def pick?
    now = Time.now.utc
    @picks.each do |pick|
      if pick < now < (pick +30)
        return true
      end
    end
    return false
  end
end

players = []
#url = 'http://draft.gnmerritt.net/api/v1/draft?key=d6ba52c5-aae1-48d5-9136-73c4f624ad25'
url = 'http://draft.gnmerritt.net/api/v1/draft?key=4cf416f5-7e5e-4cd8-8e20-b6b9d5858b82'
team_name = 'Nybble and Bits'

CSV.foreach('players.csv', :headers => true, :header_converters => :symbol, :converters => :all) do |row|
  players << Hash[row.headers[0..-1].zip(row.fields[0..-1])]
end

pl = PlayerList.new(players)
draft = Draft.new(url)
my_team = draft.find_team(team_name)

loop do
  draft.update(url, pl)
  player = pl.best_available
  $log.info("Best Available: #{player.first} #{player.last}")
  $log.info("Is it my turn? #{my_team.pick?}")
  sleep(5)
end