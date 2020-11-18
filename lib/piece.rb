$: << "."
require 'chess'
require 'json'

module Movement

  #create a new MovementArray originating at the current_pos
  #MovementArray's methods can be chained from here to create an array of possible moves
  def from(current_pos)
    MovementArray.new(current_pos)
  end

  class MovementArray
   
    attr_reader :moves, :modifiable_moves, :origin 
    
    def initialize(origin = [0,0])    
      @origin = origin
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
    def forward(n, piece)
      if piece.team == "black"
        down(n)
      elsif piece.team == "white"
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
    def spaces
      add_moves
      moves = @moves.map { |move| [ move[0] + @origin[0], move[1] + @origin[1] ] }
      reset_moves
      reset_modifiable_moves
      return moves
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
      pawns << Pawn.new(team: team, current_pos: pos)
    end
    return pawns
  end

  def Pieces.rooks(team)
    rooks = []
    @@positions[team][:rooks].each do |pos|
      rooks << Rook.new(team: team, current_pos: pos)
    end
    return rooks
  end

  def Pieces.bishops(team)
    bishops = []
    @@positions[team][:bishops].each do |pos|
      bishops << Bishop.new(team: team, current_pos: pos)
    end
    return bishops
  end
 
  def Pieces.knights(team)
    knights = []
    @@positions[team][:knights].each do |pos|
      knights << Knight.new(team: team, current_pos: pos)
    end
    return knights
  end

  def Pieces.king(team)
    pos = @@positions[team][:king]
    king = King.new(team: team, current_pos: pos)
  end

  def Pieces.queen(team)
    pos = @@positions[team][:queen]
    queen = Queen.new(team: team, current_pos: pos)
  end

end

class Piece

  include Movement

  attr_reader :team, :current_pos

  def initialize(args = {})
    @team = args.fetch(:team, "")
    @current_pos = args.fetch(:current_pos, [0,0]) 
    @icon = args.fetch(:icon, false) || get_icon
    @moved = args.fetch(:moved, false)
  end

  def set_pos(pos)
    @current_pos = pos
  end

  #Get either white_icon or black_icon from subclasses
  def get_icon
    if @team == "white"
      white_icon
    else
      black_icon
    end
  end

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

  def possible_moves
    from(current_pos).vertically(1..7).or.
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

  def possible_moves
    from(current_pos).horizontally(1..7).or.
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

  def possible_moves
    from(current_pos).horizontally(2).and.vertically(1).or.
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

  def possible_moves
    #regular movement
    from(current_pos).horizontally(1).or.vertically(1).or.diagonally(1).spaces
    #in check..
    #castling..
  end

end

class Bishop < Piece

  def white_icon
    "\u2657"
  end

  def black_icon
    "\u265D"
  end

  def possible_moves
    from(current_pos).diagonally(1..7).spaces
  end

end

class Pawn < Piece

  def white_icon
    "\u2659"
  end

  def black_icon
    "\u265F"
  end

  def possible_moves
    #if first move
    unless @moved
      from(current_pos).forward(1..2, self).spaces
    else
      #if not first move
      from(current_pos).forward(1, self).spaces
    end
    #if an opponent's piece is diagonally adjacent
    #get opponent's piece location
    #if it was their last move, allow en passant
  end
end

