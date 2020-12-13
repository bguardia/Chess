require 'pry'
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
  TAB ||= "\t".ord

end

module KeyMapping

  @stop_receiving_input = false

  #methods mapped to each key should be defined in each class
  def to_up; end
  def to_down; end
  def to_left; end
  def to_right; end
  def on_enter; end
  def on_backspace; end
  
  def on_escape
    @stop_receiving_input = true
  end

  def default_mapping
    { Keys::UP => -> { to_up },
      Keys::DOWN => -> { to_down },
      Keys::LEFT  => -> { to_left },
      Keys::RIGHT => -> { to_right },
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


class Screen
  
  def initialize(args)
    @regions = []
    @win = CursesWrapper.new_window(args)
  end

  def add_region(rgn)
    h = rgn.height
    w = rgn.width
    t = rgn.top
    l = rgn.left
    rgn.set_win(@win.subwin(h,w,t,l))
    rgn.update
    @regions << rgn
  end

  def update
    @regions.each { |rgn| rgn.update }
    @win.refresh
  end

  def gets
    @win.getch
  end
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
   
=begin

   COLOR MAPPING LOGIC AND VARIABLES

=end

  #Use the following characters when creating a color map
  #Capital letters refer to the brighter version of the same color 
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

  #takes a font color map and bg color map
  #and turns them into a color array
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

  #Turns color map string into an array of color symbols
  def color_map_to_arr(map)
    arr = map.split("\n").map do |line|
            line.split("").map do |chr|
              COLOR_CODES[chr]
            end
    end  

    return arr
  end

=begin

  CURSES COLOR LOGIC

=end
  #Constants for Curses colors. 
  CURSES_COLORS ||= { black: Curses::COLOR_BLACK,
                      red: Curses::COLOR_RED,
                      green: Curses::COLOR_GREEN,
                      yellow: Curses::COLOR_YELLOW,
                      blue: Curses::COLOR_BLUE,
                      magenta: Curses::COLOR_MAGENTA,
                      cyan: Curses::COLOR_CYAN,
                      white: Curses::COLOR_WHITE }
 
  #the c_pairs hash matches pairs of fg and bg colors to
  #a color_pair number, a previously initialized pair used in
  #Curses. 
  def c_color_pairs
    @@c_pairs ||= { [nil, nil] => 0 }
  end

  def num_c_pairs
    c_color_pairs.size
  end
 
  #Removes the bright prefix from color symbols and matches them to CURSES_COLORS
  def sym_to_color_const(sym)
    str = sym.to_s[/(b_)?([[:alpha:]]*)/, 2] #remove b_
    return nil if str.nil?
    CURSES_COLORS[str.to_sym]
  end

  #get CURSES_COLORS values of each color and create a new color_pair,
  #adding to the c_color_pairs hash and returning color_pair
  def new_c_pair(c_arr)
    fg = sym_to_color_const(c_arr[0])
    bg = sym_to_color_const(c_arr[1])
    
    return 0 if !fg && !bg

    fg = CURSES_COLORS[:black] unless fg
    bg = CURSES_COLORS[:black] unless bg

    pair_num = num_c_pairs
    Curses.init_pair(pair_num, fg, bg)
    c_color_pairs[c_arr] = pair_num

    return pair_num
  end

  #Highlights a single character or row of characters with curses
  def c_highlight(win, chr, pos)
    data = highlight_arr[pos[0]][pos[1]]
    color_pair = c_color_pairs.fetch(data, nil) || new_c_pair(data)
    
    win.attron(Curses.color_pair(color_pair))
    win.setpos(pos[0], pos[1])
    win.addstr(chr)
    win.attroff(Curses.color_pair(color_pair))
  end
  
  #Pass a str_arr and curses window to input the string character by character
  #into the curses window
  def curses_colorize_str(win, str_arr)
    str_arr.each_index do |y|
      str_arr[y].each_index do |x|
        c_highlight(win, str_arr[y][x], [y, x])
      end
    end
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

  def highlight_arr
    @highlight_arr
  end  

=begin

  ASCII CONTROL CODE LOGIC

=end
#Constant hashes for ASCII control code colors 
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

  #for single operations
  def self.highlight(str, args)
    fg = args.fetch(:fg, nil)
    bg = args.fetch(:bg, nil)

    Highlighting.get_sequence(fg, bg) + str + Highlighting.esc_sequence
  end


  def highlight(str, pos)
    data = highlight_arr[pos[0]][pos[1]]
    fg = data[0]
    bg = data[1]

    Highlighting.get_sequence(fg, bg) + str + Highlighting.esc_sequence
  end
  
  #Pass a string array to colorize it with ASCII control codes
  def colorize_str(str_arr)
    colorized_str = ""
    str_arr.each_index do |y|
      str_arr[y].each_index do |x|
        colorized_str += highlight(str_arr[y][x], [y, x])
      end
      colorized_str += "\n"
    end 

    return colorized_str
  end

end

#Maps elements of an array to coordinates on a string
#for easy updating
class Map
  include Highlighting
  
  def initialize(args)
    #Set up array and array map
    @arr = args.fetch(:arr)
    str = args.fetch(:str)
    key = args.fetch(:key)
    @delimiter = args.fetch(:delim, "\n")
    @map = create_map(@arr, str, key, @delimiter)
    @reverse_map = @map.invert
    #Remove keys from string and create string array
    @empty_chr = args.fetch(:empty_chr, " ")
    @str_arr = create_str_arr(str, key)
    #Calculate total size of map
    @height = @str_arr.length
    @width = @str_arr.first.length

    #Optional arguments for desired coordinates
    #and window object.
    #Window may be set later, allowing it to become a subwindow of a
    #larger window/screen.
    @top = args.fetch(:top, 0)
    @left = args.fetch(:left, 0) 
    
    if args.fetch(:window, false)
      args = args.merge({ height: @height, width: @width })
      @win = CursesWrapper.new_window(args)
    end

    #Optional settings for a color map
    #See highlighting module for more info
    if args.has_key?(:fg_map)
      set_color_map(args)
    end

    post_initialize(args)
  end
  
  public
  def set_win(win)
    @win = win
  end

  def height
    @height
  end

  def width
    @width
  end

  def top
    @top
  end

  def left
    @left
  end

  def set_color_map(args)
    bg_map = args.fetch(:bg_map)
    fg_map = args.fetch(:fg_map)
    color_arr = create_color_arr(fg_map, bg_map)
    init_highlight_arr(color_arr)
  end

  private  
  def post_initialize(args); end #for subclasses

  def create_str_arr(str, key)
    cleaned_str = str.gsub(key, @empty_chr)
    str_arr = str.split(@delimiter).map { |line| line.split("") }
  end

  #take an array and str and create a hash that connects array positions to string positions
  def create_map(arr, str, key, delim = "\n")

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
      return (0...arr.length).to_a
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

  #Places up-to-date, stringified elements of array into str_array
  def update_str
    @map.each_pair do |arr_pos, str_pos|
      chr = @arr[arr_pos[0]][arr_pos[1]].to_s
      @str_arr[str_pos[0]][str_pos[1]] = chr.length == 0 ? @empty_chr : chr
    end
  end

  def update_logic 
    return nil unless @win
    if highlight_arr
      update_str
      curses_colorize_str(@win, @str_arr)  
    else
      str = to_s
      @win.setpos(0,0)
      @win.addstr(str)
    end
  end

  public
  def update
    update_logic
    return nil unless @win
    @win.refresh
  end

  def to_s
    update_str
    if highlight_arr
      return colorize_str(@str_arr)
    else
      return @str_arr.reduce("") { |t, l| t += l.join("").concat(@delimiter) }
    end
  end
end

class ColorMap < Map
  include Highlighting

  def post_initialize(args)
    #bg_maps are strings that map regions of a display area
    #characters from COLOR_CODES are used
    bg_map = args.fetch(:bg_map)
    fg_map = args.fetch(:fg_map)
    color_arr = create_color_arr(fg_map, bg_map)
    init_highlight_arr(color_arr)
  end

  def to_s
    update_str
    curses_colorize_str
  end
end

class CursorMap < Map
  include KeyMapping

  def post_initialize(args)
    @pos_x = 0
    @pos_y = 0
    @stored_input = nil
  end
 
  def reset_pos
    @cursor_x = 0
    @cursor_y = 0
    update_cursor_pos
  end

  def to_up
    if pos_exist?(@pos_y - 1, @pos_x)
      @pos_y -= 1
      update_cursor_pos    
    end
  end

  def to_down
    if pos_exist?(@pos_y + 1, @pos_x)
      @pos_y += 1
      update_cursor_pos
    end
  end

  def to_left
    if pos_exist?(@pos_y, @pos_x - 1)
      @pos_x -= 1
      update_cursor_pos
    end
  end

  def to_right
    if pos_exist?(@pos_y, @pos_x + 1)
      @pos_x += 1
      update_cursor_pos
    end
  end

  def on_enter
    current_pos = [@pos_y, @pos_x] 
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

  def pos_exist?(x, y)
    @map.fetch([y, x], false)
  end

  def setpos(x, y)
    @win.setpos(y, x)
  end

  def update_cursor_pos
    cursor_pos = @map[[@pos_y, @pos_x]]
    x = cursor_pos[1]
    y = cursor_pos[0]
    setpos(x, y)
  end

  def get_input
    receive_input(@win)
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

def test_screen
begin
    
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

  Curses.init_screen
  Curses.start_color
  screen = Screen.new(height: 20, width: 40, top: 10, left: 10)


  test_color_map = CursorMap.new(top: 12, left: 12, arr: arr, str: test_str, key: "X", bg_map: bg_map, fg_map: fg_map)
  
  screen.add_region(test_color_map)

  screen.gets

  board.move(pieces.first, [3,3])
  screen.update
  test_color_map.get_input
ensure
  Curses.close_screen
end
end

def test_cursor_map
 
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
 

  cursor_map = CursorMap.new(top: 12, left: 12, arr: arr, str: test_str, key: "X", bg_map: bg_map, fg_map: fg_map)

  puts "cursor_map's callable methods are:\n#{cursor_map.methods}"
  puts "cursor_map's instance variables are:\n#{cursor_map.instance_variables}"
  puts "cursor_map.to_s returns:\n#{cursor_map.to_s}"
end

if __FILE__ == $0

  test_screen

end
