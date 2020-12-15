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

  win = CursesWrapper.new_window(height: h,
                                 width:  w,
                                 top: t,
                                 left: l,
                                 border_top: "-",
                                 border_side: "|")

  win.setpos(padding, padding)
  win.addstr(str)
  input = win.getch
  win.erase
  Curses.refresh
  return input
end

def start_game
  game_screen = InteractiveScreen.new(height: 40, width: 80, top: 0, left: 0)
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
  options = [["Start game", ->{start_game}],
             ["Load save", ->{load_save}],
             ["Quit game", ->{quit_game}],
             ["About the game", ->{about_game}]]

  Menu.new(height: h,
           width: w,
           top: t,
           left: l,
           options: options,
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
