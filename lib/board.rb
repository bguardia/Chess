#require 'chess'

$board_debug = ""

module Gamestate

  REMOVED = nil

  def update 
    prev_state = get_previous_state(0)
    pieces = self.get_pieces
    pieces_hash = {} 

    #Check for pieces which have been removed from game since last state
    prev_state.each_key do |key|
      pieces_hash[key] = REMOVED unless pieces.find { |p| p.id == key.to_i }
    end

    #Check for pieces which have changed position since last state
    pieces.each do |p|
      p_arr = [p, get_coords(p)]
      p_key = p.id.to_s
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

  def return_last_moved
    $board_debug += "called return_last_moved.\n"
    $board_debug += "@log.length = #{@log.length}\n"
    log_str = ""
    @log.last.each_pair do |key, val|
      name = val.nil? ? "empty" : val[0].class
      pos = val.nil? ? "none" : val[1]
      log_str += "#{key} => #{name}, #{pos}\n"
    end
    $board_debug += "@log.last: #{log_str}\n"
    @log.last.each_value do |val|
      if val
        return val[0]
      end
    end
  end
end

class Board
  include Gamestate
  attr_reader :arr

  def initialize(args = {})
    @height = args.fetch(:height, 8)
    @width = args.fetch(:width, 8)
    @arr = args.fetch(:arr, nil) || create_array
    
    
    @log = []

    if pieces = args.fetch(:pieces, nil)
      pieces.each { |p| p.add_to_board(self) }
      update_gamestate
    end

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
    $board_debug += "called board.move(#{piece.class}, #{pos})\n"

    current_pos = get_coords(piece)
    $board_debug += "current_pos: #{current_pos}\n"
    return nil if current_pos.nil?
    $board_debug += "current_pos is not nil\n"
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
    @arr.map! do |row|
      row = Array.new(@width, nil)  
    end
  end

  def set_arr (arr)
    @arr = arr
  end
 
  def set_log(log)
    @log = log
  end

  def copy
    board_copy = self.dup
    arr = @arr.map do |row|
      row.dup.map do |cell|
              cell.dup
      end
    end

    board_copy.set_arr(arr)
    board_copy.set_log(@log.map { |h| h.dup })
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

  def get_previous_pos(piece)
    $board_debug += "called get_previous_pos\n"
    return nil if piece.nil?
    prev_state = get_previous_state(1)
    val = prev_state.fetch(piece.id.to_s, nil)
    $board_debug += "val fetched from prev_state: #{val}\n"
    if val
      return val[1]
    else
      return nil
    end 
  end

  def simulate_move(piece, pos)
    dup_arr = @arr.map do |row|
      row.dup.map do |cell|
        cell.dup
      end
    end
    sim_board = Board.new(arr: dup_arr)
    sim_board.move(piece, pos)
    return sim_board
  end

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


