#require './lib/chess.rb'

class Player < Saveable
  attr_reader :name, :team

  @@num_players = 0
  def initialize(args = {})
    @@num_players += 1
    @id = args.fetch(:id, nil) || @@num_players
    @name = set_name(args)
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

  def set_name(args)
    name = args.fetch(:name, nil)
    if name.nil? || name == ""
      name = self.class.to_s + " #{@id}"
    else
      name
    end
  end

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
  #Values taken from https://www.chessprogramming.org/Simplified_Evaluation_Function
  PAWN_BOARD = [[0,  0,  0,  0,  0,  0,  0,  0],
                [50, 50, 50, 50, 50, 50, 50, 50],
                [10, 10, 20, 30, 30, 20, 10, 10],
                [5,  5, 10, 25, 25, 10,  5,  5],
                [0,  0,  0, 20, 20,  0,  0,  0],
                [5, -5,-10,  0,  0,-10, -5,  5],
                [5, 10, 10,-20,-20, 10, 10,  5],
                [0,  0,  0,  0,  0,  0,  0,  0]]

  KNIGHT_BOARD = [[-50,-40,-30,-30,-30,-30,-40,-50],
                 [-40,-20,  0,  0,  0,  0,-20,-40],
                 [-30,  0, 10, 15, 15, 10,  0,-30],
                 [-30,  5, 15, 20, 20, 15,  5,-30],
                 [-30,  0, 15, 20, 20, 15,  0,-30],
                 [-30,  5, 10, 15, 15, 10,  5,-30],
                 [-40,-20,  0,  5,  5,  0,-20,-40],
                 [-50,-40,-30,-30,-30,-30,-40,-50]]


  BISHOP_BOARD = [[-20,-10,-10,-10,-10,-10,-10,-20],
                 [ -10,  0,  0,  0,  0,  0,  0,-10],
                 [ -10,  0,  5, 10, 10,  5,  0,-10],
                 [ -10,  5,  5, 10, 10,  5,  5,-10],
                 [ -10,  0, 10, 10, 10, 10,  0,-10],
                 [ -10, 10, 10, 10, 10, 10, 10,-10],
                 [ -10,  5,  0,  0,  0,  0,  5,-10],
                 [ -20,-10,-10,-10,-10,-10,-10,-20]]

  ROOK_BOARD = [[  0,  0,  0,  0,  0,  0,  0,  0],
                [  5, 10, 10, 10, 10, 10, 10,  5],
                [ -5,  0,  0,  0,  0,  0,  0, -5],
                [ -5,  0,  0,  0,  0,  0,  0, -5],
                [ -5,  0,  0,  0,  0,  0,  0, -5],
                [ -5,  0,  0,  0,  0,  0,  0, -5],
                [ -5,  0,  0,  0,  0,  0,  0, -5],
                [  0,  0,  0,  5,  5,  0,  0,  0]]

  QUEEN_BOARD = [[-20,-10,-10, -5, -5,-10,-10,-20],
                 [ -10,  0,  0,  0,  0,  0,  0,-10],
                 [ -10,  0,  5,  5,  5,  5,  0,-10],
                 [  -5,  0,  5,  5,  5,  5,  0, -5],
                 [   0,  0,  5,  5,  5,  5,  0, -5],
                 [ -10,  5,  5,  5,  5,  5,  0,-10],
                 [ -10,  0,  5,  0,  0,  0,  0,-10],
                 [ -20,-10,-10, -5, -5,-10,-10,-20]]

  KING_BOARD = [[-30,-40,-40,-50,-50,-40,-40,-30],
                [ -30,-40,-40,-50,-50,-40,-40,-30],
                [ -30,-40,-40,-50,-50,-40,-40,-30],
                [ -30,-40,-40,-50,-50,-40,-40,-30],
                [ -20,-30,-30,-40,-40,-30,-30,-20],
                [ -10,-20,-20,-20,-20,-20,-20,-10],
                [  20, 20,  0,  0,  0,  0, 20, 20],
                [  20, 30, 10,  0,  0, 10, 30, 20]]

  def get_space_value(piece, space, team)
    table_hash = { Pawn => PAWN_BOARD,
                   Knight => KNIGHT_BOARD,
                   Bishop => BISHOP_BOARD,
                   Rook => ROOK_BOARD,
                   Queen => QUEEN_BOARD,
                   King => KING_BOARD }

    r = space[0]
    f = space[1]
    board = table_hash[piece.class]

    if team == "black"
      board = board.reverse 
    end

    return board[r][f]
  end

  def piece_values
    { Pawn => 100,
      Knight => 320,
      Bishop => 330,
      Rook => 500,
      Queen =>  900,
      King => 20000}
  end

  def get_move_value(move)
    #$game_debug += "move: #{move}\n"
    piece = move.get_piece
    pos = move.destination(piece)
    if pos.nil?
      piece = move.get_promoted
      pos = move.destination(piece)
    end

    captured = move.get_attr(:capture)

    space_val = get_space_value(piece, pos, piece.team)
    #$game_debug += "space_val: #{space_val}\n"
    capture_val = 0
    unless captured.nil?
      capture_val = piece_values[captured.class]
    end

    modifier = piece.team == self.team ? 1 : -1 
    return modifier * (space_val + capture_val)
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
      #$game_debug += "move (score: #{score}): #{mv}\n"
      state.undo
      if score > max_value
        best_move = mv
        max_value = score
      end
    end

    #$game_debug += "Selected move was: #{best_move} (score: #{max_value})"
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
