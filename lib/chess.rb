require './lib/game.rb'
require './lib/player.rb'
require './lib/board.rb'
require './lib/piece.rb'
require './lib/window.rb'
require './lib/chess_notation.rb'



def pop_up(str)
  padding = 2
  h = str.split("\n").length + padding * 2
  w = str.index("\n") + padding * 2
  t = Curses.lines / 2
  l = Curses.cols / 2

  win = Window.new(height: h,
                   width:  w,
                   top: t,
                   left: l,
                   border_top: "-",
                   border_side: "|")

  win.addstr(str)
  input = win.get_input
  win.close
  Curses.refresh
  return input
end

def start_game
  height = 40 + 2 < Curses.lines ? 40 : 30 
  width = 80 + 2 < Curses.cols ? 80 : 60
  padding = 2
  top = (Curses.lines - height) / 2
  left = (Curses.cols - width) / 2
  game_screen = InteractiveScreen.new(height: height, width: width, top: top, left: left, padding: padding)
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
  h = 15
  w = 40
  t = Curses.lines / 2
  l = Curses.cols / 2
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
           top: t,
           left: l,
           content: content,
           actions: actions,
           col1: [:white, :black],
           col2: [:white, :cyan])
end

if __FILE__ == $0
begin
  Curses.init_screen
  Curses.start_color

  screen = InteractiveScreen.new(height: 40, width: 80, top: 0, left: 0)
  screen.add_region(start_menu)
 
  input_handler = InputHandler.new(in: screen)

  loop do
    input_handler.get_input
  end
ensure
  Curses.close_screen
  puts $game_debug
  puts $window_debug
end

end
