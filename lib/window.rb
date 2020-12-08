require 'curses'
require './lib/game.rb'


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

class Window

  attr_reader :height, :width, :top, :left, :cursor_x, :cursor_y

  def initialize(args)
    args = default.merge(args)

    #window variables
    @height = args[:height]
    @width = args[:width]
    @top = args[:top]
    @left = args[:left]
    @cursor_x = 0
    @cursor_y = 0
    @win = CursesWrapper.new_window(args)

    #subwindow variables
    @sub_wins = []
    @active_window = @window

    setpos(@cursor_x, @cursor_y)
  end

  def default
    {}
  end

  def window
    @window
  end

  def addstr(str)
    window.addstr(str)
  end

  def setpos(x, y)
    window.setpos(x, y)
  end

  def refresh
    window.refresh
  end

  def getch
    window.getch
  end

  def get_char
    window.get_char
  end

  def keypad(bool)
    window.keypad(bool)
  end

  def close
    window.close
  end
 
  def reset_pos
    @cursor_x = 0
    @cursor_y = 0
    update_cursor_pos
  end

  def up
    if @cursor_x - 1 >= 0 
      @cursor_x -= 1
      update_cursor_pos
    end
  end

  def down
    if @cursor_x + 1 <= @height
      @cursor_x += 1
      update_cursor_pos
    end
  end

  def left
    if @cursor_y - 1 >= 0
      @cursor_y -= 1
      update_cursor_pos
    end
  end

  def right
    if @cursor_y <= @width
      @cursor_y += 1
      update_cursor_pos
    end
  end

  def update_cursor_pos
    setpos(@cursor_x, @cursor_y)
  end

  def begin_cursor_control
    Curses.noecho
    Curses.crmode

    loop do
      #responses based on input and current context
    end

  end

  def begin_echo_typing
    Curses.echo
    Curses.nocrmode
  end

  def insert_sub_window(args)
    p = args.fetch(:padding, 2)
    height = args.fetch(:height, @height - p*2)
    width = args.fetch(:width, @width - p*2)
    top = args.fetch(:top, @top + p)
    left = args.fetch(:left, @left + p)
    @sub_windows << @window.subwin(height, width, top, left)

    return @sub_windows.last
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


def test
  begin
    Curses.init_screen
    Curses.noecho
    Curses.crmode
    

    win1 = create_window("Window 1", 20, 50, 5, 10)
    Curses.refresh

    win1.keypad(true)

    loop do
      input = win1.get_char.to_s
      win1.addstr(input)
      win1.refresh
    end

  ensure
    Curses.echo
    Curses.close_screen
  end
end


def create_window(str, height, width, top, left)
  win = Window.new(height: height, width: width, top: top, left: left)
  win.setpos(height/2, width/2)
  win.addstr(str)
  Curses.refresh
  win.refresh
  return win
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

def log_win(height, width)
  top = 2
  left = (Curses.cols - width) / 2
  win = CursesWrapper.new_window(height: height,
                                 width:  width,
                                 top: top,
                                 left: left,
                                 border_top: "-",
                                 border_side: "|" )

  win.setpos(height, 0)
  return win
end

def create_log
  height = 10
  width = 40
  win = log_win(height, width)
  log_arr = []

  log_func = ->(str) do
    str = str.chomp.gsub(/[[:cntrl:]]/) { |m| Regexp.escape(m) } 
    log_arr << str
    win.setpos(0,0)
    log_arr.last(height).each do |s|
      disp_s = s[0...width] + "\n" 
      win.addstr(disp_s)
    end
    win.refresh
  end

  return log_func

end

def test_refresh
  begin
  Curses.init_screen
  height = 20
  width = 20
  mid_top = Curses.lines / 2
  mid_left = Curses.lines / 2
  offset = 5
  win1 = CursesWrapper.new_window(height: height,
                                  width: width,
                                  top: mid_top,
                                  left: mid_left - width - offset,
                                  border_top: "x",
                                  border_side: "o")
  win2 = CursesWrapper.new_window(height: height,
                                  width: width,
                                  top: mid_top,
                                  left: mid_left + offset,
                                  border_top: "<",
                                  border_side: "^")

  win1.addstr("window 1")
  win2.addstr("window 2")
  win1.refresh
  win2.refresh
  win1.getch
  win1.addstr("update 1")
  win2.addstr("update 2")
  win2.refresh
  win1.getch
ensure
  Curses.close_screen
end

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


if __FILE__ == $0

  test_board

end
