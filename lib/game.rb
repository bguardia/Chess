require './lib/piece.rb'
require './lib/player.rb'
require 'json'

$game_debug = ""

class Game

 attr_reader :players, :board, :sets

 def initialize(args = {})
   @players = args.fetch(:players, false) || create_players
   @sets = args.fetch(:sets, false) || create_sets
   @board = args.fetch(:board, false) || Board.new 
   @current_player = nil
   @io_stream = args.fetch(:io)
   $game_debug += "Game initialized with the following variables:\n" +
                  "@players: #{@players}\n@sets: #{@sets}\n@board:\n" +
                  "#{@board}\n"
 end

 def create_players
   [ Player.new, Player.new ]
 end

 def create_sets
   [ Pieces.new_set("white"), Pieces.new_set("black") ]
 end

 def set_up_board
   @sets.each do |set|
     set.each do |piece|
       piece.add_to_board(@board)
     end
   end
   board.update_gamestate
 end

 def set_up_messenger
   @msg_arr = []
   @messenger = List.new(height: 3, width: 30, content: @msg_arr, top: 5, left: 5, lines: 1)
   @io_stream.add_region(@messenger)
 end

 def set_up_move_history
   @move_history_arr = []
   @move_history = List.new(height: 30, 
                            width: 10, 
                            content: @move_history_arr,
                            top: 10,
                            left: 5,
                            lines: 15) 
   @io_stream.add_region(@move_history)
 end

 def update_move_history(move)
   l = @move_history_arr.length
   if @turn_num == l 
     @move_history_arr[@turn_num - 1] += " #{move}"
   else
     @move_history_arr << "#{@turn_num} #{move}"
   end
 end

 def to_json
   JSON.dump({ :players => @players.map(&:to_json),
                   :sets => @sets.map { |set| set.map(&:to_json) },
                   :board => @board })
 end

 def game_over?
     $game_debug += "game_over?: @current_player.team: #{@current_player.team}\n"
     king = @board.get_pieces(type: "King", team: @current_player.team)[0]
     $game_debug += "game_over?: king is #{king}\n"
     $game_debug += "board is:\n #{@board.to_s}"
     return Movement.checkmate?(king, @board)
 end

 def start
   set_up_board
   set_up_messenger
   set_up_move_history
   @players[0].team = "white"
   @players[1].team = "black"
   @current_player = @players[0]

   @turn_num = 1
   play
 end

 def play
   game_over = false

   until game_over
     @io_stream.update
     player_turn
     change_current_player
     game_over = game_over?
     if @current_player.team == "white"
       @turn_num += 1
     end
   end

   @msg_arr << "Checkmate. #{@current_player.team.capitalize} loses."
   @io_stream.update
   @io_stream.get_input
 end

 def change_current_player
   @current_player = @players.find { |p| p != @current_player }
 end

 def player_turn(player = @current_player)
   move = nil

   loop do
       $game_debug += "player_turn loop: @msg_arr[0] is: #{@msg_arr[0]}\n"
       input = player.get_input({})
       move = Move.new(board, input)
       valid_move = valid?(move)
       @messenger.update
       break if valid_move
   end

   move.do(@board)
   update_move_history(move.notation)
 end

 def valid?(move)
   unless move.legible
     @msg_arr << "Couldn't read move."
     return false
   end

   piece = move.piece
   pos = move.pos
   removed = move.removed
   

   unless piece.team == @current_player.team
     @msg_arr << "You can only move pieces on your team (#{@current_player.team})."
     return false
   end

   #Must be a possible move of the piece
   unless piece.possible_moves(board).include?(pos)
     @msg_arr << "#{piece.to_s} cannot move there."
     return false
   end

   #Must not move to a square occupied by a friendly piece
   if removed && piece.team == removed.team
     @msg_arr << "Destination is occupied by a friendly piece."
     return false
   end

   #King must not be in check after move
   sim_board = @board.copy
   sim_king = sim_board.get_pieces(type: "King", team: piece.team)[0]
   sim_prev_pos = board.get_coords(piece)
   sim_move = Move.simulate(sim_board, sim_prev_pos, pos)
   sim_move.do(sim_board)
   check_after_move = Movement.in_check?(sim_king, sim_board)
   if check_after_move
     @msg_arr << "Move puts king in check."
     return false
   end

   @msg_arr << ""
   return true
 end

 def draw

   #dead positions
   #knight + king vs. king
   #
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

class Move
  attr_reader :piece, :prev_pos, :pos, :removed, :castle, :promotion, :notation, :legible
  
  def initialize(board, args)
    $game_debug += "Move.new called. args are: #{args}\n"
    @board = board
  
    if args.kind_of?(String)
      @notation = args
      args = get_from_notation(@notation, @board)
    else
      args = get_from_array(args, @board)
    end

    unless args.fetch(:piece) && args.fetch(:pos)
      @legible = false      
    else
      @legible = true
      initialize_vars(args)
    end

=begin
    $game_debug += "Move initialized with following variables:\n" +
                   "@piece: #{@piece}\n@prev_pos: #{@prev_pos}\n@pos: #{@pos}\n" +
                   "@removed: #{@removed}\n@castle: #{@castle}\n@promotion: #{@promotion}\n"
=end  
  end

  def initialize_vars(args)
    @piece = args.fetch(:piece)
    @prev_pos = args.fetch(:prev_pos)
    @pos = args.fetch(:pos)
    @removed = args.fetch(:removed, nil)
    @castle = args.fetch(:castle, false)
    @promotion = args.fetch(:promotion, false)
    @notation ||= ChessNotation.to_notation(@prev_pos, @pos, @board)
  end

  def get_from_notation(note, board)
    ChessNotation.from_notation(note, board)
  end

  def get_notation(prev_pos, pos, board)
    ChessNotation.get_notation(prev_pos, pos, board)
  end

  def get_from_array(pos_arr, board)
    $game_debug += "called Move.get_from_array(#{pos_arr}, board)\n"
    ChessNotation.translate_move(pos_arr[0], pos_arr[1], board)
  end

  def self.simulate(board, prev_pos, pos)
    Move.new(board, [prev_pos, pos])
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

  def do(board)
    board.move(@piece, @pos)
    if @castle
      board.move(@castle[:piece], @castle[:pos]) 
    end
  end
end

module ChessNotation

   @@rank = [8, 7, 6, 5, 4, 3, 2, 1]
   @@file = ("a".."h").to_a
   @@pieces = {  "Pawn" => "",
                 "Knight" => "N",
                 "Bishop" => "B",
                 "Queen" => "Q",
                 "King" => "K",
                 "Rook" => "R" }

   def self.translate_move(prev_pos, new_pos, board)
     piece = board.get_piece_at(prev_pos)
     new_pos_piece = board.get_piece_at(new_pos)

     #check for castle
     if piece.kind_of?(King) && (prev_pos[1] - new_pos[1]).abs > 1
       queenside = new_pos[1] == 3
       r = new_pos[0]
       rook_prev_pos = queenside ? [r, 0] : [r, 7]
       rook_pos = queenside ? [new_pos[0], (new_pos[1] + 1)] : [new_pos[0], (new_pos[1] - 1)]
       rook = board.get_piece_at(rook_prev_pos)
       castle = { piece: rook, prev_pos: rook_prev_pos, pos: rook_pos }
     else
       castle = false
     end


     promotion = nil

     move_hash = { piece: piece,
                   prev_pos: prev_pos,
                   pos: new_pos,
                   removed: new_pos_piece,
                   castle: castle,
                   promotion: promotion } 
    
     return move_hash 
   end

   #public interface from game move to chess notation
   def self.to_notation(prev_pos, new_pos, board)
     piece = board.get_piece_at(prev_pos)
     new_pos_piece = board.get_piece_at(new_pos)

     #check for castle
     if piece.kind_of?(King) && (prev_pos[1] - new_pos[1]).abs > 1
       return castle_notation(piece, prev_pos, new_pos)
     end
    
     #check for piece capture
     if new_pos_piece && new_pos_piece.team != piece.team
       cap_char = "x"
     else
       cap_char = ""
     end
    
     #get clarifying detail if necessary
     extra = clarify_notation(piece, new_pos, board)
     
     #notation string
     to_piece_char(piece) + extra + cap_char + to_file(new_pos) + to_rank(new_pos).to_s
   end

   #create castle notation
   def self.castle_notation(piece, prev_pos, new_pos)
     if new_pos[1] < prev_pos[1] #queenside
       "O-O-O"
     else
       "O-O"
     end 
   end

   #take castle notation and render it into moves and pieces
   def self.from_castle_notation(note)
     move_hash = { :king => { :current_pos => [0,0],
                              :move => [0,0] },
                   :rook => { :current_pos => [0,0],
                              :move => [0,0] } }
     
     #with only one notation, function can't tell which team
     #king/rook are on.
     #another function can replace with a real value
     if note == "O-O-O" #queenside
       move_hash[:king][:move] = ["*", 2]
       move_hash[:rook][:current_pos] = ["*", 0]
       move_hash[:rook][:move] = ["*", 3]
     elsif note == "O-O" #kingside
       move_hash[:king][:move] = ["*", 7]
       move_hash[:rook][:current_pos] = ["*", 8]
       move_hash[:rook][:move] = ["*", 6]
     end

     return move_hash
   end

   #small parts of to_notation function
   def self.to_piece_char(piece)
     @@pieces[piece.class.to_s]
   end

   def self.to_rank(move)
     @@rank[move[0]].to_s
   end

   def self.from_rank(rank)
     @@rank.index(rank.to_i)
   end

   def self.from_file(file)
     @@file.index(file)
   end

   def self.to_file(move)
     @@file[move[1]]
   end

   #break down an individual note into its components
   def self.decomp_note(note)
     note_hash = {}
     
     #gets piece
     if @@pieces.values.include?(note[0])
       note_hash[:piece] = @@pieces.key(note[/[[:upper:]]/])
     else
       note_hash[:piece] = @@pieces.key("") #pawn
     end 
     
     pos = note[/[[:lower:]][0-9]/]
     note_hash[:rank] = pos[1] #get rank
     note_hash[:file] = pos[0] #get file
     
     #if note has two lowercase letters or two numbers, it contains a clarifying value
     if note.count("abcdefgh") >= 2 || note.count("123456789") >= 2
       f = from_file(note[/([a-h]).*[a-h]/, 1]) || "*"
       r = from_rank(note[/([0-9]).*[0-9]/, 1]) || "*"
       note_hash[:detail] = [ r , f ]
     end

     note_hash[:capture] = note.include?("x") #get capture bool
     
     return note_hash
   end

   def self.clean(note)
     note_patt = /[[:upper:]]?([a-h]|[0-9])?x?[a-h][0-9]/
     castle_patt = /0-0(-0)?/
     
     note.match(note_patt) { |m| return m[0] }   #block only activates if match is found
     note.match(castle_patt) { |m| return m[0] } #preventing error of calling [0] on nil
     return nil
   end

   #a function to derive a position even if either the rank or file is nil
   def self.get_pos(rank, file, dtl, capture)
     if rank
       r = from_rank(r)
     else
     end


     if file
       f = from_file(f)
     else
     end
   end

   def self.from_notation(note, board)
     note = clean(note)
     return nil if note.nil?

     #If castle notation, run separate function
     return from_castle_notation(note) if note.start_with?("O-O")

     #break down note into individual pieces
     note_hash = decomp_note(note)
     p = note_hash[:piece]
     dtl = note_hash[:detail]
     capture = note_hash[:capture]
     r = note_hash[:rank]
     f = note_hash[:file]
     
     pos = [from_rank(r), from_file(f)]

     #Get pieces of the same type who can reach the position
     possible_pieces = Movement.who_can_reach?(pos, board, type: p)
     if possible_pieces.length > 1
       piece = possible_pieces.find do |p|
         current_pos = board.get_coords(p)
         current_pos[0] == dtl[0] || current_pos[1] == dtl[1]
       end
     elsif possible_pieces.length == 0
       return nil
     else
       piece = possible_pieces[0]
     end

     #Return move
     move_hash = { piece: piece, 
                   prev_pos: board.get_coords(piece), 
                   pos: pos, 
                   capture: capture,
                   removed: board.get_piece_at(pos) }
   end

   #return any clarifying notes if piece & move combo are unclear
   #otherwise returns an empty string
   def self.clarify_notation(piece, move, board)
     #gets set of moved piece
     team = piece.team
     similar_pieces = board.get_pieces(type: piece.class.to_s, team: team)
     #Get all pieces that are same kind as piece
     
     #Select a piece which can do the same move
     other = similar_pieces.find do |p|
       p.object_id != piece.object_id && p.possible_moves.include?(move)
     end

     #return if no other piece exists
     return "" if other.nil?

     #Return file if rank is same, rank otherwise
     this_pos = board.get_coords(piece)
     other_pos = board.get_coords(piece)
     if other_pos[0] == piece_pos[0]
       to_file(piece_pos)
     else
       to_rank(piece_pos)
     end
   end

end

