
FILE_PATH = 'qgames.log'.freeze
INIT_GAME_REGEX = /.+(InitGame:).+/
KILL_REGEX = /.+: (.*) killed (.*?) by (.+)/
PLAYER_REGEX = /.+ n\\(.*?)\\t.+/

game_id = 0
matches = []
players = []
current_match_kills = 0
log_kills = []

def render_current_game_data(game_id, total_kills, players, log_kills)
  {
    "game_#{game_id}" => {
      "total_kills" => total_kills,
      "players" => players.uniq,
      "kills" => generate_kills(players, log_kills),
      "kills_by_means" => generate_kills_by_means(log_kills)
    }
  }
end

def generate_kills(players, log_kills)
  return {} if log_kills.empty?

  world_deaths = log_kills.select { |killer, dead, mod| killer == '<world>'}.group_by { |item| item[1] }.map do |player, deaths_by_world|
    { player => deaths_by_world.count }
  end

  grouped_kills_per_players = log_kills.reject { |killer, dead, mod| killer == '<world>'}.group_by(&:first).map do |player, kills|
    { player => kills.count }
  end

  kills_per_player = {}

  players.each do |player|
    player_kills = grouped_kills_per_players.find { |kills| kills[player] }
    player_deaths = world_deaths.find { |deaths| deaths[player] }

    kills = player_kills ? player_kills.dig(player) : 0
    deaths_by_world = player_deaths ? player_deaths.dig(player) : 0

    kills_per_player[player] = kills - deaths_by_world
  end

  kills_per_player
end

def generate_kills_by_means(log_kills)
  log_kills.group_by do |log_kill|
    log_kill[2]
  end.map do |mod, kills|
    { mod => kills.count }
  end.inject(:merge)
end

File.foreach(FILE_PATH) do |raw_log_line|
  log_line = raw_log_line.chomp.strip

  case log_line
  when -> (line) { line.match(INIT_GAME_REGEX) } then
    game_id += 1

    already_started_a_game = game_id < 1

    next if already_started_a_game

    matches << render_current_game_data(
      game_id,
      current_match_kills,
      players.uniq,
      log_kills
    )

    log_kills = []
    current_match_kills = 0
    players = []
  when -> (line) { line.match(KILL_REGEX) } then
    current_match_kills += 1
    log_kills << log_line.match(KILL_REGEX).to_a.drop(1)
  when -> (line) { line.match(PLAYER_REGEX) } then
    player = log_line.match(PLAYER_REGEX)[1]
    players << player
  end
end

class PrettyJsonToFile
  require 'json'

  def initialize(data)
    @data = data
  end

  def generate_file
    File.open(file_name, 'wb') do |file|
      file.write(pretty_data)
    end
  end

  private

  attr_reader :data

  def file_name
    "#{Time.now.to_i}.json"
  end

  def pretty_data
    JSON.pretty_generate(data)
  end
end

PrettyJsonToFile.new(matches).generate_file
