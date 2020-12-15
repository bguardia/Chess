require './lib/chess.rb'
require 'json'

$pieces_debug = ""

module Movement

  #create a new MovementArray originating at the current_pos
  #MovementArray's methods can be chained from here to create an array of possible moves
  def from(piece)
    MovementArray.new(piece)
  end

  class MovementArray
   
    attr_reader :moves, :modifiable_moves, :origin 
    
    def initialize(piece)    
      @piece = piece
      @origin = piece.current_pos
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

    #Takes all generated moves and creates positions based on the @origin position
    #and returns an array of positions. @moves and @modifiable_moves are also reset.
    #
    #This method should always be called at the end of a method chain.
    def spaces(filters = {})
      on_board = filters.fetch(:on_board, true)
      not_blocked = filters.fetch(:no_blocked, true)

      add_moves
      moves = @moves.map { |move| [ move[0] + @origin[0], move[1] + @origin[1] ] }
      
      
      if on_board
        board = @piece.board
        moves.filter! { |move| board.cell_exists?(move) }
      end

      if not_blocked
        board ||= @piece.board
        moves.filter! { |move| !Movement.blocked?(@piece, move, board) }
      end

      reset_moves
      reset_modifiable_moves
      return moves
    end

    def spaces_on(board)
      moves = spaces
      
      on_board = moves.filter { |move| board.cell_exists?(move) }

      unless @piece.kind_of?(Knight)
        on_board.filter! do |move|
          !Movement.blocked?(@piece, move, board)
        end
      end

      return on_board
    end

  end

  def self.get_possible_moves(piece, board, include_special_moves = true)
    #Get all possible moves from current location
    possible_moves = piece.possible_moves

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

  def self.blocked?(piece, move, board, args = {})
    return false if piece.kind_of?(Knight) #Knights can jump over pieces

    #get the number of spaces between current_pos and move
    spaces_between = get_spaces_between(piece.current_pos, move)

    #If piece is a pawn, add destination to spaces_between array
    #Pawns can't take enemy pieces through normal movement

    
    #return true if there are any pieces between the piece and the destination
    pieces = spaces_between.map { |s| board.get_piece_at(s) }.compact
    
    return true unless pieces.empty?
    
    #Check destination space unless explicitly :ignore_dest is true
    unless args.fetch(:ignore_dest, false)
      dest_piece = board.get_piece_at(move)  
      return false if dest_piece.nil?
      return true if dest_piece.team == piece.team
    end

    return false
  end

  def self.possible_move?(piece, move, board, args = {})
    moves = Movement.get_possible_moves(piece, board, true)
    return false if moves.empty?
    return moves.include?(move)
  end

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

    king_pos = king.current_pos

    $pieces_debug+=  "king's position is: #{king_pos}"

    enemy_pieces.any? do |piece|
      $pieces_debug+=  "piece: #{piece}"
      $pieces_debug+=  "possible_moves: #{piece.possible_moves}"
      piece.possible_moves.include?(king_pos)
    end
  end

  def self.checkmate?(king, board)
    return false unless in_check?(king, board)

    pieces = board.get_pieces(team: king.team)

    $pieces_debug+=  "pieces on king's team:"
    pieces.each { |p| $pieces_debug+=  p }

    pieces.all? do |piece|
      $pieces_debug+=  "current piece: #{piece.class}"
      piece.possible_moves.all? do |move|
        $pieces_debug+=  ">current_move: #{move}"
        #simulate move, check for check
        #if not check, it is not checkmate
        board.move(piece, move)
        in_check = in_check?(king, board)
        $pieces_debug+=  "in_check?: #{in_check}"
        board.rewind(1)
        $pieces_debug+=  board
        in_check
      end
    end
  end
end

module Pieces

  @@positions = { "black" => { :pawns => Array.new(8,1).zip((0..7).to_a),
                               :rooks => Array.new(2,0).zip([0,7]),
                               :knights => Array.new(2,0).zip([1,6]),
                               :bishops => Array.new(2,0).zip([2,5]),
                               :queen => [0,3],
                               :king => [0,4]       },
                  "white" =>  { :pawns => Array.new(8,6).zip((0..7).to_a),
                                :rooks => Array.new(2,7).zip([0,7]),
                                :knights => Array.new(2,7).zip([1,6]),
                                :bishops => Array.new(2,7).zip([2,5]),
                                :queen => [7,3],
                                :king => [7,4]       }
  }

  def Pieces.new_set(team)
    set = []
    set.concat(pawns(team))
    set.concat(rooks(team))
    set.concat(bishops(team))
    set.concat(knights(team))
    set << king(team)
    set << queen(team)
    
    return set
  end

  def Pieces.pawns(team)
    pawns = []
    @@positions[team][:pawns].each do |pos|
      pawns << Pawn.new(team: team, starting_pos: pos)
    end
    return pawns
  end

  def Pieces.rooks(team)
    rooks = []
    @@positions[team][:rooks].each do |pos|
      rooks << Rook.new(team: team, starting_pos: pos)
    end
    return rooks
  end

  def Pieces.bishops(team)
    bishops = []
    @@positions[team][:bishops].each do |pos|
      bishops << Bishop.new(team: team, starting_pos: pos)
    end
    return bishops
  end
 
  def Pieces.knights(team)
    knights = []
    @@positions[team][:knights].each do |pos|
      knights << Knight.new(team: team, starting_pos: pos)
    end
    return knights
  end

  def Pieces.king(team)
    pos = @@positions[team][:king]
    king = King.new(team: team, starting_pos: pos)
  end

  def Pieces.queen(team)
    pos = @@positions[team][:queen]
    queen = Queen.new(team: team, starting_pos: pos)
  end

end

class Piece

  include Movement

  @@moved_last_turn = nil #stores the piece that moved last

  attr_reader :team, :board

  def initialize(args = {})
    @team = args.fetch(:team, "")
    @starting_pos = args.fetch(:starting_pos, [0,0]) 
    @icon = args.fetch(:icon, false) || get_icon
    @moved = args.fetch(:moved, false)
    @board = args.fetch(:board, nil)
  end

  def set_pos(pos)
    @current_pos = pos
  end

  def starting_pos
    @starting_pos
  end
  
  def previous_pos
  end

  def current_pos
    @board.get_coords(self)
  end

  #Get either white_icon or black_icon from subclasses
  def get_icon
    if @team == "white"
      white_icon
    else
      black_icon
    end
  end

  def white_icon; end
  def black_icon; end

  def to_json
    JSON.dump({ :class => self.class,
                :icon => @icon,
                :team => @team,
                :current_pos => @current_pos,
                :moved => @moved })
  end

  def self.from_json(json_string)
    data = JSON.load json_string
    data.transform_keys!(&:to_sym)
    Kernel.const_get(data[:class]).new(data)
  end

  #Pieces class keeps track of the last moved piece
  #Used to check for certain moves such as en passant
  #which must be performed on the piece that moved last
  def self.update_last_moved(piece)
    @@moved_last_turn = piece
  end

  public
  def moved_last_turn?
    self == @@moved_last_turn
  end

  #Subclasses must define their own behavior for possible_moves and special_moves
  #Special moves are any moves that require a greater context, such as en passant or castling,
  #therefore requiring board to be passed as an argument
  def possible_moves(board = @board); end

  def special_moves(board = @board); end

  def set_moved(bool)
    @moved = bool
  end

  def moved?
    @moved
  end

  def add_to_board(board)
    board.place(self, self.starting_pos)
    @board = board
  end

  def to_s
    @icon
  end

  #Pieces require a possible_moves class
  #An array of possible moves can be created using the Movement module (see above)
end

class Queen < Piece

  def white_icon
    "\u2655"
  end

  def black_icon
    "\u265B"
  end

  def possible_moves(board = @board)
    from(self).vertically(1..7).or.
      horizontally(1..7).or.
      diagonally(1..7).spaces
  end

end

class Rook < Piece

  def white_icon
    "\u2656" 
  end

  def black_icon
    "\u265C"
  end

  def possible_moves(board = @board)
    from(self).horizontally(1..7).or.
      vertically(1..7).spaces
  end

end

class Knight < Piece

  def white_icon
    "\u2658"
  end

  def black_icon
    "\u265E"
  end

  def possible_moves(board = @board)
    from(self).horizontally(2).and.vertically(1).or.
      vertically(2).and.horizontally(1).spaces
  end

end

class King < Piece

  def white_icon
    "\u2654"
  end

  def black_icon
    "\u265A"
  end

  def possible_moves(board = @board)
    #regular movement
    from(self).horizontally(1).or.vertically(1).or.diagonally(1).spaces
    #in check..
    #castling..
  end

  def special_moves(board = @board)
    special_moves_arr = []

    #Castling
    #When nor the king nor a rook have moved
    #and there are no pieces in between them
    #and the king is not in check at any of the positions
    #allow movement of both rook and king
    if !moved?
      #Check for ally rooks on same row
      #If not on same row, they have already moved and are ineligible for castling
      row = self.current_pos[0]
      rooks = board.get_pieces(team: self.team).filter { |p| p.kind_of?(Rook) }

      if !rooks.empty?
        #Check if spaces_on(board) between rook and king are empty
        rooks.filter! do |rook|
          !Movement.blocked?(rook, self.current_pos, board, ignore_dest: true)
        end

        return [] if rooks.empty?
      
        moves = []
        rooks.each do |rook|
          if rook.current_pos[1] > self.current_pos[1]
            move = [row, self.current_pos[1] + 2]
          else
            move = [row, self.current_pos[1] - 2]
          end
          moves << move
        end

        #Check for check at any square along the path
        moves.select! do |move|
          #Get spaces_on(board) between moves
          #Check if any space between moves can be reached by an enemy piece
          !Movement.get_spaces_between(self.current_pos, move).any? do |space|
            Movement.who_can_reach?(space, board).any? do |piece|
              piece.team != self.team
            end
          end
        end

      return moves
    end
   end
  end 
end

class Bishop < Piece

  def white_icon
    "\u2657"
  end

  def black_icon
    "\u265D"
  end

  def possible_moves(board = @board)
    from(self).diagonally(1..7).spaces
  end

end

class Pawn < Piece

  def white_icon
    "\u2659"
  end

  def black_icon
    "\u265F"
  end

  def possible_moves(board = @board)
    #if first move
    unless @moved
      from(self).forward(1..2).spaces
    else
      #if not first move
      from(self).forward(1).spaces
    end
  end

  def special_moves(board = @board)
    special_moves_arr = []

    #Diagonal pawn captures
    df_moves = from(self).forward(1).and.horizontally(1).spaces(no_blocked: false)
    df_moves.each do |move|
      something = board.get_piece_at(move)
      if something && something.team != team
        special_moves_arr << move
      end
    end


    #En passant
    #If an enemy piece moves to a square horizontally adjacent to a pawn
    #the pawn can capture it on the next turn
    if (self.current_pos[0] - self.starting_pos[0]).abs == 3 
      adj_moves = from(self).horizontally(1).spaces(no_blocked: false)
      adj_moves.each_index do |index|
        something = board.get_piece_at(adj_moves[index])
        if something && something.kind_of?(Pawn)
          if something.moved_last_turn? && something.previous_pos == something.starting_pos
            special_moves_arr << df_moves[index] #Add diagonally forward move of same index
          end
        end
      end
    end

    return special_moves_arr
  end
end

