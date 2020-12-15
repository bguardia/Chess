#require 'chess'

module Gamestate

  REMOVED = nil

  def update 
    prev_state = get_previous_state(1)
    pieces = self.get_pieces
    pieces_hash = {} 

    #Check for pieces which have been removed from game since last state
    prev_state.each_key do |key|
      pieces_hash[key] = REMOVED unless pieces.find { |p| p.object_id == key.to_i }
    end

    #Check for pieces which have changed position since last state
    pieces.each do |p|
      p_arr = [p, p.current_pos]
      p_key = p.object_id.to_s
      if prev_state[p_key] == p_arr
        next
      else
        pieces_hash[p_key] = p_arr
      end
    end

    #Add state to log
    @log << pieces_hash 
  end

  def get_previous_state(n)
    arr = @log[0..(@log.length - (n + 1))]
    arr.reduce({}) do |sum, state|
      sum.merge(state)
    end
  end

  def revert_to_previous_state(n)
    n.times { @log.pop }
    state = get_previous_state(0)
  end

end

class Board
  include Gamestate
  attr_reader :arr

  def initialize(args = {})
    @height = args.fetch(:height, 8)
    @width = args.fetch(:width, 8)
    @arr = args.fetch(:arr, nil) || create_array
    
    if pieces = args.fetch(:pieces, nil)
      pieces.each { |p| p.add_to_board(self) }
      update_gamestate
    end

    @log = []
  end

  def update_gamestate
    update
  end

  def create_array
    Array.new(@height) { Array.new(@width, nil) }
  end

  public
  def place(piece, pos)
    return nil unless cell_exists?(pos)
    x = pos[0]
    y = pos[1]
    @arr[x][y] = piece
  end

  def move(piece, pos)
    current_pos = get_coords(piece)
    return nil if current_pos.nil?
    remove_at(current_pos)
    place(piece, pos)
    update_gamestate
  end

  def get_pieces(args = {})
    pieces = []

    @arr.each do |rank|
      rank.each do |space|  
        if space.kind_of?(Piece)
          match_all = args.keys.all? do |key|
            if key == :type
              clz = Kernel.const_get(args[key])
              space.kind_of?(clz)
            else
              inst_var = "@#{key}".to_sym
              space.instance_variable_get(inst_var) == args[key]
            end
          end
          pieces << space if match_all
        end
      end
    end

    return pieces
  end

  def get_piece_at(pos)
    x = pos[0]
    y = pos[1]

    return @arr[x][y]
  end

  def get_coords(piece)
    @arr.each_index do |x|
      @arr[x].each_index do |y|
        if @arr[x][y] == piece
          return [x, y]
        end
      end
    end

    return nil
  end

  public
  def cell_exists?(pos)
    valid_x = pos[1] >= 0 && pos[1] < @width
    valid_y = pos[0] >= 0 && pos[0] < @height
    if valid_x && valid_y
      return true
    else
      return false
    end
  end

  def remove_at(pos)
    x = pos[0]
    y = pos[1]

    @arr[x][y] = nil
  end

  private
  def ruled_arr
    width_ruler = ("a".."z").to_a.first(@width)
    height_index = @height
    ruled_arr = []
    ruled_arr.push( [nil].concat(width_ruler) )
    @arr.each do |row|
      ruled_arr.push( [height_index].concat(row) )
      height_index -= 1
    end

    return ruled_arr
    end


  public
  def clear
    @arr.each do |row|
      row.each do |cell|
        cell = nil
      end
    end  
  end

  def set_arr (arr)
    @arr = arr
  end

  def copy
    board_copy = self.dup
    board_copy.set_arr( self.arr.map { |row| row.dup } )

    return board_copy
  end

  def rewind(n)
    prev_state = revert_to_previous_state(n)
    clear
    prev_state.each_value do |p_arr|
      unless p_arr.nil?
        place(p_arr[0], p_arr[1])
      end
    end     
    
  end

=begin
  def simulate_move(piece, pos)
    dup_arr = @arr.map do |row|
      row.dup.map do |cell|
        cell.dup
      end
    end

    sim_board = Board.new(arr: dup_arr)

    sim_board.move(piece, pos)
  end
=end

  public
  def to_s
    
    separator = "|"
    board_str = ""
    ruled_arr.each do |row|
      row.each do |cell|
        cell_str = cell.nil? ? " " : cell.to_s
        board_str += cell_str + separator
      end
      board_str += "\n" 
    end
    return board_str
  end

end


