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


