require './lib/chess.rb'

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
      @origin = board.get_coords(piece)
      @moves = []
      @modifiable_moves = [[0,0]]
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
      
      on_board = moves.filter { |move| @board.cell_exists?(move) }

      unless @piece.kind_of?(Knight)
        on_board.filter! do |move|
          !Movement.blocked?(@piece, move, @board)
        end
      end

      #pawns cannot capture pieces unless moving diagonally,
      #so set :pawn_cap to true for diagonal movement
      if @piece.kind_of?(Pawn)
        unless args.fetch(:pawn_cap, false)
          on_board.filter! do |move|
            @board.get_piece_at(move).nil?
          end
        end
      end

      reset_moves
      reset_modifiable_moves
      return on_board
    end

  end

=begin
  def self.get_possible_moves(piece, board, include_special_moves = true)
    #Get all possible moves from current location
    possible_moves = piece.possible_moves(board)

    #Remove moves that are off-board or blocked
    possible_moves.filter! do |move|
      board.cell_exists?(move) && !blocked?(piece, move, board)
    end

    #Get special moves
    if include_special_moves
      special_moves = piece.special_moves(board)
      possible_moves << special_moves unless special_moves.nil? 
    end

    return possible_moves  
  end
=end

  def self.blocked?(piece, move, board, args = {})
    #return false if piece.kind_of?(Knight) #Knights can jump over pieces
    unless piece.kind_of?(Knight)
      #get the number of spaces between current_pos and move
      pos = board.get_coords(piece)
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

=begin
  def self.possible_move?(piece, move, board, args = {})
    moves = Movement.get_possible_moves(piece, board, true)
    return false if moves.empty?
    return moves.include?(move)
  end
=end

  def self.who_can_reach?(space, board, args = {})
    pieces = board.get_pieces(args)
    pieces.filter! do |piece|
      piece.possible_moves.include?(space)
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

    king_pos = board.get_coords(king)
    #$pieces_debug+=  "king's position is: #{king_pos}"

    can_reach = enemy_pieces.filter do |piece|
      piece.possible_moves(board).include?(king_pos)
    end

    return nil if can_reach.empty?
    return can_reach
  end

  def self.checkmate?(king, board)
    #$game_debug += "Movement.checkmate? called\n"
    can_reach = in_check?(king, board)
    return false unless can_reach
    #$game_debug += "king is currently in check\n"

    pieces = board.get_pieces(team: king.team)
    
    #$game_debug += "king's team is: #{king.team}\n"
    #$game_debug += "pieces are:\n#{pieces}\n"

    king_can_escape = king.possible_moves(board).any? do |move|
      sim_board = board.simulate_move(king, move)
      !Movement.in_check?(king, sim_board)
    end

    return false if king_can_escape

    #get important spaces to help cut down on calculations
    #important spaces include spaces between king and attacker,
    #as well as attacker positions
    king_pos = board.get_coords(king)
    important_spaces = []
    can_reach.each do |attacker|
      attack_pos = board.get_coords(attacker)
      important_spaces << Movement.get_spaces_between(king_pos, attack_pos)
      important_spaces << attack_pos
    end 

    checkmate = pieces.all? do |piece|
      $game_debug += "For #{piece.class} (id: #{piece.id})\n"
      piece.possible_moves(board).all? do |move|
        #if move can block or take attacking piece
        #simulate move and check state
        if important_spaces.include?(move)
          sim_board = board.simulate_move(piece, move)
          Movement.in_check?(king, sim_board)
        else
          true
        end
      end
    end
    return checkmate
  end
end


