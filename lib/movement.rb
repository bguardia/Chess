require './lib/chess.rb'


$movement_debug = ""

module Movement

  #create a new MovementArray with the given board and piece 
  #MovementArray's methods can be chained from here to create an array of possible moves
  def moves(piece, board)
    MovementArray.new(piece, board)
  end

  class MovementArray
   
    attr_reader :moves, :modifiable_moves, :origin 
    
    def initialize(piece, board)    
      @piece = piece
      @board = board
      @origin = board.get_pos(piece)
      @moves = []
      @modifiable_moves = [[0,0]]
      $movement_debug += "MovementArray.new called. @piece: #{@piece.class}, @origin: #{@origin}\n"
    end

    private
    def add_moves
      @modifiable_moves.each do |move|
        @moves << move.dup
      end
    end

    #applies a moves_arr to any currently modifiable moves (any moves defined before an #or call, or [0,0])
    def modify_moves(moves_arr)
      modified_moves = []
      @modifiable_moves.each do |one|
        moves_arr.each do |two|
          modified_moves << [ one[0] + two[0], one[1] + two[1] ]
        end
      end
      @modifiable_moves = modified_moves.dup
    end

    #creates an array of moves from separate x and y arrays
    #works well for two arrays of equal length, or one single element with another array of any size
    def create_moves_array(args)
      move_arr = []
      x = args.fetch(:x, [0])
      y = args.fetch(:y, [0])
      y_i = 0
      x_i = 0

      loop do
        move_arr << [y[y_i], x[x_i]]
        x_i += 1 if more_x = x_i < x.length - 1
        y_i += 1 if more_y = y_i < y.length - 1
        break unless more_x || more_y
      end

      return move_arr
    end

    def reset_modifiable_moves
      @modifiable_moves = [[0,0]]
    end
    
    def to_arr(n)
      if n.kind_of?(Array)
        return n
      elsif n.kind_of?(Integer)
        return [n]
      elsif n.kind_of?(Range)
        return n.to_a
      end
    end

    def reset_moves
      @moves = []
    end

    #Movement methods are chained to create arrays of possible positions
    #Methods can accept an Integer or a Range/Array of Integers
    #  A single Integer creates a single move
    #  A Range or Array will create a position for each element
    #Methods can be changed with #and, #or and #up_to methods to create more complex movements
    #
    #Finally, ending the chain with #spaces will return a final array of moves based on the origin
    public
    def horizontally(n)
      n = to_arr(n)
      n = n.concat(n.map { |n| -n })
      moves_arr = create_moves_array(x: n)
      modify_moves(moves_arr)
      return self
    end

    def diagonally(n)
      positive_n = to_arr(n)
      negative_n = positive_n.map { |num| -num }

      moves_arr = []
      moves_arr.concat create_moves_array(x: positive_n, y: positive_n ) #down-right
      moves_arr.concat create_moves_array(x: positive_n, y: negative_n ) #up-right
      moves_arr.concat create_moves_array(x: negative_n, y: negative_n ) #down-left
      moves_arr.concat create_moves_array(x: negative_n, y: positive_n ) #up-left

      modify_moves(moves_arr)
      return self
    end

    def vertically(n)
      n = to_arr(n)
      n = n.concat(n.map { |n| -n })
      moves_arr = create_moves_array(y: n)
      modify_moves(moves_arr)
      return self
    end

    def up(n) 
      num_moves = to_arr(n).map { |y| -y }
      moves_arr = create_moves_array(y: num_moves)
      modify_moves(moves_arr)
      return self
    end

    def down(n) 
      num_moves = to_arr(n)
      moves_arr = create_moves_array(y: num_moves)
      modify_moves(moves_arr)
      return self
    end

    def left(n)
      num_moves = to_arr(n).map { |x| -x }
      moves_arr = create_moves_array(x: num_moves)
      modify_moves(moves_arr)
      return self
    end

    def right(n)
      num_moves = to_arr(n)
      moves_arr = create_moves_array(x: num_moves)
      modify_moves(moves_arr)
      return self
    end

    #Generates a different direction based on piece's team
    def forward(n)
      if @piece.team == "black"
        down(n)
      elsif @piece.team == "white"
        up(n)
      end
      return self
    end
    
    #Will multiply @modifiable_moves n times
    def up_to(n)
      return self unless n >= 2
      m = 1
      modified_moves = []
      n.times do
        @modifiable_moves.each do |move|
          modified_moves << [ move[0] * m, move[1] * m ]
        end
        m += 1
      end
      @modifiable_moves = modified_moves.dup
      return self
    end

    #Currently has no logical purpose, only exists in contrast with #or, and makes method chains more human-readable
    def and
      return self
    end

    #Takes all moves generated up to this method and moves them to the @moves array, protecting them from further modification
    #For example, a knight's possible moves can be described as: #horizontally(2).and.vertically(1).or.vertically(2).and.horizontally(1).spaces
    def or
      add_moves
      reset_modifiable_moves
      return self
    end

    def spaces(args = {})
      add_moves
      moves = @moves.map { |move| [move[0] + @origin[0], move[1] + @origin[1]] }
      
      $movement_debug += "Spaces called. Calculated positions are: #{moves}\n"

      on_board = moves.filter do |pos|
        valid_r = pos[0] >= 0 && pos[0] <= 7
        valid_f = pos[1] >= 0 && pos[1] <= 7
        valid_r && valid_f
      end

      $movement_debug += "Positions off board have been filtered. Now: #{on_board}\n"

      unless @piece.kind_of?(Knight)
        $movement_debug += "Piece is not a knight. Filtering blocked moves...\n"
        on_board.filter! do |move|
          !Movement.blocked?(@piece, move, @board)
        end
        $movement_debug += "Blocked moves have been filtered. Remaining moves: #{on_board}\n"
      end

      #pawns cannot capture pieces unless moving diagonally,
      #so set :pawn_cap to true for diagonal movement
      if @piece.kind_of?(Pawn)
        unless args.fetch(:pawn_cap, false)
          $movement_debug += "Piece is a pawn and :pawn_cap is false. Filtering positions with pieces...\n"
          on_board.filter! do |move|
            @board.get_piece_at(move).nil?
          end
          $movement_debug += "Positions have been filtered. Remaining moves: #{on_board}\n"
        end
      end

      reset_moves
      reset_modifiable_moves
      return on_board
    end

  end

  def self.blocked?(piece, move, board, args = {})
    #return false if piece.kind_of?(Knight) #Knights can jump over pieces
    unless piece.kind_of?(Knight)
      #get the number of spaces between current_pos and move
      pos = board.get_pos(piece)
      spaces_between = get_spaces_between(pos, move)

      #If piece is a pawn, add destination to spaces_between array
      #Pawns can't take enemy pieces through normal movement
      
      
      #return true if there are any pieces between the piece and the destination
      pieces = spaces_between.map { |s| board.get_piece_at(s) }.compact
      
      return true unless pieces.empty?
    end

    #Check destination space unless explicitly :ignore_dest is true
    unless args.fetch(:ignore_dest, false)
      dest_piece = board.get_piece_at(move)  
      return false if dest_piece.nil?
      return true if dest_piece.team == piece.team
    end

    return false
  end

  def self.who_can_reach?(pos, board, args = {})
    pieces = board.get_pieces(args)
    pieces.filter! do |piece|
      piece.can_reach?(pos)
    end

    return pieces
  end

  #Returns an array of coordinates between two given coordinates
  def self.get_spaces_between(a, b)
    spaces_between = []

    #Get duplicates of arrays so as not to harm originals
    start = a.dup
    dest = b.dup

    while start[0] != dest[0] || start[1] != dest[1]
      if start[0] < dest[0]
        start[0] += 1
      elsif start[0] > dest[0]
        start[0] -= 1
      end

      if start[1] < dest[1]
        start[1] += 1
      elsif start[1] > dest[1]
        start[1] -= 1
      end
      
      spaces_between << start.dup
    end

    spaces_between.pop

    return spaces_between
  end

  def self.in_check?(king, board)
    op_team = ["white", "black"].find { |t| t != king.team }

    enemy_pieces = board.get_pieces(team: op_team)

    king_pos = king.current_pos
    #$pieces_debug+=  "king's position is: #{king_pos}"

    can_reach = enemy_pieces.filter do |piece|
      piece.can_move_to?(king_pos, board)
    end

    return nil if can_reach.empty?
    return can_reach
  end

  def self.checkmate?(king, board)
    #return false unless king is in check
    can_reach = in_check?(king, board)
    return false unless can_reach


    #first check if king can escape from check on its own
    king_can_escape = king.possible_moves.any? do |move|
      board.do(move)
      not_in_check = !Movement.in_check?(king, board)
      board.undo(move)
      not_in_check
    end

    return false if king_can_escape

    #get important spaces to help cut down on calculations
    #important spaces include spaces between king and attacker,
    #as well as attacker positions
    king_pos = king.current_pos
    important_spaces = []
    can_reach.each do |attacker|
      attack_pos = attacker.current_pos
      important_spaces << Movement.get_spaces_between(king_pos, attack_pos)
      important_spaces << attack_pos
    end 

    #check possible moves of other ally pieces
    pieces = board.get_pieces(team: king.team)
    checkmate = pieces.all? do |piece|
      piece.possible_moves.all? do |mv|
        #if move can block or take attacking piece
        #simulate move and check state
        mv.all? do |piece, pos_arr|
          pos = pos_arr[1]
          if important_spaces.include?(pos)
            board.do(mv)
            check = Movement.in_check?(king, sim_board)
            board.undo(mv)
            check
          else
            true
          end
        end
      end
    end
    return checkmate
  end

  def self.return_move(piece_pos, dest_pos, board)
    $game_debug += "called Movement.return_move(#{piece_pos}, #{dest_pos}, board)\n"
    piece = board.get_piece_at(piece_pos)
    return EmptyMove.new if piece.nil?

    moves = piece.possible_moves

    $game_debug += "Piece is: #{piece.class} (#{piece.id})\n"
    $game_debug += "Moves are:\n"
    moves.each do |mv|
      $game_debug += mv.to_s
    end

    #check for any moves matching given destination
    #and return first match
    moves.each do |mv|
      $game_debug += mv.to_s
      if mv.destination(piece) == dest_pos
        $game_debug += "Move matched to #{dest_pos}\n"
        return mv
      end
    end
    #return nil if none match
    return EmptyMove.new #empty move 
  end

  def self.create_move(move_arr, type)
    move = Move.new(move: move_arr, type: type) 
    return move
  end

  def self.add_to_move(move, piece2, dest_pos2)
     move.merge({ piece2 => [piece2.current_pos, dest_pos2] })
  end

  def promotion?(piece)
    if piece.kind_of?(Pawn)
      final_rank = piece.team == "white" ? 0 : 7
      if piece.current_pos[0] == final_rank
        return true
      end
    end
    return false
  end
end

class Move

  def initialize(args = {})
    @instructions = prepare_arr(args.fetch(:move, nil)) # [ [piece, current_pos, next_pos] ] 
    @turn = args.fetch(:team, nil) || get_team #:white, :black
    #additional information about a move
    @attributes = { :type => args.fetch(:type, nil),        #:normal, :en_passant, :castle, :promotion   
                    :blocked? => args.fetch(:blocked?, nil),  
                    :capture => args.fetch(:capture?, nil),
                    :check? => false,
                    :checkmate => false,
                    :notation => nil     }
  end

  def get_team
    if @instructions
      @instructions.first[0].team
    else
      nil
    end
  end

  def prepare_arr(arr)
    return nil if arr.nil?

    if arr.flatten == arr
      return [arr]
    else
      return arr
    end
  end

  def set_attr(attr, val)
    return nil unless @attributes.has_key?(attr)
    @attributes[attr] = val
  end

  def get_attr(attr)
    @attributes[attr]
  end

  def include?(pos)
    @instructions.each do |move_arr|
      move_arr[1..2].each do |move_pos|
        return true if move_pos == pos
      end
    end

    return false
  end

  def each (&block)
    @instructions.each do |move|
      block.call(move)
    end
  end

  def get_piece
    if @instructions
      @instructions.first.first
    else
      nil
    end
  end

  def destination(piece)
    @instructions.each do |move_arr|
      if move_arr[0] == piece
        return move_arr[2]
      end
    end

    return nil
  end

  def to_s
    str = "Move:\n"
    each do |p, cur_pos, dest_pos|
      str += "-> #{p.class} (#{p.id}), #{cur_pos}, #{dest_pos}\n"
    end
    return str
  end
end

class EmptyMove < Move
  
  def each (&block); end
  def destination(piece); end
  def include?(pos); end
  def set_attr(attr, val); end
  def get_attr(attr); end

end

=begin
class Move
  attr_reader :piece, :prev_pos, :pos, :removed, :castle, :promotion, :notation
  
  def initialize(board, args)
    @moves = []
    @piece = args.fetch(:piece)
    @prev_pos = args.fetch(:prev_pos)
    @pos = args.fetch(:pos)
    @removed = args.fetch(:removed, nil)
    @castle = args.fetch(:castle, false)
    @promotion = args.fetch(:promotion, false)
    @notation = args.fetch(:notation, false) || ChessNotation.to_notation(@prev_pos, @pos, @board)
  end

  def get_from_notation(note, board)
    ChessNotation.from_notation(note, board)
  end

  def get_notation(prev_pos, pos, board)
    ChessNotation.get_notation(prev_pos, pos, board)
  end

  def get_from_array(pos_arr, board)
    $game_debug += "called Move.get_from_array(#{pos_arr}, board)\n"
    ChessNotation.translate_move(pos_arr[0], pos_arr[1], board)
  end

  def self.simulate(board, prev_pos, pos)
    Move.new(board, [prev_pos, pos])
  end

  def set_removed(removed)
    @removed = removed
  end

  def get_removed
    @removed
  end

  def get_move
    { piece: @piece,
      pos: @new_pos } 
  end

  def reverse_move
    { piece: @piece,
      pos: @prev_pos }
  end

  def do(board)
    board.move(@piece, @pos)
    if @castle
      board.move(@castle[:piece], @castle[:pos]) 
    end
  end
end

=end
