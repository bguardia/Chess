require './lib/save.rb'
require './lib/game.rb'
require './lib/player.rb'
require './lib/board.rb'
require './lib/movement.rb'
require './lib/piece.rb'
require './lib/window.rb'
#require './lib/chess_notation.rb'

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

  #get_players
  
  board = Board.new
  move_history_input = []
  message_input = []
  turn_display_input = []

  game_screen = WindowTemplates.game_screen(height: height,
                                            width: width,
                                            top: 0,
                                            left: 0,
                                            move_history_input: move_history_input,
                                            message_input: message_input,
                                            turn_display_input: turn_display_input,
                                            board: board)

  game_input_handler = InputHandler.new(in: game_screen)

  player_one = Player.new(input_handler: game_input_handler)
  player_two = Player.new(input_handler: game_input_handler)

  game = Game.new(players: [player_one, player_two],
                  board: board,
                  move_history_input: move_history_input,
                  message_input: message_input,
                  turn_display_input: turn_display_input,
                  io_stream: game_screen)
  game.start
end

def get_players
  
end

def load_save
=begin
  info = "       Load Save       \n" +
         "You have a save to load\n" +
         "So you should load it. \n" 
  if File.exists?("saves.txt")
    save_data = File.read("saves.txt")
    save_obj = Save.from_json(save_data)
  end

  pop_up(info)
=end

 save = File.open("my_save.txt", "r")
 save_data = save.readlines[0]
 save.close
 game = Saveable.from_json(save_data)
 game.play
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

def title_screen
  #Get Chess ascii art from title.txt
  title_file = File.open("title.txt")
  title_image = title_file.readlines 
  title_file.close

  title_image << "v1.0"
  title_image << "By Blair Guardia"

  padding = 2
  height = title_image.length + padding * 2
  width = title_image[0].length + padding * 2
  top = 3
  left = (Curses.cols - width - padding * 2) / 2
  Window.new(height: height,
             width: width,
             content: title_image,
             padding: padding,
             top: 3,
             left: left) 
end

if __FILE__ == $0
begin
  Curses.init_screen
  Curses.start_color

  h = Curses.lines
  w = Curses.cols
  screen = InteractiveScreen.new(height: h, width: w, top: 0, left: 0, fg: :white, bg: :red, bkgd: " ")

  
  #screen.set_bg(:white, :red, "A")
  screen.add_region(title_screen)
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
  puts $board_debug
  #puts $pieces_debug
  #puts $movement_debug
  #puts $chess_debug
end

end
