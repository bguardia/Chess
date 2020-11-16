#require 'chess'


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

    private
    def modify_moves(moves_arr)
      modified_moves = []
      @modifiable_moves.each do |one|
        puts "one: #{one}"
        moves_arr.each do |two|
          modified_moves << [ one[0] + two[0], one[1] + two[1] ]
          puts ">two: #{two}, new_move: #{modified_moves.last}" 
        end
      end
      puts "\nmodified_moves: #{modified_moves}"
      @modifiable_moves = modified_moves.dup
      puts "modifiable_moves: #{@modifiable_moves}"
    end

    private
    def create_moves_array(args)
      move_arr = []
      x = args.fetch(:x, [0])
      y = args.fetch(:y, [0])
      y_i = 0
      x_i = 0

      puts "x: #{x}, y: #{y}"
      loop do
        move_arr << [y[y_i], x[x_i]]
        puts "#{move_arr.last}"
        x_i += 1 if more_x = x_i < x.length - 1
        y_i += 1 if more_y = y_i < y.length - 1
        break unless more_x || more_y
      end

      return move_arr
    end

    #Movement methods are chained to create arrays of possible positions
    #Methods can accept an integer or a range/array of integers
    #  A single integer creates a single position
    #  A range or array will create a position for each element
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
      n = to_arr(n).last
      up(1).and.left(1).up_to(n).or.
        up(1).and.right(1).up_to(n).or.
        down(1).and.left(1).up_to(n).or.
        down(1).and.right(1).up_to(n)
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

    def forward(n, piece)
      if piece.team == "black"
        down(n)
      elsif piece.team == "white"
        up(n)
      end
      return self
    end
    
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

    def and
      return self
    end

    def or
      add_moves
      reset_modifiable_moves
      return self
    end

    private
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

    private
    def reset_moves
      @moves = []
    end

    public
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
                               :queen => [0,4],
                               :king => [0,5]       },
                  "white" =>  { :pawns => Array.new(8,6).zip((0..7).to_a),
                                :rooks => Array.new(2,7).zip([0,7]),
                                :knights => Array.new(2,7).zip([1,6]),
                                :bishops => Array.new(2,7).zip([2,5]),
                                :queen => [7,4],
                                :king => [7,5]       }
  }

  def self.new_set(team)
    set = []
    set.concat(pawns(team))
    set.concat(rooks(team))
    set.concat(bishops(team))
    set.concat(knights(team))
    set << king(team)
    set << queen(team)
    
    return set
  end

  def pawns(team)
    pawns = []
    @@positions[team][:pawns].each do |pos|
      pawns << Pawn.new(team: team, current_pos: pos)
    end
    return pawns
  end

  def rooks(team)
    rooks = []
    @@positions[team][:rooks].each do |pos|
      rooks << Rook.new(team: team, current_pos: pos)
    end
    return rooks
  end

  def bishops(team)
    bishops = []
    @@positions[team][:bishops].each do |pos|
      bishops << Bishop.new(team: team, current_pos: pos)
    end
    return bishops
  end
 
  def knights(team)
    knights = []
    @@positions[team][:knights].each do |pos|
      knights << Knight.new(team: team, current_pos: pos)
    end
    return knights
  end

  def king(team)
    pos = @@positions[team][:king]
    king = King.new(team: team, current_pos: pos)
  end

  def queen(team)
    pos = @@positions[team][:queen]
    queen = Queen.new(team: team, current_pos: pos)
  end

end

class Piece

  include Movement

  attr_reader :team, :current_pos

  def initialize(args = {})
    @team = args.fetch(:team, "")
    @current_pos = []
  end

  def set_pos(pos)
    @current_pos = pos
  end

  #Pieces require a possible_moves class
  #An array of possible moves can be created using the Movement module (see above)
end

class Queen < Piece

  def possible_moves
    from(current_pos).vertically(1..7).or.
      horizontally(1..7).or.
      diagonally(1..7).spaces
  end

end

class Rook < Piece

  def possible_moves
    from(current_pos).horizontally(1..7).or.
      vertically(1..7).spaces
  end

end

class Knight < Piece

  def possible_moves
    from(current_pos).horizontally(2).and.vertically(1).or.
      vertically(2).and.horizontally(1).spaces
  end

end

class King < Piece

  def possible_moves
    #regular movement
    from(current_pos).horizontally(1).or.vertically(1).or.diagonally(1).spaces
    #in check..
    #castling..
  end

end

class Bishop < Piece

  def possible_moves
    from(current_pos).diagonally(1..7).spaces
  end

end

class Pawn < Piece

  def possible_moves
    #if first move
    from(current_pos).forward(1..2)
    #if not first move
    from(current_pos).forward(1)
    #if an opponent's piece is diagonally adjacent
    #get opponent's piece location
    #if it was their last move, allow en passant
  end
end

