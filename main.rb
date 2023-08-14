require_relative 'log_reader'
require_relative 'pretty_json_to_file'

LOG_FILE_PATH = 'qgames.log'.freeze

log_reader = LogReader.new(LOG_FILE_PATH)
matches = log_reader.render_log_data

pretty_json_to_file = PrettyJsonToFile.new(matches)
pretty_json_to_file.generate_file