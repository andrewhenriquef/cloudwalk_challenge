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
