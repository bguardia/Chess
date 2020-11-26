$: << "."
require 'chess'
require 'piece'
require 'player'
require 'json'

class Move

  def initialize(args)
    @piece = args.fetch(:piece)
    @prev_pos = args.fetch(:prev_pos)
    @new_pos = args.fetch(:pos)
    @removed = args.fetch(:removed, nil)
  end

  def set_removed(removed)
    @removed = removed
  end

  def get_removed
    @removed
  end

  def get_move
    { piece: @piece,
      pos: @new_pos } 
  end

  def reverse_move
    { piece: @piece,
      pos: @prev_pos }
  end
end

class Game

 attr_reader :players, :board, :sets

 def initialize(args = {})
   @players = args.fetch(:players, false) || create_players
   @sets = args.fetch(:sets, false) || create_sets
   @board = Board.new
 end

 def create_players
   [ Player.new, Player.new ]
 end

 def create_sets
   [ Pieces.new_set("white"), Pieces.new_set("black") ]
 end

 def to_json
   JSON.dump({ :players => @players.map(&:to_json),
                   :sets => @sets.map { |set| set.map(&:to_json) },
                   :board => @board })
 end

 def game_over?
   @players.each do |player|
     king = @board.get_pieces(type: "King", team: player.team)
     return true if Movement.checkmate?(king, @board)
   end
 end

 def draw

 end

 def self.from_json(json_str)

   data = JSON.load json_str

   data["players"].map! do |player_str|
     Player.from_json(player_str)
   end

   data["sets"].map! do |set|
     set.map! do |piece_str|
       Piece.from_json(piece_str)
     end
   end

   data.transform_keys!(&:to_sym)

   Game.new(data)
 end

 def save
   f = File.new('save.txt', 'a')
   f.puts to_json
   f.close 
 end

 def self.load(saved_game); end
end
