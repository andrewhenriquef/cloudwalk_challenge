
FILE_PATH = 'qgames.log'.freeze
INIT_GAME_REGEX = /.+(InitGame:).+/
KILL_REGEX = /.+: (.*) killed (.*?) by (.+)/
PLAYER_REGEX = /.+ n\\(.*?)\\t.+/

game_id = 0
matches = []
players = []
current_match_kills = 0
log_kills = []

def render_match_data(game_id, total_kills, players, log_kills)
  {
    "game_#{game_id}" => {
      "total_kills" => total_kills,
      "players" => players.uniq,
      "kills" => generate_kills_per_player(players, log_kills),
      "kills_by_means" => generate_kills_by_means(log_kills)
    }
  }
end

def generate_kills_per_player(players, log_kills)
  return {} if log_kills.empty?

  players_kills = count_of_players_kills(log_kills)
  worlds_kills = count_of_players_deaths_by_world(log_kills)

  kills_per_player = players.map do |player|
    player_kills = players_kills.find { |kills| kills[player] }
    player_deaths = worlds_kills.find { |deaths| deaths[player] }

    kills = entity_kills(player_kills, player)

    deaths_by_world = entity_kills(player_deaths, player)

    { player => kills - deaths_by_world }
  end

  kills_per_player.inject(:merge)
end

def count_of_players_deaths_by_world(log_kills)
  world_kills = log_kills.select { |killer, dead, mod| killer == '<world>'}
  world_kills_grouped_by_killed = world_kills.group_by { |item| item[1] }
  world_kills_grouped_by_killed.map do |player, deaths_by_world|
    { player => deaths_by_world.count }
  end
end

def count_of_players_kills(log_kills)
  player_kills = log_kills.reject { |killer, dead, mod| killer == '<world>'}
  player_kills_grouped_by_killer = player_kills.group_by(&:first)
  player_kills_grouped_by_killer.map do |player, kills|
    { player => kills.count }
  end
end

def entity_kills(kills_data, player)
  return 0 if kills_data.nil?

  kills_data.dig(player)
end

def generate_kills_by_means(log_kills)
  return {} if log_kills.empty?

  kills_grouped_by_mod = log_kills.group_by { |log_kill| log_kill[2] }

  kills_by_mods = kills_grouped_by_mod.map do |mod, kills|
    { mod => kills.count }
  end

  kills_by_mods.inject(:merge)
end

File.foreach(FILE_PATH) do |raw_log_line|
  log_line = raw_log_line.chomp.strip

  case log_line
  when -> (line) { line.match(INIT_GAME_REGEX) } then
    already_started_a_game = game_id > 0

    if already_started_a_game
      matches << render_match_data(
        game_id,
        current_match_kills,
        players.uniq,
        log_kills
      )

      log_kills = []
      current_match_kills = 0
      players = []
    end

    game_id += 1
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
