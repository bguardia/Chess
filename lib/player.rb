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
    key_map = args.fetch(:key_map, nil) || {}
    @input_handler.get_input(key_map)
  end
=begin
  def self.from_json(json_str)
    data = JSON.load json_str
    data.transform_keys!(&:to_sym)
    Player.new(data)
  end
=end

end

module ComputerAI

  def piece_values
    { Pawn => 10,
      Knight => 30,
      Bishop => 30,
      Rook => 50,
      Queen =>  90,
      King => 900}
  end

  def get_move_value(move)
    captured = move.get_attr(:capture)
    unless captured.nil?
      modifier = captured.team == self.team ? -1 : 1
      piece_values[captured.class] * modifier
    else
      0
    end
  end

  def return_move(args)
    gamestate = args.fetch(:gamestate)
    best_move = minimax(gamestate, 2) 
  end

  def min(state, depth)
    if depth == 0 || state.checkmate?(other_team(self.team))
      mv = state.get_last_move
      return get_move_value(mv)
    end 
      moves = state.get_valid_moves
      min = Float::INFINITY
      moves.each do |mv|
        score = get_move_value(mv) + max(state, depth - 1)
        if score < min
          min = score
        end
      end
      return min
  end

  def max(state, depth)
    if depth == 0 || state.checkmate?(self.team)
      mv = state.get_last_move
      return get_move_value(mv)
    end

      moves = state.get_valid_moves
      max = -Float::INFINITY
      moves.each do |mv|
        state.do!(mv)
        score = get_move_value(mv) + min(state, depth - 1)
        state.undo
        if score > max
          max = score
        end
      end
    return max
  end

  def minimax(state, depth)
    moves = state.get_valid_moves
    best_move = nil
    max_value = -Float::INFINITY
    moves.each do |mv|
      state.do!(mv)
      score = min(state, depth - 1)
      state.undo
      if score > max_value
        best_move = mv
      end
    end

    return best_move    
  end

  def minimax_best_move(state, team, depth)
    moves = state.get_valid_moves 
    if depth == 0
      mv_val_pairs = moves.map { |mv| [mv, get_move_value(mv)] }
      return mv_val_pairs 
    else
      mv_val_pairs = moves.map do |mv|
        state.do!(mv)
        child_mv_val_pairs = minimax_best_move(state, other_team(team), max_depth, current_depth + 1)
        state.undo
        #get lowest value among child moves. If there are no moves, set to 0
        child_val = child_mv_val_pairs.empty? ? 0 : child_mv_val_pairs.reduce(child_mv_val_pairs[0][1]) { |lowest, pair| pair[1] < lowest ? pair[1] : lowest }
        [mv, child_val + get_move_value(mv)]
      end
      if current_depth == 0
        return mv_val_pairs.reduce(mv_val_pairs[0]) { |highest_pair, pair| pair[1] > highest_pair[1] ? pair : highest_pair }
      else
        return mv_val_pairs
      end
   end
  end

  def negamax(state, depth)
    moves = state.get_valid_moves
    scored_moves = moves.map do |mv|
      state.do!(mv)
      score = negamax_recursive(state, depth - 1, -1)
      state.undo
      [mv, score + get_move_value(mv)]
    end
  
    best_move = scored_moves.reduce(scored_moves[0]) do |best, score_move|
      score_move[1] > best[1] ? score_move : best
    end
    
    return best_move[0]
  end

  def negamax_recursive(state, depth, color)
    if depth == 0
      return get_move_value(state.get_last_move) * color
    end
    max = -Float::INFINITY
    moves = state.get_valid_moves
    moves.each do |mv|
      state.do!(mv)
      score = -negamax_recursive(state, depth - 1, -color)
      state.undo
      if score > max
        max = score
      end
    end
    return max
  end

  def return_random_move(args)
    gamestate = args.fetch(:gamestate)
    possible_moves = gamestate.get_moves(team: self.team).filter { |m| m.get_attr(:invalid) == false }
    prng = Random.new
    rand_index = prng.rand(possible_moves.length)
    return possible_moves[rand_index]
  end

  def get_shortest_branch(statetree, team, enemy)
    #if statetree.checkmate(team: enemy?)
    #  return true
    #elsif statetree.checkmate
    #end
  end

  def other_team(current_team)
    ["white", "black"].find { |t| t != current_team }
  end
end


class ComputerPlayer < Player
  include ComputerAI
  def get_input(args)
    return return_move(args)
  end

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
