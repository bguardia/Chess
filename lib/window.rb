require 'pry'
require 'curses'
require './lib/chess.rb'
require './lib/game.rb'
require './lib/board.rb'
require './lib/piece.rb'

$window_debug = ""

module ColorSchemes
  THEMES ||= { 
    :waves =>
    { col1: [:black, :cyan],
      col2: [:white, :cyan],
      col3: [:yellow, :blue],
      bg_bg: :blue,
      bg_fg: :cyan,
      bg_bkgd: ["  )",  " ( "],
      title_col2: [:white, :cyan],
      board_base_col: :black,
      board_dark_col: [:yellow, :yellow],
      board_highlight: :cyan,
      move_history_col2: [:white, :yellow],
      title_border_top: "-",
      title_border_side: "|" },

    :radical =>
    { col1: [:yellow, :black],
      col2: [:white, :black],
      col3: [:red, :yellow],
      bg_bg: :red,
      bg_fg: :yellow,
      bg_bkgd: ["/ ","\\ "],
      board_dark_col: [:yellow, :yellow],
      board_highlight: :red,
      move_history_col2: [:red, :yellow],
      title_border_top: "-",
      title_border_side: "|" },
      
    :ninja_turtle =>
    { col1: [:red, :green],
      col2: [:white, :green],
      col3: [:white, :red],
      board_dark_col: [:red, :red],
      board_highlight: :green,
      bg_bg: :green,
      bg_fg: :black,
      bg_bkgd: [" )(  )( ","(  )(  )"], 
      field_col2: [:white, :red],
      title_col1: [:green, :red],
      title_col2: [:white, :red],
      title_border_top: "-",
      title_border_side: "|" },

    :purple =>
    { col1: [:black, :magenta],
      col2: [:white, :magenta],
      col3: [:magenta, :b_green],
      bg_bkgd: "|",
      bg_fg: :green,
      board_dark_col: [:green, :green],
      board_highlight: :magenta,
      title_border_top: "-",
      title_border_side: "|" },

    :yellow =>
    { col1: [:black, :yellow],
      col2: [:white, :yellow],
      col3: [:yellow, :black],
      bg_bg: :white,
      bg_fg: :yellow,
      bg_bkgd: [" / \\ ","(   )", " \\ / "],
      title_col1: [:white, :yellow],
      board_dark_col: [:cyan, :cyan],
      board_highlight: :yellow,
      move_history_col2: [:white, :cyan],
      title_border_top: "-",
      title_border_side: "|"  },

    :monochrome =>
    { col1: [:black, :white],
      col2: [:black, :white],
      col3: [:white, :black],
      bg_bg: :white,
      bg_fg: :black,
      bg_bkgd: "\\",
      board_dark_col: [:white, :black],
      piece_col: :magenta,
      board_base_col: :black,
      title_border_top: "-",
      title_border_side: "|"  }
   }

  def self.get(theme)
    if THEMES.has_key?(theme.to_sym)
      return THEMES[theme.to_sym]
    else
      return THEMES[:monochrome]
    end
  end
end

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

  def bright?(col)
    col.to_s.include?("b_")
  end

  #Highlights a single character or row of characters with curses
  def c_highlight(win, chr, pos)
    data = get_highlight_data(pos[1], pos[0])
    color_pair = c_color_pairs.fetch(data, nil) || new_c_pair(data)
    win.attron(Curses.color_pair(color_pair))
    win.setpos(pos[0], pos[1])
    win.addstr(chr)
    win.attroff(Curses.color_pair(color_pair))
  end

  def c_temp_highlight(win, chr, pos, colors)
    color_pair = c_color_pairs.fetch(colors, nil) || new_c_pair(colors)
    
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

  def get_highlight_data(x, y)
    if y >= 0  && y < highlight_arr.length
      if x >= 0 && x < highlight_arr[y].length
        return highlight_arr[y][x]
      end
    end
    
    return [:green, :purple] #highlight_arr.first.first
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

  #If set to true, an InteractiveScreen will change to next active region
  def lose_focus
    @in_focus = false
  end

  def set_focus
    @in_focus = true
  end

  def focus
    @in_focus
  end

  def check_focus
  end

  #Stores any special keys used by a paticular context
  #(Will be over-ridden by arguments passed to input_handler)
  def key_map
    @key_map ||= {}
  end

  def set_key_map(key_map)
    @key_map = key_map
  end

  def merge_key_map(key_map)
    @key_map = @key_map.merge(key_map)
  end

  def get_action(action_str)
    method(action_str)
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
  def input_to_return=(val)
    @input_to_return = val
  end

  def return_input
    @input_to_return
  end
end

class Window
  include Highlighting
  attr_reader :win, :content
  
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

    @col1 = args.fetch(:col1, nil) || [:black, :white] #color of border and padded area of windows
    @col2 = args.fetch(:col2, nil) || @col1 #color of window content
    @col3 = args.fetch(:col3, nil) || [:red, :black] #color of highlighted elements
    @fg = args.fetch(:fg, nil) || @col1[0]
    @bg = args.fetch(:bg, nil) || @col1[1]
    @bkgd = args.fetch(:bkgd, nil) || " " #pass a string or an array of strings for bkgd characters

    @border_top = args.fetch(:border_top, nil)
    @border_side = args.fetch(:border_side, nil)
=begin
    $window_debug += "Initializing #{self.class}:\n@height: #{@height}\n" +
                     "@width: #{@width}\n@top: #{@top}\n@left: #{@left}\n" +
                     "@padding: #{@padding}\n@padding_left: #{@padding_left}\n" +
                     "@padding_right: #{@padding_right}\n@padding_top: #{@padding_top}\n" +
                     "@padding_bottom: #{@padding_bottom}\n"
=end
    @border_win = nil #encapsulating window with border + padding
    @win = create_win #window to handle output

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

  def clear
    @win.erase
    @content = ""
  end

  def create_win
    #$game_debug += "Called create_win\n"
    @border_win = Curses::Window.new(@height, @width, @top, @left)
    
    if border_top && border_side
      #$game_debug += "border_top is: #{border_top}, border_side is: #{border_side}\n"
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

    bkgd_chr_arr = [].push(@bkgd).flatten
    @height.times do
      @border_win.setpos(y, 0)
      chr = bkgd_chr_arr[y % bkgd_chr_arr.length]
      @border_win.attron(col) do
        multiplier = @width / chr.length
        left_over = @width - chr.length * multiplier 
        @border_win.addstr( (chr * multiplier) + chr[0, left_over] )
      end
      y += 1
    end
    if border_top && border_side
      @border_win.attron(col | Curses::A_BOLD) do 
        @border_win.box(border_side, border_top)
      end 
    end
    @border_win.refresh
  end

  def arrayify_str(str)
    content_w = @width - @padding_left - @padding_right
    str_arr = []
    if str.include?("\n")
      str_arr = str.split("\n")
    else
      i = 0
      loop do
        eol = i + content_w < str.length ? i + content_w : str.length - 1
        str_arr << str[i..eol]
        i = eol + 1
        break if i >= str.length
      end
    end
    
    #Go over each line of string array, checking current and next lines
    #If current string is too long, or a word is broken up between both strings,
    #cut the overflow from current string and place it at beginning of next string
    str_arr.each_index do |l|
      cur_line = str_arr[l]
      next_line = l + 1 < str_arr.length ? str_arr[l + 1].to_s : ""
      
      if cur_line.length > content_w || (( next_line[0] != " " && next_line[0] != nil ) && cur_line[-1] != " " )
         overflow = cur_line.slice!(/\s[[:graph:]]+$/).to_s #turn to string in case of nil returns
         str_arr[l + 1] = next_line.insert(0, overflow)
      end

    end

    return str_arr
  end

  def win_update
    if @content.kind_of?(String)
      to_print = arrayify_str(@content)
    elsif @content.nil?
      to_print = @content.to_a
    else
      to_print = @content
    end

    col = Curses.color_pair(return_c_pair(@col2[0], @col2[1]))
    y = 0
    @win.attron(col) do 
      to_print.each do |line|
        @win.setpos(y,0)
        @win.addstr(line.chomp.ljust(@width))
        y += 1
      end
    end
    
    @win.refresh
  end

  def update
    border_win_update 
    win_update
  end
end

class ColorfulWindow < Window

  def post_initialize(args)
    set_color_map(args)
  end

  def set_color_map(args)
    bg_map = args.fetch(:bg_map)
    fg_map = args.fetch(:fg_map)
    color_arr = create_color_arr(fg_map, bg_map)
    init_highlight_arr(color_arr)
  end

  def win_update
    str_arr = @content.map { |row| row.chomp.split("") }
    curses_colorize_str(@win, str_arr)
    @win.refresh
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
    @key_map = default_key_map.merge(args.fetch(:key_map, {}))   
  end

  def default_key_map
    { Keys::TAB =>-> { change_active_rgn },
      Keys::ESCAPE => -> { @break = true }}

  end

  def change_active_rgn(inc = 1)
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
      @active_region.set_focus
      @active_region.before_get_input
    else
      next_i = (i + inc) % l
      @active_region.post_get_input
      @active_region = interactive[next_i]
      @active_region.set_focus
      @active_region.before_get_input
    end

    #$game_debug += "Active Region is now: #{@active_region.class}\n"
    return @active_region
  end

  public
  def interactive_rgns
    @regions.filter { |r| r.respond_to?(:interactive) }
  end

  def to_next
    change_active_rgn
  end

  def to_previous
    change_active_rgn(-1)
  end

  def set_active_region(rgn)
    if @regions.include?(rgn)
      @active_region = rgn
      rgn.set_focus
      return true
    end  
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

  def check_focus
    if active_region.focus == false 
      #$game_debug += "Active region: #{active_region.class}.focus is false. Changing region.\n"
      change_active_rgn
    end
  end

  def get_input
    active_region.get_input
  end

  def get_action(action_str)
    if @active_region.respond_to?(action_str)
      @active_region.method(action_str)
    else
      method(action_str)
    end
  end

  def break
    @break = true
  end

  def break_condition
    @break || active_region.break_condition
  end

  def key_map
    @key_map
    if active_region  
      @key_map.merge(active_region.key_map)
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

  def highlight_cell(pos, color = [:black, :yellow])
    str_pos = arr_to_str_pos(pos)
    chr = @str_arr[str_pos[0]][str_pos[1]]
    c_temp_highlight(@win, chr, str_pos, color)
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
    @cols = args.fetch(:cols, nil) || 1
    @just = args.fetch(:just, nil) || "left"
    @item_padding = args.fetch(:item_padding, nil) || 0
    @colified_content_map = Array.new(@cols) { Array.new(@num_lines) } 
    #@col_arr = args.fetch(:color_arr, nil) || [[:white, :black]]
    post_post_initialize(args)
  end

  def post_post_initialize(args); end

  def justify(str, size)
    if @just == "left"
      str.to_s.ljust(size)
    else
      str.to_s.rjust(size)
    end
  end

  def colify_content
    total_spaces = @num_lines * @cols
    #Advance all stored indexes if content array size if greater than total spaces
    #and last stored index is second-to-last element of content
    if @content.length > total_spaces && @colified_content_map[-1][-1].to_i == @content.length - 2
      @colified_content_map.map! do |col_arr|
        col_arr.map! do |el|
          el.to_i + 1
        end
      end
    end

    #Add all elements of @content which are not already stored
      stored_items = @colified_content_map.reduce(0) { |tot, col_arr| tot + col_arr.compact.length }
      (@content.length - stored_items).times do |i|
        @colified_content_map.each_index do |col_num|
          col = @colified_content_map[col_num]
          open_index = col.index(nil)
          next unless open_index
          @colified_content_map[col_num][open_index] = stored_items + i #store index of item in @contents
          break
        end
      end
    
  end

  def win_update
    colify_content
    to_print = []


    content_width = @width - @padding * 2
    @num_lines.times do |i|
      temp_str = ""
      @cols.times do |j|
        content_index = @colified_content_map[j][i]
        item = content_index ? @content[content_index] : nil
        temp_str += justify(item, content_width/@cols)
      end
      to_print << temp_str
    end

    y = 0
    @win.erase

    c_pair = get_line_color(y)
    c_num = return_c_pair(c_pair[0], c_pair[1]) 
    col = Curses.color_pair(c_num)
    @win.attron(col) do
      to_print.each do |line|
        @win.addstr(justify(line, content_width))
        y += 1
        @item_padding.times do 
          @win.addstr(@bkgd * (@width - @padding * 2))
          y += 1
          break if y > @height
        end
        break if y > @height
      end

    (@height - y).times do 
      @win.setpos(y,0)
      @win.addstr(@bkgd * (@width - @padding * 2))
      y += 1
    end
    end

    @win.refresh
    $window_debug += "called #{self.class}.update. to_print is: #{to_print}\n"
  end

  def get_line_color(line_num)
=begin
    return 0 if @col_arr.empty?
    i = line_num % @col_arr.length
    @col_arr[i]
=end
    @col2
  end
end

class Menu < List
  include InteractiveWindow
  include Highlighting

  def post_post_initialize(args)
    @actions = args.fetch(:actions) #a 2D array containing a string to display and a lambda to call = ["Start Game", ->{ game_start}]
    @pos_y = 0
    @prev_pos_y = 0
    @break_on_select = args.fetch(:break_on_select, true) 
    @loop_selection = args.fetch(:loop, false)
    #@col2 = args.fetch(:col2, nil)
    #@col1 = args.fetch(:col1, nil)
    @item_padding = args.fetch(:item_padding, nil) || 0
    @key_map = default_key_map.merge(args.fetch(:key_map, {}))

    #$game_debug += "Menu contents (length: #{@content.length}) are: #{@content}\n"
    clean_content
    update
  end

  def default_key_map
    { Keys::UP => -> { to_up },
      Keys::DOWN => -> { to_down },
      Keys::ENTER => -> { select }}
  end

  def update_prev_pos
    @prev_pos_y = @pos_y
  end

  def clean_content
    @content.map! do |item|
      item.split("\n").map do |line|
        line.ljust(@width - @padding_left - @padding_right)
      end
    end
  end

  def to_up
    if @pos_y - 1 >= 0
      update_prev_pos
      @pos_y -= 1
    else
      if @loop_selection
        @pos_y = @content.length - 1
      else
        lose_focus
      end
    end
    update
  end

  def to_down
    if @pos_y + 1 <= @content.length - 1
      update_prev_pos
      @pos_y += 1
    else
      if @loop_selection
        @pos_y = 0
      else
        lose_focus
      end
    end
    update
  end 

  def selected
    @pos_y
  end

  def active
    @actions[@pos_y]
  end

  def get_line_color(line_num)
    if @in_focus && line_num == @pos_y
      col = @col3
    else
      col = @col2 
    end
  end

  def select
    @break = true if @break_on_select
    @win.erase
    active.call
  end

  def write_arr(line_arr, pos_y)
      c_pair = get_line_color(pos_y)
      c_num = return_c_pair(c_pair[0], c_pair[1]) 
      col = Curses.color_pair(c_num)
      @win.attron(col) do
      line_arr.each do |line|
        @win.addstr(line.ljust(@width - @padding * 2, @bkgd))
      end
      end
  end

  def win_update
    y = 0
    pos_y = 0
    blank_line = " " * (@width - @padding_left - @padding_right)
    menu_str = @content.map { |item| item.join }.join(blank_line * @item_padding)
    c_num = return_c_pair(@col2[0], @col2[1])
    col = Curses.color_pair(c_num)
    @win.setpos(0,0)
    @win.attron(col) do
      @win.addstr(menu_str)
    end
   
    if @in_focus 
    selected_line_num = @pos_y * (@content.first.length + @item_padding)
    $game_debug += "selected_line_num is: #{selected_line_num}\n"
    @win.setpos(selected_line_num, 0)
    c_num = return_c_pair(@col3[0], @col3[1])
    col = Curses.color_pair(c_num)
    @win.attron(col) do
      @win.addstr(@content[@pos_y].join)
    end
    end
    @win.refresh
  end

  def key_map
    @key_map
  end

  def before_get_input
    set_focus
    update
    @win.keypad(true)
    @break = false
  end

  def get_input
    @win.getch
  end

  def break_condition
    @break
  end

  def post_get_input
    @win.keypad(false)
  end
end


class TypingField < Window
 include InteractiveWindow
 include Highlighting

 def post_initialize(args)
   #@bg = args.fetch(:bg, nil) #colors should be passed as symbols used in Highlighting
   #@fg = args.fetch(:fg, nil)
   @input_to_return = "" 
   @content = ""
   @break = false
   @key_map = default_key_map.merge(args.fetch(:key_map, {}))
 end

 def default_key_map
   {Keys::ENTER => -> { @break = true},
    Keys::BACKSPACE => -> { on_backspace },
    Keys::LEFT => -> { to_left },
    Keys::RIGHT => -> { to_right }}
 end
 
 def to_left
   x = @win.curx
   y = @win.cury
   if x > 0
     @win.setpos(y, x - 1)
   end
 end

 def to_right
   x = @win.curx
   y = @win.cury
   if x < @content.length 
     @win.setpos(y, x + 1)
   end
 end

 def in_bounds?(x , y)
   if x > 0 && x < @width && y > 0 && y < @width
     true
   end
 end

 def set_color
   col = Curses.color_pair(return_c_pair(@col2[0], @col2[1]))
   @win.attron(col)
   @win.setpos(0,0)
   @win.addstr(@input_to_receive.to_s.ljust(@width))
   @win.attroff(col)
   @win.setpos(0,0)
   @win.touch
   @win.refresh
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
     @input_to_return.slice!(x)
     @content = @input_to_return
     @win.setpos(y, @content.length)
     @win.addstr(" " * (@width - @content.length))
     #update
     #@win.attron(Curses.color_pair(return_c_pair(@col2[0], @col2[1]))) 
     @win.setpos(y, x)
   end
 end

 def break_condition
   @break
 end

 def before_get_input
   #@input_to_return = ""
   Curses.curs_set(1)
   @win.keypad(true)
   @win.setpos(0,0)
   @win.attron(Curses.color_pair(return_c_pair(@col2[0], @col2[1]))) 
 end

 def get_input
   chr = @win.getch
 end

 def handle_unmapped_input(input)
   #don't echo or add characters to input if there is no space remaining in field
   x = @win.curx
   if x < @width -1
     #currently replaces selected characters
     @win.addch(input) 
     @input_to_return[x] = input
     @content = @input_to_return
   end
 end

 def post_get_input
   @win.attroff(Curses.color_pair(return_c_pair(@col2[0], @col2[1])))
   Curses.curs_set(0)
   @win.keypad(false)
 end

end

class CursorMap < Map
  include InteractiveWindow

  def post_post_initialize(args)
    @pos_x = 0
    @pos_y = 0
    @stored_input = nil
    @key_map = default_key_map.merge(args.fetch(:key_map, {}))
    $window_debug += "#{self.class}.post_initialize called."
  end

  def pos_x
    @pos_x
  end

  def pos_y
    @pos_y
  end

  def reset_pos
    @cursor_x = 0
    @cursor_y = 0
    update_cursor_pos
  end

  def default_key_map
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
    if @stored_input == current_pos
      on_backspace
    elsif @stored_input
      @input_to_return = [@stored_input.dup, current_pos]
      @stored_input = nil
    else
      @stored_input = current_pos
      something = @arr[current_pos[0]][current_pos[1]]
      if something && something.possible_moves
        something.possible_moves.map do |mv|
          pos = mv.destination(something)
          str_pos = arr_to_str_pos(pos)
          chr = @str_arr[str_pos[0]][str_pos[1]]
          c_temp_highlight(@win, chr, str_pos, @col3)
        end
      str_pos = arr_to_str_pos(current_pos)
      chr = @str_arr[str_pos[0]][str_pos[1]]
      c_temp_highlight(@win, chr, str_pos, @col3)
      #get highlights from board and update map display with highlights
      end 
    end 
  end

  def on_backspace
    if @stored_input
      something = @arr[@stored_input[0]][@stored_input[1]]
      if something && something.possible_moves
        something.possible_moves.map do |mv|
          pos = mv.destination(something)
          str_pos = arr_to_str_pos(pos)
          chr = @str_arr[str_pos[0]][str_pos[1]]
          c_highlight(@win, chr, str_pos)
        end
      
      str_pos = arr_to_str_pos(@stored_input)
      chr = @str_arr[str_pos[0]][str_pos[1]]
      c_highlight(@win, chr, str_pos)
      end
      @stored_input = nil
    end
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
    update
    @input_to_return = nil
    @stored_input = nil
    Curses.curs_set(1)
    @win.keypad(true)
  end

  def post_get_input
    Curses.curs_set(0)
    @win.keypad(false)
  end

  def return_input
    @input_to_return
  end

  def break_condition
    @input_to_return
  end

end

class Button < Window
  include Highlighting
  include InteractiveWindow

  def post_initialize(args)
    #@col1 = args.fetch(:col1, nil)
    #@fg = @col1[0]
    #@bg = @col1[1]
    #@col2 = args.fetch(:col2, nil)
    @highlighted = false
    @action = args.fetch(:action, nil) || Proc.new { @break = true }
    @key_map = default_key_map.merge(args.fetch(:key_map, {}))
    #$game_debug += "Button initialized. @col1: #{@col1}, @col2: #{@col2}, @highlighted: #{@highlighted}\n"
  end

  def default_key_map
    { Keys::ENTER => ->{ press },
      Keys::UP => ->{ lose_focus
                      update },
      Keys::DOWN => ->{ lose_focus
                        update } }
  end

  def press
    @action.call
  end

  def before_get_input
    @highlighted = true
    @win.keypad(true)
    update
  end

  def get_input
    @win.getch
  end

  def break_condition
    @break
  end

  def post_get_input
    @highlighted = false
    @win.keypad(false)
    update
  end

  def win_update
    if @highlighted
      c_pair = @col3
    else
      c_pair = @col2
    end

    @win.erase
    c_num = return_c_pair(c_pair[0], c_pair[1]) 
    col = Curses.color_pair(c_num)
    @win.attron(col)
    @win.addstr(@content.ljust(@width))
    @win.attroff(col)
    @win.refresh
  end
end

module WindowTemplates

  def self.color_set
    @@color_set ||= ColorSchemes.get(Settings.get("theme"))
  end

  def self.screen_height
    @@screen_height ||= Curses.lines
  end

  def self.screen_width
    @@screen_width ||= Curses.cols
  end

  def self.fullscreen_window_settings
    { height: self.screen_height,
      width: self.screen_width,
      top: 0,
      left: 0 }
  end

  def self.default_background_settings
    screen_h = self.screen_height
    screen_w = self.screen_width
    color_scheme = ColorSchemes.get(Settings.get("theme"))
    col1 = color_scheme[:col1]

    { bg_height: screen_h,
      bg_width: screen_w,
      bg_top: 0,
      bg_left: 0,
      bg_col1: col1 }.merge(self.color_set)
  end

  def self.default_window_settings
    #unless @@default_window_settings
      screen_h = self.screen_height
      screen_w = self.screen_width

      pad = 2
      def_h = screen_h < 40 ? screen_h/2 : 15 + pad * 2
      def_w = screen_w < 88 ? screen_w/2 : 40 + pad * 2
      def_t = (screen_h - def_h) / 2
      def_l = (screen_w - def_w) / 2

      border_top = "-"
      border_side = "|"
    #end

    @@default_window_settings = self.color_set.merge(:screen_h => screen_h,
                                                      :screen_w => screen_w,
                                                      :height => def_h,
                                                      :width => def_w,
                                                      :top => def_t,
                                                      :left => def_l,
                                                      :padding => pad,
                                                      :border_top => border_top,
                                                      :border_side => border_side )

  end

  def self.create_subhash(hash, key_substr)
    #pull values from hash that contain key_substr and
    #create new hash where each key has key_substr removed

    subhash = hash.transform_keys do |key|
      key_str = key.to_s
      if key_str.start_with?(key_substr)
        key_str.sub("#{key_substr}_", "").to_sym #remove substr and underscore from key
      else
        :to_delete #mark all other keys for deletion from subhash
      end 
    end

    subhash.delete(:to_delete)

    return subhash
  end

  def self.default_btn_set_settings(args = {})
    padding = args.fetch(:btn_set_padding, nil) || 1
    win_padding = args.fetch(:padding, nil) || 1
    win_width = args.fetch(:width, nil)
    width = win_width ? win_width - win_padding * 2 : 10
    height = self.default_button_settings[:btn_height] + padding * 2
    col1 = self.color_set[:col1] 
    col2 = self.color_set[:col2] 
    col3 = self.color_set[:col3] 

    {  btn_set_width: width,
       btn_set_height: height,
       btn_set_padding: padding,
       btn_set_padding_left: padding,
       btn_set_padding_right: padding,
       btn_set_padding_bottom: padding,
       btn_set_padding_top: padding,
       #btn_set_border_top: "",
       #btn_set_border_bottom: "",
       btn_set_col1: col1,
       btn_set_fg: col1[0],
       btn_set_bg: col1[1],
       btn_set_col2: col2,
       btn_set_col3: col3,
       btn_set_top: 0,
       btn_set_left: 0 }.merge(self.color_set) 
  end

  def self.default_button_settings(args = {})
    #Create default button settings based on content of button
    content = args.fetch(:btn_content, nil) || "OK"
    padding = args.fetch(:btn_padding, nil) || 1
    col1 = self.color_set[:col1] 
    col2 = self.color_set[:col2] 
    col3 = self.color_set[:col3] 

    { btn_padding: padding,
      btn_padding_left: padding,
      btn_padding_right: padding,
      btn_padding_bottom: padding,
      btn_padding_top: padding,
      btn_height: 1 + padding * 2,
      btn_width: content.length + padding * 2 + 2,
      btn_border_top: "-",
      btn_border_side: "|",
      btn_col1: col1,
      btn_col2: col2,
      btn_col3: col3,
      btn_top: 0,
      btn_left: 0 }.merge(self.color_set)
  end

  def self.default_title_settings(args = {})
    padding = args.fetch(:title_padding, nil) || 1
    title = args.fetch(:title_content, nil) || "Window"
    width = args.fetch(:width, nil) || title.length + padding * 2
    col1 = self.color_set[:col1] 
    col2 = self.color_set[:col2] 
    col3 = self.color_set[:col3] 

    { title_padding: padding,
      title_padding_left: padding,
      title_padding_right: padding,
      title_padding_bottom: padding,
      title_padding_top: padding,
      title_height: 1 + padding * 2,
      title_width: width,
      #title_border_top: "",
      #title_border_side: "",
      title_col1: col1,
      title_col2: col2,
      #title_fg: col1[0],
      #title_bg: col1[1],
      title_col3: col3,
      title_top: 0,
      title_left: 0 }.merge(self.color_set) 
  end

  def self.default_field_settings(args = {})
    padding = args.fetch(:field_padding, nil) || 1
    col1 = self.color_set[:col1] 
    col2 = self.color_set[:col2] 
    col3 = self.color_set[:col3] 

    { field_padding: padding,
      field_padding_left: padding,
      field_padding_right: padding,
      field_padding_bottom: padding,
      field_padding_top: padding,
      field_width: 15,
      field_height: 3,
      field_col1: col1,
      field_col2: col2,
      field_col3: col3,
      field_top: 0,
      field_left: 0 }.merge(self.color_set)
  end

  def self.default_menu_settings(args = {})
=begin
    win_padding_left = args.fetch(:padding_left, nil) || args.fetch(:padding)
    win_padding_right = args.fetch(:padding_right, nil) || args.fetch(:padding)
    width = args.fetch(:width) - win_padding_left - win_padding_right
    left = args.fetch(:left) + win_padding_left
=end
    content = args.fetch(:menu_content, nil).to_a
    height = content.length
    padding = args.fetch(:menu_padding, nil) || 1
    col1 = self.color_set[:col1] 
    col2 = self.color_set[:col2] 
    col3 = self.color_set[:col3] 

    { menu_padding: padding,
      menu_padding_left: padding,
      menu_padding_right: padding,
      menu_padding_bottom: padding,
      menu_padding_top: padding,
      menu_line_padding: 1,
      menu_width: 10,
      menu_height: height,
      menu_border_top: "-",
      menu_border_side: "|",
      menu_col1: col1,
      menu_col2: col2,
      menu_fg: col1[0],
      menu_bg: col1[1],
      menu_col3: col3,
      menu_top: 0,
      menu_left: 0 }.merge(self.color_set)
  end

  def self.pop_up(window)
    #initiates a window that disappears after receiving input
    padding = 10

    win = Window.new(content: str,
                     padding: padding,
                     centered: true,
                     border_top: "-",
                     border_side: "|")
    win.update
    input = win.get_input
    win.close
    return input
  end

  def self.interactive_screen
    screen_args = self.create_subhash(self.default_background_settings, "bg")
    screen = InteractiveScreen.new(screen_args)
  end

  def self.interactive_pop_up(interactive_window)
    input_handler = InputHandler.new(in: interactive_window)
    interactive_window.update
    input = input_handler.get_input
    interactive_window.close
    return input
  end

  def self.menu(args = {})
    h = args.fetch(:height)
    w = args.fetch(:width)
    t = args.fetch(:top)
    l = args.fetch(:left)
    col1 = args.fetch(:col1, [:white, :black])
    col2 = args.fetch(:col2, [:red, :yellow])
    content = args.fetch(:content)
    actions = args.fetch(:actions)
    num_lines = args.fetch(:num_lines, nil) || h
    menu = Menu.new(height: h,
                    width: w,
                    top: t,
                    left: l,
                    lines: num_lines,
                    content: content,
                    actions: actions,
                    col1: col1,
                    col2: col2)
    
  end

  def self.multipage_window(args = {})
=begin 
    default_window_settings = { height: 30,
                                width: 20,
                                top: 0,
                                left: 0,
                                border_top: "-",
                                border_side: "|",
                                padding: 1,
                                padding_left: 1,
                                padding_right: 1,
                                padding_top: 1,
                                padding_bottom: 1 }
=end

    args = self.default_window_settings.merge(args)

    screen = InteractiveScreen.new(args)


    #Create title
    #title_content = args.fetch(:title, nil) || "Title"
    title_win = self.window_title(args)
=begin
    title_win = Window.new(height: 3,
                           width: screen.width - 2,
                           padding: 1,
                           top: screen.top + 1,
                           left: screen.left + 1,
                           content: title)
=end

    #Create pages
    pages = args.fetch(:pages, nil) || []
    current_page_index = 0
    total_pages = pages.length

    #page-turning logic
    change_page = ->(inc, rollover = true){ 
      if rollover
        current_page_index = current_page_index + inc % total_pages
      else
        new_index = current_page_index + inc
        current_page_index = new_index >= 0 && new_index < total_pages ? new_index : current_page_index
      end
      pages[current_page_index].update
    }

    to_next_page = -> { change_page.call(1, false) }
    to_previous_page = -> { change_page.call(-1, false) }

    #Create navigation buttons
    button_arr = [["Back", to_previous_page],
                  ["Close", nil],
                  ["Next", to_next_page]]

    btn_set_top = screen.top + screen.height - 5
    button_set = self.button_set(args.merge(buttons: button_arr,
                                 #width: screen.width,
                                 btn_set_top: btn_set_top,
                                 btn_set_left: screen.leftx))
                                 #col1: args.fetch(:col1),
                                 #col2: args.fetch(:col2))


    #add title and buttons to screen
    screen.add_region(title_win)
    screen.add_region(button_set)

    #display first page
    pages[current_page_index].update

    return screen
  end

  def self.button_set(args = {})
=begin
    default_window_settings = { height: 5,
                                width: 15,
                                top: 0,
                                left: 0,
                                btn_border_top: "-",
                                btn_border_side: "|",
                                padding: 1,
                                padding_top: 1,
                                padding_left: 1,
                                padding_right: 1,
                                padding_bottom: 1,
                                key_map: { Keys::LEFT => "to_previous" ,
                                           Keys::RIGHT => "to_next" }}

=end

    #Create Button Window
    btn_set_default = self.default_btn_set_settings(args).merge(args)
    btn_set_args = self.create_subhash(btn_set_default, "btn_set")
    $game_debug += "btn_set_args:\n#{btn_set_args}\n"
    btn_window = InteractiveScreen.new(btn_set_args)

    #set button set key map
    btn_window.merge_key_map(Keys::LEFT => ->{ btn_window.to_previous },
                             Keys::RIGHT => ->{ btn_window.to_next })

    #Collect window settings for button calculations
    win_h = btn_set_args[:height] #args.fetch(:height)
    win_w = btn_set_args[:width] #args.fetch(:width)
    win_t = btn_set_args[:top] #args.fetch(:top)
    win_l = btn_set_args[:left] #args.fetch(:left)
    padding_left = btn_set_args[:padding_left] #args.fetch(:padding_left)
    padding_right = btn_set_args[:padding_right] #args.fetch(:padding_right)
    padding_top = btn_set_args[:padding_top] #args.fetch(:padding_top)
    padding_bottom = btn_set_args[:padding_bottom] #args.fetch(:padding_bottom)
    padding = btn_set_args[:padding] #args.fetch(:padding)

    button_arr = args.fetch(:buttons, nil) || []
    num_btns = button_arr.length
=begin
    btn_h = 3
    btn_padding = 1
    btn_str_len = button_arr.reduce(0) { |longest, arr| arr[0].length > longest ? arr[0].length : longest }
    btn_border_len = 2
    btn_w = btn_str_len + btn_padding + btn_border_len
    btn_padding_left = (win_w - (padding_left + padding_right) - (btn_w * num_btns)) / (num_btns + 1) #automatically rounds down
    btn_padding_top = (win_h - (padding_top + padding_bottom) - btn_h) / 2
    btn_t = win_t + padding_top + btn_padding_top
    btn_border_top = args.fetch(:btn_border_top, nil) || args.fetch(:border_top, nil)
    btn_border_side = args.fetch(:btn_border_side, nil) || args.fetch(:border_side, nil)
=end
    btn_count = 0
    longest_content = button_arr.reduce("") { |longest, arr| arr[0].length > longest.length ? arr[0] : longest }
    btn_default = self.default_button_settings(btn_set_args.merge(btn_content: longest_content)).merge(btn_set_args)
    btn_args = self.create_subhash(btn_default, "btn")
    btn_w = btn_args[:width]
    btn_h = btn_args[:height]
    btn_padding_left = (win_w - (padding_left + padding_right) - (btn_w * num_btns)) / (num_btns + 1) #automatically rounds down
    btn_padding_top = (win_h - (padding_top + padding_bottom) - btn_h) / 2
    btn_t = win_t + padding_top + btn_padding_top
    button_arr.each do |btn_arr|
      btn_l = win_l + padding_left + (btn_padding_left * (btn_count + 1)) + btn_w * btn_count 
      btn = Button.new(btn_args.merge(#height: btn_h,
                       #width: btn_w,
                       top: btn_t,
                       left: btn_l,
                       #padding: btn_padding,
                       content: btn_arr[0],
                       action: btn_arr[1],
                       #col1: [:white, :black],
                       #col2: [:red, :yellow],
                       #border_top: btn_border_top,
                       #border_side: btn_border_side,
                       key_map: {}))

      btn_window.add_region(btn)
      btn_count += 1
    end

    return btn_window
  end

  def self.menu_two(args = {})
    win_h = args.fetch(:height)
    win_w = args.fetch(:width)
    win_t = args.fetch(:top)
    win_l = args.fetch(:left)

    col1 = args.fetch(:col1, [:white, :black])
    col2 = args.fetch(:col2, [:red, :yellow])
    content = args.fetch(:content)
    actions = args.fetch(:actions, nil)
    
   
    padding = args.fetch(:padding, nil) || 1
    padding_top = args.fetch(:padding_top, nil) || padding
    padding_left = args.fetch(:padding_left, nil) || padding
    padding_right = args.fetch(:padding_right, nil) || padding
    padding_bottom = args.fetch(:padding_bottom, nil) || padding
    
    win_args = self.default_window_settings.merge(args)
    menu_screen = InteractiveScreen.new(win_args.merge(#height: win_h,
                                                   #width: win_w,
                                                   #top: win_t,
                                                   #left: win_l,
                                                   #padding: padding,
                                                   border_top: "-",
                                                   border_side: "|"))

    #$game_debug += "Created menu screen\n"
    title_h = 3
    title_w = win_w - (padding * 2)
    title_t = win_t + padding_top
    title_l = win_l + padding_left
    #title = args.fetch(:title, nil) || "Load Save"
    title_padding = args.fetch(:title_padding, nil) || 1
    
    default_title_settings = self.default_title_settings(args).merge(args)
    title_args = self.create_subhash(default_title_settings, "title")
    menu_title = Window.new(title_args.merge(#height: title_h,
                            width: title_w,
                            top: title_t,
                            left: title_l,
                            #content: title,
                            padding: title_padding))

    #$game_debug += "Created menu title\n"

    btn_title = args.fetch(:btn, nil) || "Cancel"
    btn_h = 3
    btn_w = args.fetch(:btn_width, nil) || btn_title.length + (padding * 2) #btn_title.length
    btn_t = args.fetch(:btn_t, nil) || win_t + win_h - btn_h  - padding_bottom #bottom-aligned
    btn_l = win_l + ((win_w - btn_w) / 2)   #centered

    btn_padding = args.fetch(:btn_padding, nil) || 1
    default_button_settings = self.default_button_settings(args).merge(args)
    btn_args = self.create_subhash(default_button_settings, "btn")
    menu_cancel_button =  Button.new(btn_args.merge(height: btn_h,
                                     width: btn_w,
                                     top: btn_t,
                                     left: btn_l,
                                     content: btn_title,
                                     #col1: col1,
                                     #col2: col2,
                                     padding: btn_padding))
                                     #border_top: "-",
                                     #border_side: "|"))

    #$game_debug += "Created menu button\n"

    menu_h = win_h - title_h - padding_top - padding_bottom
    menu_h = btn_t < win_h + win_t ? menu_h + (btn_t - win_t - win_h) : menu_h #only subtract button height from menu width if button is inside window
    menu_w = win_w - (padding * 2)
    menu_t = title_h + title_t
    menu_l = win_l + padding_left
    num_lines = args.fetch(:lines, nil) || menu_h
    item_padding = args.fetch(:item_padding, nil)

    #Default behavior for actions is to return index of content selected
    if actions.nil?
      num_content = content.length
      actions = []
      num_content.times do |i|
        actions << ->{ menu_screen.break; return i }
      end
    end


    default_menu_settings = self.default_menu_settings(args).merge(args)
    menu_args = self.create_subhash(default_menu_settings, "menu")
    menu = Menu.new(menu_args.merge(height: menu_h,
                    width: menu_w,
                    top: menu_t,
                    left: menu_l,
                    lines: num_lines,
                    item_padding: item_padding,
                    content: content,
                    actions: actions))
                    #col1: col1,
                    #col2: col2))

    menu.merge_key_map(Keys::ENTER => ->{ menu.input_to_return = menu.selected; menu_screen.break; })

    menu_screen.add_region(menu_title)
    menu_screen.add_region(menu_cancel_button)
    menu_screen.add_region(menu)

    menu_screen.set_active_region(menu)
    return menu_screen
  end

  def self.save_menu(args = {}) #must pass :content
    default_settings = self.color_set.merge( height: 35,
                         width: 55,
                         top: (Curses.lines - 35)/2,
                         left: (Curses.cols - 55)/2,
                         menu_border_top: nil,
                         menu_border_side: nil,
                         lines: 3, 
                         title: "Load Save", 
                         item_padding: 1,
                         btn_width: 55,
                         btn_t: (Curses.lines - 35)/2 +35 )

    args = default_settings.merge(args)

    self.menu_two(args)

  end

  def self.input_box(args = {})
    padding = args.fetch(:padding, nil) || 1
    default_window_settings = {height: 15,
                               width: 35,
                               top: 0,
                               left: 0,
                               padding: padding,
                               padding_left: padding,
                               padding_right: padding,
                               padding_top: padding,
                               padding_bottom: padding,
                               col1: [:white, :black],
                               col2: [:red, :yellow],
                               border_top: "-", 
                               border_side: "|" }

    args = default_window_settings.merge(args)
    screen = InteractiveScreen.new(args)
    padding_left = args.fetch(:padding_left)
    padding_right = args.fetch(:padding_right)
    padding_top = args.fetch(:padding_top)
    padding_bottom = args.fetch(:padding_bottom)

    content_width = screen.width - padding_left - padding_right

    #title
    title_w = screen.width - padding_left - padding_right
    title_t = screen.top + padding_top
    title_l = screen.left + padding_left
    #title = args.fetch(:title, nil) || "Input Box"
    title_win = WindowTemplates.window_title(args.merge(#title_content: title,
                                             title_width: title_w,
                                             title_top: title_t,
                                             title_left: title_l))
    screen.add_region(title_win)
    
    #OK Button
    btn_w = 6
    #btn_h = 5
    btn_t = screen.top + screen.height - 3  - padding_bottom
    btn_l = screen.left + (screen.width - btn_w) / 2
    button_default_settings = self.default_button_settings(args).merge(args)
    button_args = self.create_subhash(button_default_settings, "btn")
    button = Button.new(button_args.merge(content: "OK",
                        #height: btn_h,
                        width: btn_w,
                        top: btn_t,
                        left: btn_l,
                        action: ->{}))
                        #col1: [:white, :black],
                        #col2: [:red, :yellow])

    screen.add_region(button)

    #Field
    field_h = 3    
    field_t = title_t + title_win.height + (btn_t - (title_t + title_win.height) - field_h) / 2
    field_w = content_width < 20 ? content_width - 2 : 20 
    field_l = screen.left + (screen.width - field_w) / 2
    default_field_settings = self.default_field_settings(args).merge(args)
    field_args = self.create_subhash(default_field_settings, "field")
    field = TypingField.new(field_args.merge(height: field_h,
                            width: field_w,
                            top: field_t,
                            left: field_l,
                            padding: 1,
                            border_top: "-",
                            border_side: "|"))
                            #bg: :black,
                            #fg: :white)

    field.merge_key_map({ Keys::UP => -> { field.lose_focus },
                          Keys::DOWN =>->{ field.lose_focus }, 
                          Keys::ENTER =>->{ field.lose_focus }})

    button.set_key_map({ Keys::UP =>->{button.lose_focus},
                         Keys::ENTER =>->{button.input_to_return = field.content
                                          screen.break }})

    screen.add_region(field)
    screen.update
    screen.set_active_region(field)
    return screen
  end

  def self.settings_menu(args = {})
    default_window_settings = {height: 25,
                               width: 35,
                               top: 0,
                               left: 0,
                               col1: [:white, :black],
                               col2: [:red, :yellow],
                               border_top: "-",
                               border_side: "|"}

    args = default_window_settings.merge(args)

    settings_window = InteractiveScreen.new(args)

    settings = args.fetch(:settings)
    current_settings = {}
    settings.each_key do |key|
      current_settings[key] = settings[key][:active]
    end
    new_settings = current_settings.dup
    menu_contents = []
    sub_menus = []
    sub_menu_displays = []

    #window settings
    win_h = args.fetch(:height)
    win_w = args.fetch(:width)
    win_t = args.fetch(:top)
    win_l = args.fetch(:left)
    padding = args.fetch(:padding, nil) || 1
    padding_left = args.fetch(:padding_left, nil) || padding
    padding_right = args.fetch(:padding_right, nil) || padding
    padding_top = args.fetch(:padding_top, nil) || padding
    padding_bottom = args.fetch(:padding_bottom, nil) || padding

    col1 = args.fetch(:col1)
    col2 = args.fetch(:col2)
    col3 = args.fetch(:col3)

    menu_padding = 5

    #window title
    title = args.fetch(:title, nil) || "Settings"
    title_w = win_w - padding_left - padding_right
    title_t = win_t + padding_top
    title_l = win_l + padding_left
    title_win = self.window_title(args.merge(title_content: title,
                                  title_width: title_w,
                                  title_top: title_t,
                                  title_left: title_l))

    settings_window.add_region(title_win)

    #Calculate sub_menu settings

    key_length = settings.keys.reduce(0) { |l,k| k.length > l ? k.length : l } 
    sub_l = win_l + padding_left + key_length + menu_padding
    sub_t = title_t + title_win.height + 1 
    sub_menu_padding = 1
    sub_menu_padding_left = 2
    sub_menu_padding_right = 2

    #Create a menu for each set of options
    default_menu_settings = self.default_menu_settings(args).merge(args)
    menu_args = self.create_subhash(default_menu_settings, "menu")
    settings.each_key do |key|
      options = settings[key][:options]
      sub_w = options.reduce(0) { |w,k| k.length > w ? k.length : w } + sub_menu_padding_left + sub_menu_padding_right  #longest string + padding
      menu_contents << key.to_s
      currently_selected = [settings[key][:active]]
      sub_menu_actions = options.map { |op| ->{ new_settings[key] = op; currently_selected[0] = op } }
      sub_menu = Menu.new(menu_args.merge(height: options.length + sub_menu_padding * 2,
                          width: sub_w,
                          top: sub_t,
                          left: sub_l,
                          #col1: col1,
                          #col2: col2,
                          padding: sub_menu_padding,
                          padding_left: sub_menu_padding_left,
                          padding_right: sub_menu_padding_right,
                          content: options,
                          actions: sub_menu_actions,
                          border_top: "-",
                          border_side: "|",
                          loop: true))
      
      #Create window that displays currently selected item from sub-menu
      sub_menu_displays << Window.new(height: 1,
                                    width: 10,
                                    top: sub_t,
                                    left: sub_l,
                                    content: currently_selected,
                                    col1: col1,
                                    col2: col2,
                                    fg: col1[0],
                                    bg: col1[1])

      #sub_menu.merge_key_map({ Keys::ESCAPE => ->{sub_menu.lose_focus} })
      sub_menus << sub_menu
      #settings_window.add_region(sub_menu)
      sub_t += 1
    end
    

    #Create button set
    btn_t = win_t + win_h - 5 - 1
    btn_l = win_l + padding_left
    btn_w = win_w - padding_left - padding_right
    button_set = self.button_set(args.merge(btn_set_top: btn_t,
                                 btn_set_left: btn_l,
                                 btn_set_width: btn_w,
                                 buttons: [["Save", ->{  settings_window.break; return new_settings }],
                                           ["Cancel", ->{  settings_window.break; return current_settings }]]))

    button_set.set_key_map({ Keys::UP =>->{ button_set.lose_focus },
                             Keys::LEFT =>->{ button_set.to_previous },
                             Keys::RIGHT =>->{ button_set.to_next }})
   
    button_set.interactive_rgns.each do |rgn|
      if rgn.content == "Save"
        return_settings = new_settings
      else
        return_settings = current_settings
      end
        rgn.set_key_map({ Keys::ENTER =>->{ rgn.input_to_return = return_settings; settings_window.break }})
    end

    settings_window.add_region(button_set)

    #Creat main menu

    #create actions for main settings menu
    #Pressing enter in main menu will put corresponding sub_menu in focus
    actions = sub_menus.map do |sub_menu|
      ->{ InputHandler.new(in: sub_menu).get_input; settings_window.update }
    end

    #Menu dimensions
    menu_t = title_t + title_win.height + 1
    menu_l = win_l + padding_left
    menu_h = win_h - title_win.height - button_set.height
    menu_w = sub_l - win_l - padding_left #(Changed not to overlap sub_menu_displays; old on right:) win_w - padding_left - padding_right
    menu = Menu.new(height: 3,
                    width: menu_w,
                    top: menu_t,
                    left: menu_l,
                    content: menu_contents, 
                    actions: actions,
                    col1: col1,
                    col2: col2,
                    col3: col3,
                    fg: col1[0],
                    bg: col1[1],
                    break_on_select: false)

    settings_window.add_region(menu)
    sub_menu_displays.each { |win| settings_window.add_region(win) }
    settings_window.set_active_region(menu)
    return settings_window
  end

  def self.color_cmap(map, col_args = {})
    color_char_hash = Highlighting::COLOR_CODES.invert
    col1 = col_args.fetch(:col1, nil) || :black
    col2 = col_args.fetch(:col2, nil) || :b_white
    col3 = col_args.fetch(:col3, nil) || :b_magenta
    char1 = color_char_hash[col1]
    char2 = color_char_hash[col2]
    char3 = color_char_hash[col3]
    map.gsub(/[123]/, '1' => char1, '2' => char2, '3' => char3)
  end


  def self.game_board_bg_map(args = {})
    bg_map =  "1111111111111111111111111111\n" +
             (("1122233322233322233322233311\n" +
               "1133322233322233322233322211\n") * 4) +
               "1111111111111111111111111111\n"
=begin
    color_char_hash = Highlighting::COLOR_CODES.invert
    col1 = args.fetch(:col1, nil) || :black
    col2 = args.fetch(:col2, nil) || :b_white
    col3 = args.fetch(:col3, nil) || :b_magenta
    char1 = color_char_hash[col1]
    char2 = color_char_hash[col2]
    char3 = color_char_hash[col3]

    bg_map = bg_map.gsub(/[123]/, '1' => char1, '2' => char2, '3' => char3)
=end
    col_pair1 = args.fetch(:col1, nil)
    col1 = col_pair1 ? col_pair1[1] : :black
    col2 = :b_white
    col3 = args.fetch(:col2, nil) || [:yellow, :b_magenta]

    border_col = args.fetch(:board_base_col, nil) || col3[1] #one-square wide base surrounding board
    light_col = args.fetch(:board_light_col, nil) || [:white, :white] #light square color (second value)
    dark_col = args.fetch(:board_dark_col, nil) || [:b_magenta, :b_magenta] #light dark color (second value)

    self.color_cmap(bg_map, col1: border_col, col2: light_col[1], col3: dark_col[1])
  end

  def self.game_board_fg_map(args = {})
    fg_map = "  222333222333222333222333222  \n" +
             (("331111111111111111111111111    \n" +
               "221111111111111111111111111    \n") * 4 ) +
               "                            "
=begin
    #color nums chosen to match bg_map
    color_char_hash = Highlighting::COLOR_CODES.invert
    col2 = args.fetch(:col2, nil) || :b_white
    col3 = args.fetch(:col3, nil) || :b_magenta
    char2 = color_char_hash[col2]
    char3 = color_char_hash[col3]

    fg_map = fg_map.gsub(/[23]/, '2' => char2, '3' => char3)
=end
    piece_col = args.fetch(:piece_col, nil) || :black #color of all piece icons
    light_col = args.fetch(:board_light_col, nil) || [:white, :white] #light square font color for rank/file markings (first val)
    dark_col = args.fetch(:board_dark_col, nil) || [:b_magenta, :b_magenta] #dark square font color for rank/file markings (first val)
    self.color_cmap(fg_map, col1: piece_col, col2: light_col[0], col3: dark_col[0])
  end

  def self.game_board(args = {})
    board_str = "   a  b  c  d  e  f  g  h   \n" +
                "8| X  X  X  X  X  X  X  X | \n" +
                "7| X  X  X  X  X  X  X  X | \n" +
                "6| X  X  X  X  X  X  X  X | \n" +
                "5| X  X  X  X  X  X  X  X | \n" +
                "4| X  X  X  X  X  X  X  X | \n" +
                "3| X  X  X  X  X  X  X  X | \n" +
                "2| X  X  X  X  X  X  X  X | \n" +
                "1| X  X  X  X  X  X  X  X | \n" + 
                "                            \n"
    
    board_color = args.fetch(:board_color, nil) || :b_magenta
    bg_map = self.game_board_bg_map(args.merge(self.color_set))
    fg_map = self.game_board_fg_map(args.merge(self.color_set))
    #$game_debug += "bg_map is: #{bg_map}"
    #$game_debug += "fg_map is: #{fg_map}"
    arr = args.fetch(:board).arr 
 
    board_highlight = args.fetch(:board_highlight, nil) || :yellow
    top = args.fetch(:top, (Curses.lines - arr.length) /2)
    left = args.fetch(:left, (Curses.cols - arr.first.length) /2)
    board_map = CursorMap.new(top: top, 
                              left: left, 
                              arr: arr, 
                              content: board_str, 
                              key: "X", 
                              bg_map: bg_map, 
                              fg_map: fg_map,
                              col3: [:black, board_highlight],
                              empty_chr: "_")

  end

  def self.self_scrolling_feed(args)
    content_arr = args.fetch(:content, nil) ? args.fetch(:content) : []
    default_list_settings = { lines: 10,
                              content: content_arr }

    args = default_list_settings.merge(args)
    self_scrolling_feed = List.new(args) 

    return [self_scrolling_feed, content_arr]
  end

  def self.window_title(args)
    title = args.fetch(:title_content, nil) || "Window"
    width = args.fetch(:title_width, nil) || 10
    padding_left = padding_right = (width - title.length) / 2

=begin
    default_title_settings = { height: 3,
                               width: 10,
                               padding_top: 1,
                               padding_bottom: 1,
                               padding_left: padding_left,
                               padding_right: padding_right,
                               content: title }
=end

    default_title_settings = self.default_title_settings(args).merge(args)
    title_args = self.create_subhash(default_title_settings, "title")
    return Window.new(title_args.merge(padding_left: padding_left,
                                       padding_right: padding_right))

  end

  def self.confirmation_screen(args = {})
    default_settings = { height: 10,
                         border_top: "-",
                         border_side: "|" }

    args = default_settings.merge(args)
    win_h = args.fetch(:height)
    win_w = args.fetch(:width)
    win_t = args.fetch(:top)
    win_l = args.fetch(:left)
    padding = args.fetch(:padding, nil) || 1
    padding_left = args.fetch(:padding_left, nil) || padding
    padding_right = args.fetch(:padding_right, nil) || padding
    padding_top = args.fetch(:padding_top, nil) || padding
    padding_bottom = args.fetch(:padding_bottom, nil) || padding

    win_args = self.default_window_settings.merge(args)
    screen = InteractiveScreen.new(win_args)

    
    title_h = 3
    title_w = win_w - padding_right - padding_left
    title_t = win_t + padding_top
    title_l = win_l + padding_left

    #title = args.fetch(:title, nil) || "Window"
    title_win = self.window_title(args.merge(#title_content: title,
                                  title_width: title_w, 
                                  title_top: title_t,
                                  title_left: title_l))

    btn_h = 5
    buttons = args.fetch(:buttons, nil) || [["Yes", nil], ["No", nil]]

    default_button_settings = args.merge( btn_set_height: btn_h,
                                          btn_set_width: win_w - padding * 2,
                                          btn_set_top: win_t + win_h - btn_h - 1,
                                          btn_set_left: win_l + padding_left,
                                          buttons: buttons )

    button_set = self.button_set(default_button_settings)
    
    button_set.interactive_rgns.each do |rgn|
      if rgn.content == "Yes"
        to_return = 1
      else
        to_return = 0
      end
      rgn.merge_key_map(Keys::ENTER => ->{ rgn.input_to_return = to_return; screen.break})
    end

    content = args.fetch(:content, nil) || ""
    win_args = self.default_window_settings.merge(args)
    content_win = Window.new(win_args.merge(height: win_h - title_h - btn_h - padding_top - padding_bottom,
                             width: win_w - padding_left - padding_right,
                             top: title_t + title_h,
                             left: win_l + padding_left,
                             content: content)) 

    screen.add_region(title_win)
    screen.add_region(button_set)
    screen.add_region(content_win)

    return screen

  end


  def self.game_screen(args = {})

    h = args.fetch(:height, Curses.lines)
    w = args.fetch(:width, Curses.cols)
    t = args.fetch(:top, 0)
    l = args.fetch(:left, 0)

    border_top = args.fetch(:border_top, nil) || "-"
    border_side = args.fetch(:border_side, nil) || "|"

    col_hash = { :col1 => args[:col1],
                 :col2 => args[:col2],
                 :col3 => args[:col3] }

    bg_settings = self.default_background_settings
    bg_args = self.create_subhash(bg_settings, "bg")
    game_screen = InteractiveScreen.new(bg_args)
=begin
    game_screen = InteractiveScreen.new(col_hash.merge(height: h, 
                                        width: w, 
                                        top: t, 
                                        left: l))
=end

    padding = 2
    win_h = 25 + padding * 2
    win_w = 95 + padding * 2
    win_t = (game_screen.height - win_h) / 2
    win_l = (game_screen.width - win_w) / 2
    game_window = InteractiveScreen.new(col_hash.merge(height: win_h,
                                                       width: win_w,
                                                       top: win_t,
                                                       left: win_l,
                                                       border_top: "-",
                                                       border_side: "|"))

    $game_debug += "win_h: #{win_h}, win_w: #{win_w}, win_t: #{win_t}, win_l: #{win_l}\n"

    game_title = args.fetch(:title_content, nil) || "Game"
    title_h = 3
    title_t = win_t + padding
    title_l = win_l + (win_w - (padding * 2) - game_title.length) / 2
    game_title_display = self.window_title(col_hash.merge(title_width: game_title.length + 2,
                                                          title_height: title_h,
                                                          title_top: title_t,
                                                          title_left: title_l,
                                                          title_content: game_title))

=begin
      Window.new(col_hash.merge(height: title_h,
                                    width: game_title.length,
                                    left: title_l,
                                    top: title_t,
                                    content: game_title))
=end

    $game_debug += "title_h: #{title_h}, title_t: #{title_t}, title_l: #{title_l}\n"


    mh_h = win_h - title_h - padding * 2 - 2
    mh_w = 31 #board_l - win_l - padding * 2
    mh_t = title_t + game_title_display.height
    mh_l = win_l + padding
    mh_lines = (mh_h - 1) / 2
    move_history_input = args.fetch(:move_history_input) || []
    move_history_args = self.create_subhash(self.color_set, "move_history")
    move_history_feed = self.self_scrolling_feed(col_hash.merge(height: mh_h,
                                                 width: mh_w,
                                                 top: mh_t,
                                                 left: mh_l,
                                                 padding: 1,
                                                 cols: 2,
                                                 content: move_history_input,
                                                 lines: mh_lines,
                                                 item_padding: 1,
                                                 border_top: border_top, 
                                                 border_side: border_side).merge(move_history_args))
    
    $game_debug += "mh_h: #{mh_h}, mh_w: #{mh_w}, mh_t: #{mh_t}, mh_l: #{mh_l}\n"

    mh_title_content = "Move History"
    mh_title_l = mh_l #+ (mh_w - mh_title_content.length) / 2
    mh_title_t = title_t + 2
    move_history_label = Window.new(col_hash.merge(top: mh_title_t,
                                    left: mh_title_l,
                                    content: mh_title_content))

    $game_debug += "mh_title_l: #{mh_title_l}\n"

    message_input = args.fetch(:message_input) || []

    board = args.fetch(:board) || Board.new
    board_color = args.fetch(:board_color, nil) || :b_magenta 
    board_arr = board.to_s.split("\n")
    board_h = board_arr.length
    board_w = 27 #board_arr[1].length
    board_t = mh_t #win_t + (win_h - padding * 2 - board_h) / 2 + title_h
    board_l = mh_l + mh_w + padding #win_l + (win_w - padding * 2 - board_w) / 2
    board_map = self.game_board(args.merge(board: board,
                                top: board_t,
                                left: board_l,
                                board_color: board_color))
                                   
    $game_debug += "board_h: #{board_h}, board_w: #{board_w}, board_t: #{board_t}, board_l: #{board_l}\n"
    mf_h = 3
    mf_w = mh_w
    mf_t = mh_t + mf_h 
    mf_l = board_l + board_w + 1
    message_feed = self.self_scrolling_feed(col_hash.merge(height: mf_h, 
                                            width: mf_w, 
                                            top: mf_t,
                                            left: mf_l,
                                            content: message_input,
                                            lines: 1,
                                            just: "right"))
    
    $game_debug += "mf_h: #{mf_h}, mf_w: #{mf_w}, mf_t: #{mf_t}, mf_l: #{mf_l}\n"
    td_w = 18
    td_l = win_l + win_w - padding - td_w
    turn_display_input = args.fetch(:turn_display_input) || []
    turn_display = self.self_scrolling_feed(col_hash.merge(height: mf_h,
                                            width: td_w,
                                            top: mh_title_t,
                                            left: td_l,
                                            content: turn_display_input,
                                            lines: 1))

   
    #Controls window
    ctrl_win_h = 2
    ctrl_win_w = win_w - padding * 2
    ctrl_win_t = win_t + win_h - 3
    ctrl_win_l = win_l + padding
    ctrl_content = "Controls:\n Arrow Keys-> move cursor, Backspace-> deselect piece, Q-> quit game, S-> save game"
    ctrl_win = Window.new(col_hash.merge(height: ctrl_win_h,
                                         width: ctrl_win_w,
                                         top: ctrl_win_t,
                                         left: ctrl_win_l,
                                         content: ctrl_content))
    game_window.add_region(ctrl_win)
    game_window.add_region(game_title_display)
    game_window.add_region(board_map)
    game_window.add_region(move_history_feed[0])
    game_window.add_region(message_feed[0])
    game_window.add_region(move_history_label)
    game_window.add_region(turn_display[0])
    game_screen.add_region(game_window)
    return game_screen
  end
end

def test_map

  test_str = "   a  b  c  d  e  f  g  h \ \n" +
             "1| X  X  X  X  X  X  X  X | \n" +
             "2| X  X  X  X  X  X  X  X | \n" +
             "3| X  X  X  X  X  X  X  X | \n" +
             "4| X  X  X  X  X  X  X  X | \n" +
             "5| X  X  X  X  X  X  X  X | \n" +
             "6| X  X  X  X  X  X  X  X | \n" +
             "7| X  X  X  X  X  X  X  X | \n" +
             "8| X  X  X  X  X  X  X  X | \n" + 
             " \________________________\ \n"
   
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
  Curses.init_screen
  Curses.start_color
  screen = InteractiveScreen.new(height: 20, width: 40, top: 10, left: 10, border_top: "-", border_side: "|")
  screen.update
  gets
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
                            fg_map: fg_map,
                            empty_chr: "_")

end

def test_cursor_map
 
  test_str = "   a  b  c  d  e  f  g  h   \n" +
             "8| X  X  X  X  X  X  X  X | \n" +
             "7| X  X  X  X  X  X  X  X | \n" +
             "6| X  X  X  X  X  X  X  X | \n" +
             "5| X  X  X  X  X  X  X  X | \n" +
             "4| X  X  X  X  X  X  X  X | \n" +
             "3| X  X  X  X  X  X  X  X | \n" +
             "2| X  X  X  X  X  X  X  X | \n" +
             "1| X  X  X  X  X  X  X  X | \n" + 
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
=begin
  h = 10
  w = 25
  t = 12
  l = 12
  options = [ ["Start game", -> { my_game }],
              ["Check rules", -> {see_rules}],
              ["Load game", -> { load_game }],
              ["Quit", -> { quit }]]

  content = ["Start game",
             "Check rules",
             "Load game",
             "Quit"]
  actions = [->{ my_game },
             ->{ see_rules },
             ->{ load_game }, 
             ->{ quit }]

  my_menu = WindowTemplates.menu_two(height: h,
                     width: w,
                     top: t,
                     left: l,
                     content: content,
                     actions: actions,
                     col1: [:white, :black],
                     col2: [:red, :yellow],
                     title: "Start Menu")


  my_menu.update
  inputgetter = InputHandler.new(in: my_menu)

=end

  #inputgetter.get_input

  btn_arr = [["Go Back", -> { puts "Pressed go back"; exit }],
            ["Accept", -> { puts "Pressed accept"; exit }],
            ["Next", -> { puts "Pressed Next"; exit }]]
  btn_window = WindowTemplates.button_set(height: 7,
                                          width: 35,
                                          buttons: btn_arr,
                                          top: 5,
                                          left: 5,
                                          padding: 1)

  btn_window.update
  inputgetter = InputHandler.new(in: btn_window)
  inputgetter.get_input

end

def test_multipage_window

  win_h = 30
  win_w = 40
  win_t = 5
  win_l = 5

  page_contents = ["This is the first page.\n It has a lot of great info. \n So read carefully.",
                   "This is the second page.\n Wow! It works!. \n Let's keep reading,",
                   "This is the third page.\n Are you impressed?\n There are more pages.",
                   "This is the last page. \n Did you enjoy it?\n Great!"]

  page_h = win_h - 10
  page_w = win_w - 2
  page_t = win_t + 3 + 1
  page_l = win_l + 1
  pages = []
  page_contents.each do |content|
    pages.push(Window.new(height: page_h,
                          width: page_w,
                          top: page_t,
                          left: page_l,
                          content: content))
  end

  mp_window = WindowTemplates.multipage_window(height: win_h,
                                               width: win_w,
                                               top: win_t,
                                               left: win_l,
                                               pages: pages)
  mp_window.update
  inputgetter = InputHandler.new(in: mp_window)
  inputgetter.get_input
end

def test_settings_menu

  h = 30
  w = 40
  t = 5
  l = 5

  title = "Settings"

  settings = { background_color: { active: "black",
                                   options: ["red", "yellow", "blue", "black", "green"] },
               board_color: { active: "purple",
                              options: ["red", "purple", "blue", "green", "yellow"] },
               ai_difficulty: { active: "easy",
                                options: ["easy", "normal", "hard", "insane"] }}
  settings_menu = WindowTemplates.settings_menu(title: title,
                                                height: h,
                                                width: w,
                                                top: 5,
                                                left: 5,
                                                settings: settings)

  settings_menu.update

  new_settings = InputHandler.new(in: settings_menu).get_input
  $window_debug += "Settings returned from settings menu are: #{new_settings}\n"
end

def test_confirmation_screen

  win_h = 30
  win_w = 40
  win_t = 5
  win_l = 5

  title = "Confirmation"
  content = "Do you really want to quit the game?\nIt's so fun that you should probably never stop!"

  confirm_window = WindowTemplates.confirmation_screen(height: win_h,
                                                       width: win_w,
                                                       top: win_t,
                                                       left: win_l,
                                                       title: title,
                                                       content: content)

  confirm_window.update
  inputgetter = InputHandler.new(in: confirm_window)
  inputgetter.get_input
end

if __FILE__ == $0

  begin
    Curses.init_screen
    Curses.start_color

    test_settings_menu
  ensure
    Curses.close_screen
    puts $window_debug
  end

end
