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

  def get_input(input_handler)
    loop do
      input = gets.chomp
      continue_bool = input_handler.interpret(input)
      break unless continue_bool
    end
  end

  def self.from_json(json_str)
    data = JSON.load json_str
    data.transform_keys!(&:to_sym)
    Player.new(data)
  end
end


=begin
class InputHandler
  include ChessNotation

  attr_reader :received_input

  def initialize(args)
    @special_keys = args.fetch(:special_keys, {})
    @board = args.fetch(:board, nil)
    @received_input = nil
  end

  def interpret(input)
    hit_special_key = @special_keys.has_key?(input)
    
    if hit_special_key
      @special_keys[input]
    else
      @received_input = notation
    end
  end
end
=end

