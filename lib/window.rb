require 'curses'

class Window

  attr_reader :height, :width, :top, :left, :cursor_x, :cursor_y, :sub_windows

  def initialize(args)
    args = default.merge(args)
    @height = args[:height]
    @width = args[:width]
    @top = args[:top]
    @left = args[:left]
    @cursor_x = 0
    @cursor_y = 0
    @window = Curses::Window.new(@height, @width, @top, @left)
    @window.box("|", "-")
    @sub_windows = []
    setpos(@cursor_x, @cursor_y)
  end

  def default
    {}
  end

  def addstr(str)
    @window.addstr(str)
  end

  def setpos(x, y)
    @window.setpos(x, y)
  end

  def refresh
    @window.refresh
  end

  def getch
    @window.getch
  end

  def close
    @window.close
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

  def insert_sub_window(args)
    height = args.fetch(:height, @height - 4)
    width = args.fetch(:width, @width - 4)
    top = args.fetch(:top, @top + 2)
    left = args.fetch(:left, @left + 2)
    @sub_windows << @window.subwin(height, width, top, left)

    return @sub_windows.last
  end
end

class DisplayBoard < Window
 
  attr_reader :height, :width, :top, :left, :separator

  def initialize(arr, top, left, separator = ", ")
     if arr_depth(arr) == 1
       @height = 1 + 2
       @width = arr.size * (1 + separator.length) + 2
     else
       @height = arr.size + 2
       @width = arr.first.size * (1 + separator.length) + 2
     end

     @top = top
     @left = left
     @cursor_x = 0
     @cursor_y = 0

     @separator = separator
     @window = Curses::Window.new(height, width, top, left)
     @window.box("|", "-")
     @window.setpos(0,0)
     @window.addstr(stringify(arr))
  end

end

def stringify(arr)
  if arr_depth(arr) == 1
    return arr.join(separator)
  else
    str = ""
    arr.each do |row|
      str += "#{row.join(separator)}\n"
    end
      return str
  end
end

def arr_depth(arr)
  return arr.to_a == arr.flatten(1) ? 1 : arr_depth(arr.flatten(1)) + 1
end

def driver
  begin
  Curses.init_screen
  Curses.noecho
  Curses.crmode
  

  win1 = create_window("Window 1", 20, 50, 5, 10)
  win1.insert_sub_window(height: 5, width: 8, top: 12, left: 31)
  win2 = create_window("Window 2", 20, 50, 5, 80)
  win2.insert_sub_window(height: 5, width: 8, top: 12, left: 103)
  win3 = create_window("Window 3", 20, 50, 30, 10)
  win3.insert_sub_window(height: 5, width: 8, top: 37, left: 31)
  win4 = create_window("Window 4", 20, 50, 30, 80)
  win4.insert_sub_window(height: 5, width: 8, top: 37, left: 103)
  Curses.refresh 
  win_arr = [win1, win2, win3, win4]

  x = 0
  loop do
  win = win_arr[x]
  win.refresh
  win.reset_pos 
  allow_move_cursor(win)
  if x + 1 >= win_arr.size
    x = 0
  else
    x += 1
  end
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
  win.refresh
  Curses.refresh
  return win
end

def create_board(arr)

  top = Curses.lines / 4
  left = Curses.cols / 4
  input_arr = []
  win = DisplayBoard.new(arr, top, left, "|")
  win.refresh
  input = ""
  loop_num = 0
  loop do
    loop_num += 1
    input += win.getch.to_s
    input_arr.push("#{loop_num}. '#{input}'")

    case input
  when "j" || "27[A"
    win.up
  when "k" || "27[B"
    win.down
  when "h" || "27[D"
    win.left
  when "l" || "27[C"
    win.right
  when "q"
    break
  when "27" 
    next
  when "27["
    next
  when "27[A"
    win.up
  when "27[B"
    win.down
  when "27[C"
    win.right
  when "27[D"
    win.left
  end
    input = ""
  end
  win.close

  return input_arr
end

 input_hash = { "j" => ->(win) { win.up }, 
                "27[A" => ->(win) { win.up },
                "k" => ->(win) {  win.down },
                "27[B" => ->(win) {  win.down },
                "h" => ->(win) { win.left },
                "27[D" => ->(win) { win.left },
                "l" => ->(win) { win.right },
                "27[C" => ->(win) { win.right },
                "27" => ->(x) { next },         #Unfortunately, can't break out of loop from inside another function
                "27[" => ->(x) { next },
                "q" => ->(x) { break } }


def allow_move_cursor(win) #Get input from window and move cursor based on hjkl or arrow key input
  input = ""
  loop do
    input += win.getch.to_s
    case input
    when "j"
      win.up
    when "k"
      win.down
    when "h"
      win.left
    when "l"
      win.right
    when "q"
      break
    when "10"
      win.sub_windows.last.clear
      win.sub_windows.last.addstr("[#{win.cursor_x}, #{win.cursor_y}]")  
      win.sub_windows.last.refresh
    when "27"  #When getch is \e or \e[, get next char without resetting input
      next     #Unfortunately, don't know how to distinguish between regular escape press and other keys
    when "27["
      next
    when "27[A"
      win.up
    when "27[B"
      win.down
    when "27[C"
      win.right
    when "27[D"
      win.left
    end
      input = ""
  end
  end
  


if __FILE__ == $0

  driver

end
