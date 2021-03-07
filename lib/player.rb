#require './lib/chess.rb'

class Player < Saveable
  attr_reader :name, :team

  @@num_players = 0
  def initialize(args = {})
    @@num_players += 1
    @id = args.fetch(:id, nil) || @@num_players
    @name = args.fetch(:name, nil) || "Player #{@id}"
    @team = args.fetch(:team, "")
    @input_handler = args.fetch(:input_handler, nil)
  end

=begin
  def to_json
    JSON.dump({ :class => Player,
                :name => @name,
                :team => @team })
  end
=end

  def team=(team)
    @team = team
  end

  def set_input_handler(input_handler)
    @input_handler = input_handler
  end

  def get_input(args)
    @input_handler.get_input(args)
  end
=begin
  def self.from_json(json_str)
    data = JSON.load json_str
    data.transform_keys!(&:to_sym)
    Player.new(data)
  end
=end

end


class InputHandler

  attr_reader :received_input

  def initialize(args)
    @key_map = args.fetch(:key_map, {})
    @received_input = nil
    @interactive = args.fetch(:in)
    @break = false
  end

  def get_input(key_map_arg = {})
    @interactive.before_get_input
    @break = false
    @requested = nil
    loop do
      #Key map is constantly updated. Order of preference:
      #Map passed through args > window args > default args
      key_map = @key_map.merge(@interactive.key_map).merge(key_map_arg)
      input = @interactive.get_input 
      if key_map.has_key?(input)
        if key_map[input].kind_of?(String) && @interactive.respond_to?(key_map[input])
          action = @interactive.get_action(key_map[input])
        else
          action = key_map[input]
        end
         action.call
      else
        @interactive.handle_unmapped_input(input)
      end

      @interactive.check_focus

      break if break_condition
    end 

    @interactive.post_get_input 
    return_input
  end

  def request(data)
    @requested = data
  end

  def break_condition
    @break || @interactive.break_condition
  end

  public
  def break
    @break = true
  end

  def return_input
    @requested || @interactive.return_input
  end
end

=begin
  Actual module in lib/window.rb
  Just here for comparison with InputHandler, which takes InteractiveWindows
  module InteractiveWindow
    #A module that allows an input source to interactive with input handler
    #The default methods are an example of using $stdin
    def interactive
      true
    end

    #Stores any special keys used by a paticular context
    #(Will be over-ridden by arguments passed to input_handler)
    def key_map
      {}
    end

    #Called during InputHandler's get_input loop
    def before_get_input; end
    def post_get_input; end
    def get_input
      @input_to_return = gets.chomp #Wrap gets or win.getch so other objects don't need to know the difference
    end

    #Method to handle returned input if the input is not a special character
    def handle_unmapped_input(input); end

    def break_condition
      true #Because gets.chomp returns input as soon as entered is pressed, loop should automatically break
    end

    #Add new context based on key press
    def update_key_map; end

    #A way for window/io to return its input
    def return_input
      @input_to_return
    end
  end
=end
