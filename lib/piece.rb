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
      puts "called or"
      add_moves
      puts "modifiable_moves added to moves"
      puts "moves: #{@moves}"
      reset_modifiable_moves
      puts "reset modifiable_moves"
      puts "modifiable_moves: #{@modifiable_moves}"
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

 def all_horizontal_spaces(current_pos)
    width = 8
    horizontal_moves_arr = []
    x = 0
    width.times do
      horizontal_moves_arr << [current_pos[0], x] unless x == current_pos[1]
      x += 1
    end
    return horizontal_moves_arr
  end

  def all_vertical_spaces(current_pos)
    height = 8
    vertical_moves_arr = []
    y = 0
    height.times do
      vertical_moves_arr << [y, current_pos[1]] unless y == current_pos[0]
      y += 1 
    end
    return vertical_moves_arr
  end

  def all_diagonal_spaces(current_pos)
    width, height = 8, 8
    diagonal_moves_arr = []
    x1, y1 = current_pos[1], current_pos[0]
    x2, y2 = 1, 1
    checks = Array.new(4, true)

    while checks.any?(true) 
      up_right = [y1 - y2, x1 + x2]
      up_left = [y1 - y2, x1 - x2]
      down_right = [y1 + y2, x1 + x2]
      down_left = [y1 + y2, x1 - x2]

      diagonal_moves_arr << up_right if checks[0] = valid_pos?(up_right)
      diagonal_moves_arr << up_left  if checks[1] = valid_pos?(up_left)
      diagonal_moves_arr << down_right if checks[2] = valid_pos?(down_right)
      diagonal_moves_arr << down_left if checks[3] = valid_pos?(down_left)
      
      x2 += 1
      y2 += 1
    end

    return diagonal_moves_arr
  end

  def valid_pos?(pos)
    width = 8
    height = 8
    valid_x = pos[1] >= 0 && pos[1] < width
    valid_y = pos[0] >= 0 && pos[0] < height
    if valid_x && valid_y
      return true
    else
      return false
    end
  end

  def pawn_moves(current_pos)
    #Can move forward two spaces if first turn
    #Otherwise, only one space in direction of the opponent
  end

  def king_moves(current_pos)
    #one space in every direction
    king_moves = []
    #arr = [[0, 1], [1, 0], [0, -1], [-1, 0], [-1, -1], [1, 1], [1, -1], [-1, 1]]
    arr = [0,1,1,-1,-1].permutation(2).to_a.uniq
    
    arr.each do |pos|
      move = [ pos[0] + current_pos[0], pos[1] + current_pos[1] ]
      king_moves << move if move != current_pos
    end

    #if king and rook have not moved
    #and there is nothing between them
    #king can do castling
    #
    #may need to add to possible_moves from another function
    return king_moves
  end

  def rook_moves(current_pos)
    all_horizontal_spaces(current_pos).concat(all_vertical_spaces(current_pos))
  end

  def queen_moves(current_pos)
    rook_moves(current_pos).concat(all_diagonal_spaces(current_pos))
  end

  def bishop_moves(current_pos)
    all_diagonal_spaces(current_pos)
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
