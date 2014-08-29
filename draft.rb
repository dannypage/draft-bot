require 'logger'
require 'json'
require 'net/http'
require 'csv'

$log = Logger.new('results.log')

def request_wrapper(url)
  begin
    response = Net::HTTP.get_response(URI.parse(url))
    list = JSON(response.body)
    return response, list
  rescue Exception => e
    puts e
    retry
  end
end

class PlayerList

  def initialize(list)
    $log.info('Player list initialized!')
    @players = []
    list.each do |player|
      @players << Player.new(player)
    end

    @players.sort! { |a,b| b.value <=> a.value }
  end

  def best_available(pos='any')
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
    player_url = "http://draft.gnmerritt.net/api/v1/search/name/#{player[:last]}/pos/#{player[:pos]}"
    response, list = request_wrapper(player_url)

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
      puts "Cannot find #{player[:first]} #{player[:last]}"
    end
  end
end

class Draft
  attr_reader :rounds, :time
  attr_accessor :teams, :selections

  def initialize(url)
    $log.info('Starting the draft!')
    response, list = request_wrapper(url)

    @rounds = list['roster']['slots']
    @teams = []
    @time = list['time_per_pick_s']
    @selections = []

    list['teams'].each do |team|
      @teams << Team.new(team)
    end
  end

  def update(url, pl)
    request, list = request_wrapper(url)


    selected = list['selections'].map { |x| x['player']['id']}

    if selected != @selections
      diff = selected -@selections
      diff.each do |select|
        player = pl.toggle_drafts(select)
        $log.info("#{player.first} #{player.last} was drafted.")
      end
      @selections = selected
    end

    list
  end

  def find_team(team_name)
    puts 'Finding our team.'
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
      if pick < now and ( pick +10) > now
        return true
      end
    end
    return false
  end
end

players = []
#url = 'http://draft.gnmerritt.net/api/v1/draft?key=d6ba52c5-aae1-48d5-9136-73c4f624ad25'
#key = 'd6ba52c5-aae1-48d5-9136-73c4f624ad25'
#team_name = 'Nybble and Bits'
url = 'http://draft.gnmerritt.net/api/v1/draft?key=94d062b3-1381-4a63-a679-a5ca9b166380'
key = '94d062b3-1381-4a63-a679-a5ca9b166380'
team_name = "Nybble and Bits's mock draft team"

CSV.foreach('players.csv', :headers => true, :header_converters => :symbol, :converters => :all) do |row|
  players << Hash[row.headers[0..-1].zip(row.fields[0..-1])]
end

pl = PlayerList.new(players)
draft = Draft.new(url)
my_team = draft.find_team(team_name)
picks = 0

loop do
  response = draft.update(url, pl)
  response['teams'].each do |team|
    if team['name'] == team_name
      picks = team['selection_ids'].count
    end
  end

  my_pick_status = my_team.pick_time
  if my_pick_status
    $log.info("Round ##{picks+1}: Thinking about a player.")
    if picks == 13
      player = pl.best_available('DST')
    elsif picks == 14
      player = pl.best_available('K')
    else
      player = pl.best_available
    end
    pick_url = "http://draft.gnmerritt.net/api/v1/pick_player/#{player.id}?key=#{key}"
    $log.info("Selected #{player.first} #{player.last}")
    response = request_wrapper(pick_url)
  end
  sleep(3)
end