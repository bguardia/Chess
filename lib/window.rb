require 'pry'
require 'curses'
require './lib/chess.rb'
require './lib/game.rb'
require './lib/board.rb'
require './lib/piece.rb'

$window_debug = ""

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

  def return_c_pair(fg, bg)
    color_pair = c_color_pairs.fetch([fg, bg], nil) || new_c_pair([fg, bg])
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

  def curses_fill(win, fg, bg, chr = " ")
    color_pair = c_color_pairs.fetch([fg, bg], nil) || new_c_pair([fg, bg])
    col = Curses.color_pair(color_pair)
    $window_debug += "called curses_fill on #{self.class}\n"
    $window_debug += "fg: #{fg}, bg: #{bg}, color_pair: #{color_pair}\n"
    $window_debug += "col: #{col}\n"
    win.attron(col)
    win.bkgd(chr.ord)
    win.attroff(col)
    win.refresh
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

module InteractiveWindow
  #A module that allows an input source to interactive with input handler
  #The default methods are an example of using $stdin
  def interactive
    true
  end

  #Stores any special keys used by a paticular context
  #(Will be over-ridden by arguments passed to input_handler)
  def key_map
    {}
  end

  #Called during InputHandler's get_input loop
  def before_get_input; end
  def post_get_input; end
  def get_input
    @input_to_return = gets.chomp #Wrap gets or win.getch so other objects don't need to know the difference
  end

  def handle_unmapped_input(input)
  end

  #Method to handle returned input if the input is not a special character
  def return_input(input); end

  def break_condition
    true #Because gets.chomp returns input as soon as entered is pressed, loop should automatically break
  end

  #Add new context based on key press
  def update_key_map; end

  #A way for window/io to return its input
  def return_input
    @input_to_return
  end
end

class Window
  include Highlighting
  attr_reader :win
  
  def initialize(args)   
    @padding = args.fetch(:padding, 0)
    @padding_left = args.fetch(:padding_left, nil) || @padding
    @padding_right = args.fetch(:padding_right, nil) || @padding
    @padding_top = args.fetch(:padding_top, nil) || @padding
    @padding_bottom = args.fetch(:padding_bottom, nil) || @padding
    
    @content = args.fetch(:content, nil)
    
    @height = args.fetch(:height, nil) || determine_height_of(@content) + @padding_top + @padding_bottom
    @width = args.fetch(:width, nil) || determine_width_of(@content) + @padding_left + @padding_right
    if args.fetch(:centered, false)
      @top = (Curses.lines - @height) / 2
      @left = (Curses.cols - @width) / 2
    else
      @top = args.fetch(:top, 0)
      @left = args.fetch(:left, 0)
    end

    @fg = args.fetch(:fg, nil) || :white
    @bg = args.fetch(:bg, nil) || :black
    @bkgd = args.fetch(:bkgd, nil) || " "

    @border_top = args.fetch(:border_top, nil)
    @border_side = args.fetch(:border_side, nil)

    $window_debug += "Initializing #{self.class}:\n@height: #{@height}\n" +
                     "@width: #{@width}\n@top: #{@top}\n@left: #{@left}\n" +
                     "@padding: #{@padding}\n@padding_left: #{@padding_left}\n" +
                     "@padding_right: #{@padding_right}\n@padding_top: #{@padding_top}\n" +
                     "@padding_bottom: #{@padding_bottom}\n"

    @border_win = nil #encapsulating window with border + padding
    @win = create_win #window to handle output

    $window_debug += "Initialized window.\n@border_win: #{@border_win}\n" +
                     "@win: #{@win}\n"

    post_initialize(args)
  end

  private
  def post_initialize(args); end

  private
  def determine_height_of(content = @content)
    return 1 if content.nil?

    if content.kind_of?(Array)
      if content.flatten == @content
        return 1
      else
        return content.length
      end
    else
      return content.split("\n").length
    end
  end

  def fill_win(win, fg, bg, chr = " ")
    curses_fill(win, fg, bg, chr)
  end

  private
  def determine_width_of(content = @content)
    return 1 if content.nil?

    if content.kind_of?(Array)
      if content.flatten == @content
        return content.length
      else
        return content.first.length
      end
    else
      arr = content.split("\n")
      max_width = arr.reduce(0) do |max, s|
        if s.length > max
          s.length
        else
          max
        end
      end

      return max_width 
    end
  end

  public
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

  def border_top
    @border_top
  end

  def border_side
    @border_side
  end

  def set_win(win)
    @win = win
  end

  def set_bg(fg, bg, chr = " ")
    @fg = fg
    @bg = bg
    @bkgd = chr 
  end

  def addstr(str)
    if @content.nil?
      @content = ""
    end
    @content += str
    @win.setpos(0,0)
    @win.addstr(@content)
  end

  def get_input
    @win.getch  
  end

  def close
    @win.close
  end

  def create_win
    @border_win = Curses::Window.new(@height, @width, @top, @left)
    
    if border_top && border_side
      @border_win.box(border_side, border_top)
    end
    @border_win.refresh

    h = @height - @padding_top - @padding_bottom
    w = @width - @padding_left - @padding_right
    t = @top + @padding_top
    l = @left + @padding_left
    win = @border_win.subwin(h, w, t, l)
    win.refresh
    return win
  end

  #Update methods for redrawing and refreshing windows
  #update calls border_win_update and win_update
  #to change how the window is updated, overwrite the win_update method
  def border_win_update
    #fill_win(@border_win, @fg, @bg, @bkgd)
    col = Curses.color_pair(return_c_pair(@fg, @bg))
    y = 0
    @height.times do
      @border_win.setpos(y, 0)
      @border_win.attron(col) do
        @border_win.addstr( @bkgd * @width )
      end
      y += 1
    end
    @border_win.refresh
  end

  def win_update
    if @content.kind_of?(String)
      to_print = @content.split("\n")
    else
      to_print = @content
    end

    y = 0
    to_print.each do |line|
      @win.setpos(y,0)
      @win.addstr(line)
      y += 1
    end
    
    @win.refresh
  end

  def update
    border_win_update 
    win_update
  end
end

#A screen holds information about and manages all windows. 
class Screen < Window
  
  def post_initialize(args)
    @regions = []
    post_post_initialize(args)
  end

  def post_post_initialize(args); end

  def add_region(rgn)
    @regions << rgn
  end

  def win_update
    @win.refresh
    @regions.each { |rgn| rgn.update }
  end

  def get_input
    #@win.getch
  end

end

class InteractiveScreen < Screen
  include InteractiveWindow

  def post_post_initialize(args)
    @active_region = nil
    @break = false
  end

  def interactive_rgns
    @regions.filter { |r| r.respond_to?(:interactive) }
  end

  def change_active_rgn
    interactive = interactive_rgns
    l = interactive.length
    i = interactive.index(@active_region)
    
    #If active region has not been previously set,
    #set first interactive window as active. Otherwise choose next 
    #window in array (wraps around).
    if l == 0
      @active_region = nil 
    elsif i.nil?
      @active_region = interactive.first
      @active_region.before_get_input
    else
      next_i = (i + 1) % l
      @active_region.post_get_input
      @active_region = interactive[next_i]
      @active_region.before_get_input
    end

    return @active_region
  end

  def update_input_environment

  end

  def active_region
    @active_region ||= change_active_rgn
  end

  def before_get_input
    #update
    active_region.before_get_input
  end

  def post_get_input
    active_region.post_get_input
  end

  def get_input
    active_region.get_input
  end

  def break_condition
    active_region.break_condition
  end

  def key_map
    map = { Keys::TAB =>-> { change_active_rgn },
            Keys::ESCAPE => -> { @break = true }}
    if active_region  
      map.merge(active_region.key_map)
    end 
  end

  def update_key_map
    key_map
  end

  def handle_unmapped_input(input) 
    active_region.handle_unmapped_input(input)
  end

  def return_input
    active_region.return_input
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

#Maps elements of an array to coordinates on a string
#for easy updating
class Map < Window
  include Highlighting
  
  def post_initialize(args)
    #Set up array and array map
    @arr = args.fetch(:arr)
    str = args.fetch(:content)
    key = args.fetch(:key)
    @delimiter = args.fetch(:delim, "\n")
    @map = create_map(@arr, str, key, @delimiter)
    @reverse_map = @map.invert

    #Remove keys from string and create string array
    @empty_chr = args.fetch(:empty_chr, " ")
    @str_arr = @content = create_str_arr(str, key)

    #Optional settings for a color map
    #See highlighting module for more info
    if args.has_key?(:fg_map)
      set_color_map(args)
    end

    $window_debug += "#{self.class}.new) returned from super(args)"
    post_post_initialize(args)
  end
 
  private  
  def post_post_initialize(args); end #for subclasses
 
  def set_color_map(args)
    bg_map = args.fetch(:bg_map)
    fg_map = args.fetch(:fg_map)
    color_arr = create_color_arr(fg_map, bg_map)
    init_highlight_arr(color_arr)
  end

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
    $window_debug += "#{self.class}.update_logic) @win exists\n"
    if highlight_arr
      $window_debug += "highlight_arr exists\n"
      update_str
      curses_colorize_str(@win, @str_arr)  
    else
      $window_debug += "highlight_arr doesn't exist\n"
      str = to_s
      @win.setpos(0,0)
      @win.addstr(str)
    end
  end

  public
  def win_update
    $window_debug += "called #{self.class}.update.\n"
    update_logic
    return nil unless @win
    @win.refresh
    $window_debug += "#{self.class} after update is:\n#{to_s}"
    $window_debug += "@arr.object_id is: #{@arr.object_id}"
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

class List < Window
  include Highlighting

  def post_initialize(args)
    @num_lines = args.fetch(:lines, nil) || @height
    @col_arr = args.fetch(:color_arr, nil) || [[:white, :black]]
    post_post_initialize(args)
  end

  def post_post_initialize(args); end

  def win_update
    #gets the last @num_lines lines of @content (or all if length < @num_lines)
    to_print = @content.length > @num_lines ? @content[-@num_lines...@content.length] : @content
    y = 0
    @win.erase
    to_print.each do |line|
      @win.setpos(y,0)
      c_pair = get_line_color(y)
      c_num = return_c_pair(c_pair[0], c_pair[1]) 
      col = Curses.color_pair(c_num)
      @win.attron(col)
      @win.addstr(line.ljust(@width - @padding * 2))
      @win.attroff(col)
      y += @height/@num_lines
      break if y > @height
    end
    @win.refresh
    $window_debug += "called #{self.class}.update. to_print is: #{to_print}\n"
  end

  def get_line_color(line_num)
    return 0 if @col_arr.empty?
    i = line_num % @col_arr.length
    @col_arr[i]
  end
end

class Menu < List
  include InteractiveWindow
  include Highlighting

  def post_post_initialize(args)
    @actions = args.fetch(:actions) #a 2D array containing a string to display and a lambda to call = ["Start Game", ->{ game_start}]
    @pos_y = 0
    @selected_col = args.fetch(:col2, nil)
    @unselected_col = args.fetch(:col1, nil)
    update
  end

  def to_up
    if @pos_y - 1 >= 0
      @pos_y -= 1
    end
    update
  end

  def to_down
    if @pos_y + 1 <= @content.length - 1
      @pos_y += 1
    end
    update
  end 

  def active
    @actions[@pos_y]
  end

  def get_line_color(line_num)
    if line_num == @pos_y
      col = @selected_col
    else
      col = @unselected_col 
    end
  end

  def select
    @break = true
    @win.erase
    active.call
  end

  def key_map
    { Keys::UP => -> { to_up },
      Keys::DOWN => -> { to_down },
      Keys::ENTER => -> { select }}
  end

  def before_get_input
    Curses.noecho
    Curses.curs_set(0)
    @win.keypad(true)
  end

  def get_input
    @win.getch
  end

  def break_condition
    @break
  end

  def post_get_input
    @win.keypad(false)
    Curses.curs_set(1)
  end
end


class TypingField < Window
 include InteractiveWindow
 include Highlighting

 def post_initialize(args)
   @bg = args.fetch(:bg, nil) #colors should be passed as symbols used in Highlighting
   @fg = args.fetch(:fg, nil)
   @input_to_return = "" 
   @break = false
 end

 def set_color
   col = Curses.color_pair(return_c_pair(@fg, @bg))
   @win.attron(col)
   @win.setpos(0,0)
   @win.addstr(@input_to_receive.to_s.ljust(@width))
   @win.attroff(col)
   @win.setpos(0,0)
   @win.touch
   @win.refresh
 end

 def key_map
   {Keys::ENTER => -> { @break = true},
    Keys::BACKSPACE => -> { on_backspace }}
 end

 def on_backspace
   y = @win.cury
   x = @win.curx
   if x > 0 || y > 0
     if x == 0 && y > 0
       y -= 1
       x = @width
     else
       x -= 1
     end

     @win.setpos(y, x)
     @win.delch
     @input_to_return = @input_to_return.slice(0, @input_to_return.length - 1)
     update
   end
 end

 def break_condition
   @break
 end

 def before_get_input
   @input_to_return = ""
   Curses.noecho
   @win.keypad(true)
   @win.setpos(0,0)
   @win.attron(Curses.color_pair(return_c_pair(@fg, @bg))) 
 end

 def get_input
   chr = @win.getch
 end

 def handle_unmapped_input(input)
   #don't echo or add characters to input if there is no space remaining in field
   if @win.curx < @width -1
     @win.addch(input) 
     @input_to_return += input.to_s
   end
 end

 def post_get_input
   @win.attroff(Curses.color_pair(return_c_pair(@fg, @bg)))
   Curses.echo
   @win.keypad(false)
   @win.erase
   @win.refresh
 end

end

class CursorMap < Map
  include InteractiveWindow

  def post_post_initialize(args)
    @pos_x = 0
    @pos_y = 0
    @stored_input = nil
    $window_debug += "#{self.class}.post_initialize called."
  end
 
  def reset_pos
    @cursor_x = 0
    @cursor_y = 0
    update_cursor_pos
  end

  def key_map
    { Keys::UP => -> { to_up },
      Keys::DOWN => -> { to_down },
      Keys::LEFT => -> { to_left },
      Keys::RIGHT => -> { to_right},
      Keys::ENTER => -> { on_enter },
      Keys::BACKSPACE => -> { on_backspace }}
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
    update_cursor_pos
    @win.getch
  end

  def before_get_input
    update_cursor_pos
    @win.redraw
    @input_to_return = nil
    @stored_input = nil
    Curses.noecho
    Curses.cbreak
    Curses.curs_set(1)
    @win.keypad(true)
  end

  def post_get_input
    @win.keypad(false)
  end

  def return_input
    @input_to_return
  end

  def break_condition
    @input_to_return
  end

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
  screen = InteractiveScreen.new(height: 20, width: 40, top: 10, left: 10)

  field = TypingField.new(height: 1, width: 18, top: 24, left: 12, fg: :magenta, bg: :white)
  test_color_map = CursorMap.new(top: 12, left: 12, arr: arr, str: test_str, key: "X", bg_map: bg_map, fg_map: fg_map)
  bg_map = bg_map.gsub("M", "C")
  fg_map = fg_map.gsub("M", "C")
  map_two = CursorMap.new(top: 12, left: 40, arr: arr, str: test_str, key: "X", bg_map: bg_map, fg_map: fg_map)

  inputgetter = InputHandler.new(in:screen)

  screen.add_region(field)
  screen.add_region(map_two)
  screen.add_region(test_color_map)
  screen.update
  

  board.move(pieces.first, [3,3])
  screen.update
  returned_input = inputgetter.get_input
ensure
  Curses.close_screen
end

  puts "returned input was: #{returned_input}"
end


#Actual useful function
def get_board_map(board)
 
  board_str = "   a  b  c  d  e  f  g  h   \n" +
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
  arr = board.arr 
 
  top = (Curses.lines - board.arr.length) /2
  left = (Curses.cols - board.arr.first.length) /2
  board_map = CursorMap.new(top: top, 
                            left: left, 
                            arr: arr, 
                            content: board_str, 
                            key: "X", 
                            bg_map: bg_map, 
                            fg_map: fg_map)

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

def test_field
begin
  Curses.init_screen
  Curses.start_color

  h = 2
  w = 10
  t = 12
  l = 12
  field = TypingField.new(height: h, width: w, top: t, left: l, fg: :magenta, bg: :white)

  win = CursesWrapper.new_window(height: h, width: w, top: t, left: l)
  field.set_win(win)
  win.setpos(0,0)
  field.get_input
ensure
  Curses.close_screen
end
end

def test_color_set
begin
  Curses.init_screen
  Curses.start_color
  Curses.init_pair(1, Curses::COLOR_MAGENTA, Curses::COLOR_WHITE)
  h = 10
  w = 20
  win = Curses::Window.new(h, w, 12, 12)

  win.color_set(1)

  h.times do
    w.times do
      win.addch(" ")
    end
  end
  win.refresh

  win.setpos(0,0)
  win.getstr
ensure
  Curses.close_screen
end
end

def my_game
  Curses.close_screen
  puts "starting game!"
end

def see_rules
  Curses.close_screen
  puts "Here are some rules!"
end

def load_game
  Curses.close_screen
  puts "Choose a game to load..."
end

def quit
  Curses.close_screen
  puts "you quit the game!"
end

def test_menu
begin
  Curses.init_screen
  Curses.start_color

  h = 5
  w = 20
  t = 12
  l = 12

  options = [ ["Start game", -> { my_game }],
              ["Check rules", -> {see_rules}],
              ["Load game", -> { load_game }],
              ["Quit", -> { quit }]]


  my_menu = Menu.new(height: h,
                     width: w,
                     top: t,
                     left: l,
                     options: options,
                     col1: [:white, :black],
                     col2: [:red, :yellow])


  inputgetter = InputHandler.new(in: my_menu)

  inputgetter.get_input
ensure
  Curses.close_screen
end

end


if __FILE__ == $0

  test_screen

end
