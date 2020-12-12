require 'curses'
require './lib/game.rb'
require './lib/board.rb'
require './lib/piece.rb'

module Keys

  UP ||= Curses::Key::UP
  DOWN ||= Curses::Key::DOWN
  LEFT ||= Curses::Key::LEFT
  RIGHT ||= Curses::Key::RIGHT
  ENTER ||= "\n".ord
  BACKSPACE ||= 127
  ESCAPE ||= 27

end

module KeyMapping

  @stop_receiving_input = false

  #methods mapped to each key should be defined in each class
  def up; end
  def down; end
  def left; end
  def right; end
  def on_enter; end
  def on_backspace; end
  
  def on_escape
    @stop_receiving_input = true
  end

  def default_mapping
    { Keys::UP => -> { up },
      Keys::DOWN => -> { down },
      Keys::LEFT  => -> { left },
      Keys::RIGHT => -> { right },
      Keys::ENTER => -> { on_enter },
      Keys::BACKSPACE => -> { on_backspace },
      Keys::ESCAPE => -> { on_escape } }
  end

  #break_condition should return true when ready to stop receiving input
  def break_condition
    @stop_receiving_input
  end

  def receive_input(win, key_mapping = {})
    key_mapping = default_mapping.merge(key_mapping)
    win.keypad(true)
    before_receive_input

    loop do
      input = win.getch
      if key_mapping.has_key?(input)
        key_mapping[input].call
      end

      break if break_condition
    end 

    win.keypad(false)
    post_receive_input 
    return return_input
  end

  #add in any declarations that should be made before/after the input loop in the following methods
  def before_receive_input; end
  def post_receive_input; end
  def return_input; end
end

module CursesWrapper

  def self.new_window(args)
    h = args.fetch(:height)
    w = args.fetch(:width)
    t = args.fetch(:top)
    l = args.fetch(:left)
    bt = args.fetch(:border_top, nil)
    bs = args.fetch(:border_side, nil)

    win = Curses::Window.new(h, w, t, l)

    if bt && bs
      win.box(bt, bs)
    end
    
    return win
  end

end

module Highlighting
  
  FG ||= { black: 30,
           red: 31,
           green: 32,
           yellow: 33,
           blue: 34,
           magenta: 35,
           cyan: 36,
           white: 37,
           b_black: 90,
           b_red: 91,
           b_green: 92,
           b_yellow: 93,
           b_blue: 94,
           b_magenta: 95,
           b_cyan: 96,
           b_white: 97  }

  BG ||= { black: 40,
           red: 41,
           green: 42,
           yellow: 43,
           blue: 44,
           magenta: 45,
           cyan: 46,
           white: 47, 
           b_black: 100,
           b_red: 101,
           b_green: 102,
           b_yellow: 103,
           b_blue: 104,
           b_magenta: 105,
           b_cyan: 106,
           b_white: 107  }


  def highlight_arr
    @highlight_arr
  end  

  #create a copy of an array to hold highlight data
  #array should contain a length-two array for each place to highlight
  #the first index contains FG data, the second BG data
  def init_highlight_arr(arr)
    @highlight_arr = arr.map do |y|
      if y.kind_of?(Array)
        y.map do |x|
          x.dup
        end
      else
        y.dup
      end
    end
  end

  def self.get_sequence(fg, bg)
    fg = FG.fetch(fg, nil)
    bg = BG.fetch(bg, nil)
    if fg && bg
      "\e[#{fg};#{bg}m"
    else
      "\e[#{fg}#{bg}m"
    end
  end

  def self.esc_sequence
    "\e[m"
  end

  def highlight(str, pos)
    data = highlight_arr[pos[0]][pos[1]]
    fg = data[0]
    bg = data[1]

    Highlighting.get_sequence(fg, bg) + str + Highlighting.esc_sequence
  end

  #for single operations
  def self.highlight(str, args)
    fg = args.fetch(:fg, nil)
    bg = args.fetch(:bg, nil)

    Highlighting.get_sequence(fg, bg) + str + Highlighting.esc_sequence
  end
end

#Maps elements of an array to coordinates on a string
#for easy updating
class Map

  def initialize(args)
    @arr = args.fetch(:arr)
    
    str = args.fetch(:str)
    key = args.fetch(:key)
    @delimiter = args.fetch(:delim, "\n")
    
    @map = create_map(@arr, str, key, @delimiter)
    @reverse_map = @map.invert


    @empty_chr = args.fetch(:empty_chr, " ")
    @str_arr = create_str_arr(str, key)
  
    post_initialize(args)
  end
  
  def post_initialize(args); end #for subclasses

  def create_str_arr(str, key)
    cleaned_str = str.gsub(key, @empty_chr)
    str_arr = str.split(@delimiter).map { |line| line.split("") }
  end

  def create_map(arr, str, key, delim = "\n")
    #take an array and str and create a hash that connects array positions to string positions

    arr_pos = return_array_positions(arr)
    str_pos = return_string_positions(str, key, delim)
    map_hash = {}

    arr_pos.each_index do |i|
      map_hash[arr_pos[i]] = str_pos[i]
    end
      
    return map_hash
  end

  def return_array_positions(arr)
    if arr.flatten == arr
      return (0...arr.length)
    else
      pos_arr = []
      arr.each_index do |y|
        pos_arr.concat(return_array_positions(arr[y]).map { |x| [y, x] })
      end

      return pos_arr
    end
  end

  def return_string_positions(str, key, delim = "\n")
    pos_arr = []
    y = 0
    x = 0
    str.split(delim).each do |line|
      line.split("").each do |chr|
      pos_arr << [y, x]  if chr == key
      x += 1
      end
      y += 1
      x = 0
    end

    return pos_arr
  end

  def arr_to_str_pos(arr_pos)
    @map[arr_pos]
  end

  def str_to_arr_pos(str_pos)
    @reverse_map[str_pos]
  end

  def update_str
    @map.each_pair do |arr_pos, str_pos|
      chr = @arr[arr_pos[0]][arr_pos[1]].to_s
      @str_arr[str_pos[0]][str_pos[1]] = chr.length == 0 ? @empty_chr : chr
    end
  end

  def to_s
    update_str
    str = @str_arr.reduce("") { |t, l| t += l.join("").concat(@delimiter) }
  end

end

class ColorMap < Map
  include Highlighting

  COLOR_CODES ||= { "b" => :black,
                    "B" => :b_black,
                    "r" => :red,
                    "R" => :b_red,
                    "g" => :green,
                    "G" => :b_green,
                    "y" => :yellow,
                    "Y" => :b_yellow,
                    "a"  => :blue,
                    "A" => :b_blue,
                    "m" => :magenta,
                    "M" => :b_magenta,
                    "c" => :cyan,
                    "C" => :b_cyan,
                    "w" => :white,
                    "W" => :b_white,
                    " " => nil }

  def post_initialize(args)
    #bg_maps are strings that map regions of a display area
    #characters from COLOR_CODES are used
    bg_map = args.fetch(:bg_map)
    fg_map = args.fetch(:fg_map)
    color_arr = create_color_arr(fg_map, bg_map)
    init_highlight_arr(color_arr)
  end

  def create_color_arr(fg_map, bg_map)
    fg_arr = color_map_to_arr(fg_map)
    bg_arr = color_map_to_arr(bg_map)

    color_arr = []
    fg_arr.each_index do |y|
      temp_row = []
      fg_arr[y].each_index do |x|
        temp_row << [fg_arr[y][x], bg_arr[y][x]]
      end
      color_arr << temp_row
    end

    return color_arr
  end

  def color_map_to_arr(map)
    arr = map.split("\n").map do |line|
            line.split("").map do |chr|
              COLOR_CODES[chr]
            end
    end  

    return arr
  end

  def colorize_str
    str = ""
    @str_arr.each_index do |y|
      @str_arr[y].each_index do |x|
        str += highlight(@str_arr[y][x], [y, x])
      end
      str += "\n"
    end 

    return str
  end

  def to_s
    update_str
    colorize_str
  end
end

class CursorMap
  include KeyMapping

  attr_reader :win

  def initialize(args)

    padding = args.fetch(:padding, 2)

    @displayed = args.fetch(:displayed)
    @min_x = args.fetch(:min_x, 0) 
    @min_y = args.fetch(:min_y, 0)
    @max_x = args.fetch(:max_x)
    @max_y = args.fetch(:max_y)
    @x_incr = args.fetch(:x_incr, 1)
    @y_incr = args.fetch(:y_incr, 1)
    @cursor_x = 0
    @cursor_y = 0
  
    @stored_input = nil
    @input_to_return = nil


    border_win_hash = args.merge({ height: args[:height] + padding * 2,
                                   width: args[:width] + padding * 2,
                                   top: args[:top] - padding,
                                   left: args[:left] - padding })

    @win = CursesWrapper.new_window(border_win_hash)
    @subwin = @win.subwin(args[:height], args[:width], args[:top], args[:left])
    @win.refresh
  end
 
  def window
    @subwin
  end

  def reset_pos
    @cursor_x = 0
    @cursor_y = 0
    update_cursor_pos
  end

  def up
    if @cursor_y - @y_incr >= @min_y
      @cursor_y -= @y_incr
      update_cursor_pos
    end
  end

  def down
    if @cursor_y + @y_incr <= @max_y
      @cursor_y += @y_incr
      update_cursor_pos
    end
  end

  def left
    if @cursor_x - @x_incr >= @min_x
      @cursor_x -= @x_incr
      update_cursor_pos
    end
  end

  def right
    if @cursor_x + @x_incr <= @max_x
      @cursor_x += @x_incr
      update_cursor_pos
    end
  end

  def on_enter
    current_pos = translate_pos
    #check if that piece can be selected?
    if @stored_input
      @input_to_return = [@stored_input.dup, current_pos]
      @stored_input = nil
    else
      @stored_input = current_pos
      #get highlights from board and update map display with highlights
    end 
  end

  def on_backspace
    @stored_input = nil
    #remove any highlights from board
  end

  def pos_within_bounds?(x,y)
    valid_x = x >= @min_x && x <= @max_x
    valid_y = y >= @min_x && y <= @max_y

    return valid_x && valid_y
  end

  def setpos(x, y)
    window.setpos(y, x)
  end

  def set_cursor_pos(x, y)
    @cursor_x = x
    @cursor_y = y
    update_cursor_pos
  end

  def update_cursor_pos
    setpos(@cursor_x, @cursor_y)
  end

  def translate_pos
    x = (@cursor_x - @min_x) / @x_incr
    y = (@cursor_y - @min_y) / @y_incr

    return [y,x]
  end

  def before_receive_input
    @input_to_return = nil
    @stored_input = nil
    Curses.noecho
    Curses.crmode
  end

  def post_receive_input
    
  end

  def return_input
    @input_to_return
  end

  def break_condition
    @input_to_return
  end

  def update_display
    window.addstr(@displayed.to_s)
    window.refresh
  end
end

def test_board
  begin
  Curses.init_screen
  board = Board.new
  height = 9
  width = 21 
  padding = 2
  top = (Curses.lines - (height)) / 2
  left = (Curses.cols - (width)) / 2
  cursmap = CursorMap.new(height: height,
                      width: width,
                      top: top, 
                      left: left,
                      border_top: "-",
                      border_side: "|",
                      padding: 5,
                      min_x: 2,
                      min_y: 1,
                      max_x: 2 + (7*2),
                      max_y: height,
                      x_incr: 2,
                      displayed: board)

  cursmap.update_display
  returned_input = cursmap.receive_input(cursmap.window)
  ensure
  Curses.close_screen
  end

  puts "input returned from allow_cursor_movement was: #{returned_input}"
end

def map_board(board)

  board_str = board.to_s #what if board had a special to_map method that returned a string with a predefined space char?
                        
  r = 0
  c = 0
  mapped_spaces = []
  current_row = []
  board_str.each_line do |row|
    row.split("").each do |col|
      if col == " "
        current_row << [r, c]
      end
      c += 1
    end
    mapped_spaces << current_row.dup
    current_row = []
    c = 0
    r += 1
  end

  p mapped_spaces

end

  test_str = "  a b c d e f g h   \n" +
             "1|X X X X X X X X | \n" +
             "2|X X X X X X X X | \n" +
             "3|X X X X X X X X | \n" +
             "4|X X X X X X X X | \n" +
             "5|X X X X X X X X | \n" +
             "6|X X X X X X X X | \n" +
             "7|X X X X X X X X | \n" +
             "8|X X X X X X X X | \n" + 
             " ------------------ \n"
   
  bg_map =     "BBBBBBBBBBBBBBBBBBBB\n" +
             (("BBmmwwmmwwmmwwmmwwBB\n" +
               "BBwwmmwwmmwwmmwwmmBB\n") * 4) +
               "BBBBBBBBBBBBBBBBBBBB\n"

  fg_map =     "  wwmmwwmmwwmmwwmm  \n" +
             (("ww                  \n" +
               "mm                  \n") * 4 ) +
               "                    "

def test_map

  test_str = "   a  b  c  d  e  f  g  h   \n" +
             "1| X  X  X  X  X  X  X  X | \n" +
             "2| X  X  X  X  X  X  X  X | \n" +
             "3| X  X  X  X  X  X  X  X | \n" +
             "4| X  X  X  X  X  X  X  X | \n" +
             "5| X  X  X  X  X  X  X  X | \n" +
             "6| X  X  X  X  X  X  X  X | \n" +
             "7| X  X  X  X  X  X  X  X | \n" +
             "8| X  X  X  X  X  X  X  X | \n" + 
             " -------------------------- \n"
   
  bg_map =     "bbbbbbbbbbbbbbbbbbbbbbbbbbbb\n" +
             (("bbMMMWWWMMMWWWMMMWWWMMMWWWbb\n" +
               "bbWWWMMMWWWMMMWWWMMMWWWMMMbb\n") * 4) +
               "bbbbbbbbbbbbbbbbbbbbbbbbbbbb\n"

  fg_map =     "  WWWMMMWWWMMMWWWMMMWWWMMM  \n" +
             (("WW                          \n" +
               "MM                          \n") * 4 ) +
               "                            "
  pieces = Pieces.new_set("white").concat(Pieces.new_set("black"))
  board = Board.new
  pieces.each { |p| p.add_to_board(board) }

  arr = board.arr 
 
  test_color_map = ColorMap.new(arr: arr, str: test_str, key: "X", bg_map: bg_map, fg_map: fg_map)

  bg_map = bg_map.gsub("M", "A")
  fg_map = fg_map.gsub("M", "A")
  color_map_v2 = ColorMap.new(arr: arr, str: test_str, key: "X", bg_map: bg_map, fg_map: fg_map)

  bg_map = bg_map.gsub("A", "R")
  fg_map = fg_map.gsub("A", "R")
  color_map_v3 = ColorMap.new(arr: arr, str: test_str, key: "X", bg_map: bg_map, fg_map: fg_map)
  
  bg_map = bg_map.gsub("R", "C")
  fg_map = fg_map.gsub("R", "C")
  color_map_v4 = ColorMap.new(arr: arr, str: test_str, key: "X", bg_map: bg_map, fg_map: fg_map)

  bg_map = bg_map.gsub("C", "Y")
  fg_map = fg_map.gsub("C", "Y")
  color_map_v5 = ColorMap.new(arr: arr, str: test_str, key: "X", bg_map: bg_map, fg_map: fg_map)
  
  bg_map = bg_map.gsub("Y", "G")
  fg_map = fg_map.gsub("Y", "G")
  color_map_v6 = ColorMap.new(arr: arr, str: test_str, key: "X", bg_map: bg_map, fg_map: fg_map)



  puts test_color_map
  gets
  puts color_map_v2
  gets
  puts color_map_v3
  gets
  puts color_map_v4
  gets
  puts color_map_v5
  gets
  puts color_map_v6

end

if __FILE__ == $0

  test_map

end
