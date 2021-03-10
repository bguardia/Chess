require './lib/save.rb'
require './lib/game.rb'
require './lib/player.rb'
require './lib/board.rb'
require './lib/movement.rb'
require './lib/piece.rb'
require './lib/window.rb'
#require './lib/chess_notation.rb'

$chess_debug = ""

#Load and save settings that can be changed by user
module Settings

  @@file_loc = "settings.txt"
 
  @@vars = {}

  def self.default_vars
    { "bkgd_color" => "black",
      "board_color" => "b_magenta" }
  end

  def self.possible_vars
    { "bkgd_color" => ["black", "red", "green", "yellow", "blue"],
      "board_color" => ["red", "b_yellow", "green", "b_blue", "b_magenta", "b_cyan"] }
  end

  def self.load
    f = File.open(@@file_loc, "r")
    json_str = f.read
    f.close
    $game_debug += "json_str is #{json_str}\n"
    @@vars = self.default_vars.merge(JSON.load(json_str))
    var_class = @@vars.class
    $game_debug += "@@vars is: #{@@vars}\n@@vars is a #{var_class}\n"
    
  end

  def self.get(key)
    @@vars[key]
  end

  def self.all
    @@vars
  end

  def self.update(settings)
    @@vars.merge!(settings)
  end

  def self.save
    f = File.open(@@file_loc, "w")
    f.puts JSON.dump(@@vars)
    f.close
  end
end

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
  #game_input_handler = InputHandler.new(in: game_screen)

  player_one = Player.new #(input_handler: game_input_handler)
  player_two = Player.new #(input_handler: game_input_handler)

  game = Game.new(players: [player_one, player_two])
  init_game_ui(game, board_color: Settings.get("board_color").to_sym)
  game.start
end

def init_game_ui(game, args = {})
  height = Curses.lines 
  width = Curses.cols
  top = 0 
  left = 0 

  board = Board.new
  board_color = args.fetch(:board_color, nil) || :b_magenta
  move_history_input = []
  message_input = []
  turn_display_input = []

  title = "#{game.players[0].name} vs. #{game.players[1].name}"
  game_screen = WindowTemplates.game_screen(height: height,
                                            width: width,
                                            top: 0,
                                            left: 0,
                                            title: title,
                                            move_history_input: move_history_input,
                                            message_input: message_input,
                                            turn_display_input: turn_display_input,
                                            board: board,
                                            board_color: board_color)


  game.set_ui(board: board,
              move_history_input: move_history_input,
              message_input: message_input,
              turn_display_input: turn_display_input,
              io_stream: game_screen)

end

def get_players
  
end

def load_save
 SaveHelper.load_saves
 actions = []
 content = []
 SaveHelper.saves.each do |save|
   content << save.to_s
   actions << -> { init_game_ui(save.data); save.data.start }
 end

 load_menu = WindowTemplates.menu_two(height:35,
                                      width: 55,
                                      top: 5,
                                      left: 5,
                                      lines: 3,
                                      item_padding: 1,
                                      content: content,
                                      actions: actions,
                                      title: "Load Save")

 load_menu.update
 InputHandler.new(in: load_menu).get_input

end

def quit_game
  h = 15
  w = 30
  t = ( Curses.lines - h ) / 2
  l = ( Curses.cols - w ) / 2

  title = "Quit Game"
  content = "Are you sure you'd like to quit the game?"
  buttons = [["Yes", ->{ exit }], ["No", nil]]

  quit_confirm = WindowTemplates.confirmation_screen(height: 15,
                                      width: 30,
                                      top: t,
                                      left: l,
                                      padding: 2,
                                      title: title,
                                      content: content,
                                      buttons: buttons)
  quit_confirm.update
  InputHandler.new(in: quit_confirm).get_input
end

def about_game
  info = " You want to learn about\n" +
         "This amazing game and th\n" +
         "amazing person that made\n" +
         "it. Great!              \n"

  pop_up(info)
end

def settings
 current_settings = Settings.all
 possible_settings = Settings.possible_vars
 
 settings_hash = {}
 current_settings.each_key do |key|
   settings_hash[key] = { :active => current_settings[key],
                          :options => possible_settings[key] }
 end

 h = 25
 w = 35
 t = (Curses.lines - h) / 2
 l = (Curses.cols - w) / 2
 settings_menu = WindowTemplates.settings_menu(height: h,
                                               width: w,
                                               top: t,
                                               left: l,
                                               settings: settings_hash) 
 settings_menu.update
 new_settings = InputHandler.new(in: settings_menu).get_input
 Settings.update(new_settings)
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
             "About the game",
             "Settings"]

  actions = [-> {start_game},
             -> {load_save},
             -> {quit_game},
             -> {about_game},
             -> {settings}]

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

  Settings.load

  bkgd_color = Settings.get("bkgd_color").to_sym
  $game_debug += "bkgd_color is: #{bkgd_color}\n"
  screen = InteractiveScreen.new(height: h, width: w, top: 0, left: 0, fg: :white, bg: bkgd_color, bkgd: " ")

  
  screen.add_region(title_screen)
  screen.add_region(start_menu)
  screen.update
  input_handler = InputHandler.new(in: screen)

  loop do
    input_handler.get_input
    screen.update
  end
ensure
  Settings.save
  Curses.close_screen
  puts $game_debug
  #puts $window_debug
  #puts $board_debug
  #puts $pieces_debug
  #puts $movement_debug
  #puts $chess_debug
end

end
