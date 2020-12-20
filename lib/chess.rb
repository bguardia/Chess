require './lib/game.rb'
require './lib/player.rb'
require './lib/board.rb'
require './lib/movement.rb'
require './lib/piece.rb'
require './lib/window.rb'
require './lib/chess_notation.rb'

$chess_debug = ""

def pop_up(str)
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

def start_game
  height = Curses.lines 
  width = Curses.cols
  top = 0 
  left = 0 
  game_screen = InteractiveScreen.new(height: height, width: width, top: top, left: left)
  game_input_handler = InputHandler.new(in: game_screen)
  board = Board.new
  board_map = get_board_map(board)
  game_screen.add_region(board_map)
  player_one = Player.new(input_handler: game_input_handler)
  player_two = Player.new(input_handler: game_input_handler)

  game = Game.new(players: [player_one, player_two],
                  board: board,
                  io: game_screen)
  game.start
end

def load_save
  info = "       Load Save       \n" +
         "You have a save to load\n" +
         "So you should load it. \n" 

  pop_up(info)
end

def quit_game
  info =  " You are about to Quit! \n" +
          "Are you sure that you wa\n" +
          "nt to quit? [y/n]       \n" 

  input = pop_up(info)

  if input == "y" || input == "Y"
    exit
  end
end

def about_game
  info = " You want to learn about\n" +
         "This amazing game and th\n" +
         "amazing person that made\n" +
         "it. Great!              \n"

  pop_up(info)
end

def settings
  info = "You want to change game\n" +
         "settings? What, the ori\n" +
         "ginal settings weren't \n" +
         "good enough?           \n"

  pop_up(info)
end

def start_menu
  p = 2
  h = 15 + p * 2
  w = 40 + p * 2
  t = (Curses.lines - h) / 2
  l = (Curses.cols - w) / 2
  content = ["Start game",
             "Load save",
             "Quit game",
             "About the game"]

  actions = [-> {start_game},
             -> {load_save},
             -> {quit_game},
             -> {about_game}]
  Menu.new(height: h,
           width: w,
           padding: p,
           centered: true, 
           content: content,
           actions: actions,
           col1: [:white, :black],
           col2: [:white, :cyan],
           border_top: "-",
           border_side: "|")
end

if __FILE__ == $0
begin
  Curses.init_screen
  Curses.start_color

  h = Curses.lines
  w = Curses.cols
  screen = InteractiveScreen.new(height: h, width: w, top: 0, left: 0, fg: :white, bg: :red, bkgd: " ")
  
  #screen.set_bg(:white, :red, "A")
  screen.add_region(start_menu)
  screen.update
  input_handler = InputHandler.new(in: screen)

  loop do
    input_handler.get_input
    screen.update
  end
ensure
  Curses.close_screen
  puts $game_debug
  #puts $window_debug
  #puts $board_debug
  puts $pieces_debug
  #puts $movement_debug
  #puts $chess_debug
end

end
