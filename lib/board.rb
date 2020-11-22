#require 'chess'

class Board

  attr_reader :arr

  def initialize(args = {})
    @height = args.fetch(:height, 8)
    @width = args.fetch(:width, 8)
    @arr = create_array
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

  public
  def move(piece, pos)
    current_pos = get_coords(piece)
    return nil if current_pos.nil?
    remove_at(current_pos)
    place(piece, pos)
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

  private
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
    @arr = create_array
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


