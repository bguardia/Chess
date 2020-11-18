require 'json'

class Player

  attr_reader :name, :team

  def initialize(args = {})
    @name = args.fetch(:name, "")
    @team = args.fetch(:team, "")
  end

  def to_json
    JSON.dump({ :class => Player,
                :name => @name,
                :team => @team })
  end

  def self.from_json(json_str)
    data = JSON.load json_str
    data.transform_keys!(&:to_sym)
    Player.new(data)
  end
end
