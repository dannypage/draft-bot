require 'logger'
require 'json'
require 'net/http'
require 'csv'

$log = Logger.new('results.log')

class PlayerList

  def initialize(list)
    $log.info('Player list initialized!')
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

  def toggle_drafts(selected_id)
    @players.each do |player|
      if player.id == selected_id
        player.not_drafted = false
        return player
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
    $log.info('Starting the draft!')
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
    selected = list['selections'].map { |x| x['player']['id']}

    if selected != @selections
      diff = selected -@selections
      diff.each do |select|
        player = pl.toggle_drafts(select)
        $log.info("#{player.first} #{player.last} was drafted.")
      end
      @selections = selected
    end
  end

  def find_team(team_name)
    puts "Finding our team."
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

  def pick_time
    now = Time.now.to_i
    @picks.each do |pick|
      if pick < now and ( pick +30) > now
        return true
      end
    end
    return false
  end
end

players = []
#url = 'http://draft.gnmerritt.net/api/v1/draft?key=d6ba52c5-aae1-48d5-9136-73c4f624ad25'
url = 'http://draft.gnmerritt.net/api/v1/draft?key=45d25107-91f3-458b-89db-e9bfa900aab9'
key = '45d25107-91f3-458b-89db-e9bfa900aab9'
#team_name = 'Nybble and Bits'
team_name = "Nybble and Bits's mock draft team"

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
  my_pick_status = my_team.pick_time
  $log.info("Is it my turn? #{my_pick_status}")
  if my_pick_status
    pick_url = "http://draft.gnmerritt.net/api/v1/pick_player/#{player.id}?key=#{key}"
    response = Net::HTTP.get_response(URI.parse(pick_url))
  end
  sleep(5)
end