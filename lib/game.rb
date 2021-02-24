#require './lib/chess.rb'

$game_debug = ""

class Game < Saveable

 attr_reader :players, :board, :sets 

 def initialize(args = {})
   @players = args.fetch(:players, false) || create_players
   @sets = args.fetch(:sets, false) || create_sets

   #Serve as connections with UI for easy updating
   @io_stream = args.fetch(:io)
   @board = args.fetch(:board, false) || Board.new 
   @message_input = args.fetch(:message_input)
   @move_history_input = args.fetch(:move_history_input)
   @turn_display_input = args.fetch(:turn_display_input)
   
   @gamestate = args.fetch(:gamestate, false) || set_gamestate
   @current_player = args.fetch(:current_player, nil)
 end

 def create_players
   [ Player.new, Player.new ]
 end

 def create_sets
   [ Pieces.new_set("white"), Pieces.new_set("black") ]
 end

 def set_gamestate
  pieces = @sets.flatten
  $game_debug += "called set_gamestate\n"
  $game_debug += "pieces: \n#{pieces}"
  StateTree.new(pieces: pieces)
 end

 def update_turn_display(current_player, turn)
   @turn_display_input[0] =  "#{current_player.team.capitalize}'s Turn (#{turn})"
 end

 def update_move_history(move)
   note = ChessNotation.move_to_notation(move, @gamestate)
   l = @move_history_input.length
   if @turn_num == l 
     @move_history_input[@turn_num - 1] += " #{note}"
   else
     @move_history_input << "#{@turn_num} #{note}"
   end
 end

 def game_over?
   $game_debug += "Called game_over? \n"
   return @gamestate.checkmate?(@current_player.team)
 end

 def start
   @players[0].team = "white"
   @players[1].team = "black"
   @current_player = @players[0]
  
   #Pieces and Board observe changes in gamestate and update themselves accordingly 
   piece_observer = Observer.new(to_do: ->(state) { Piece.update_pieces(state) })
   board_observer = Observer.new(to_do: ->(state) { @board.update(state) })
   @gamestate.add_observer(piece_observer)
   @gamestate.add_observer(board_observer)
   @gamestate.notify_observers

   @turn_num = 1
   play
 end

 def play
   game_over = false
   until game_over
     update_turn_display(@current_player, @turn_num)
     @io_stream.update
     player_turn
     change_current_player
     game_over = game_over?
     if @current_player.team == "white"
       @turn_num += 1
     end
   end

   @message_input << "Checkmate. #{@current_player.team.capitalize} loses."
   @io_stream.update
   @io_stream.get_input
 end

 def change_current_player
   @current_player = @players.find { |p| p != @current_player }
 end

 def player_turn(player = @current_player)
   move = nil

   #Get player's possible moves and validate them
   move_list = @gamestate.get_moves(team: player.team)
   valid_moves = Movement.validate_moves(move_list, @gamestate)
   @gamestate.update_moves(valid_moves)

   #input loop
   loop do
     input = player.get_input({ 's' => -> { save }})
     move = to_move(input)
     valid_move = valid?(move)
     @io_stream.update
     break if valid_move
   end

   @gamestate.do!(move)
   update_move_history(move)
 end

 def highlight_moves(piece, win)
   return nil unless piece
   piece.possible_moves.map do |mv|
     pos = mv.destination(something)
     win.highlight_cell(pos)
   end
   win.highlight_cell(piece.current_pos)
 end

 def handle_promotion(moves)
   temp_board = Board.new
   pop_up_board = get_board_map(temp_board)
   input_handler = InputHandler.new(in: pop_up_board) 

   #place pieces on temporary board
   i = 0
   moves.each do |mv|
     p = mv.promoted_to
     pos = [4, 2 + i]
     temp_board.place(p, pos)
     i += 1
   end 

   piece = nil
   pop_up_board.update

   #get input from input_handler until a valid piece is selected
   loop do
     #Bypass normal board behavior by supplying optional key map
     input = input_handler.get_input( { Keys::ENTER => -> {
                                      input_handler.request([pop_up_board.pos_y, pop_up_board.pos_x])
                                      input_handler.break}} )
        
     piece_pos = input
     piece = temp_board.get_piece_at(piece_pos) 
     break if piece
   end
   pop_up_board.close

   return piece
 end

 def to_move(input)
   move = nil
   if input.kind_of?(String)
     move = ChessNotation.from_notation(input, @gamestate)
   else
     piece_pos = input[0]
     dest_pos = input[1]
     moves = Movement.return_move(piece_pos, dest_pos, @gamestate)
     if moves.length > 1 && moves[0].type == :promotion
       piece = handle_promotion(moves)
       move = moves.find { |mv| mv.promoted_to == piece }
     else
       move = moves.first
     end
   end

   return move
 end
 
 def valid?(move)
   piece = move.get_piece
   
   unless piece
     @message_input << "Not a valid move"
     return false
   end

   pos = move.destination(piece)
   removed = @gamestate.get_piece_at(pos)

   unless piece.team == @current_player.team
     @message_input << "You can only move pieces on your team (#{@current_player.team})."
     return false
   end

   #Must be a possible move of the piece

   unless piece.can_reach?(pos)
     @message_input << "#{piece.to_s} cannot move there."
     return false
   end

   #Must not move to a square occupied by a friendly piece
   if removed && piece.team == removed.team
     @message_input << "Destination is occupied by a friendly piece."
     return false
   end

   @message_input << ""
   return true
 end

 def draw

   #dead positions
   #knight + king vs. king
   #
 end

=begin
 def self.to_json
   sets = @sets.map do |set|
     set.map(&:to_json)
   end

   players = @players.map { |player| player.to_json }

   JSON.dump({ "gamestate" => @gamestate.to_json,
               "sets" => sets,
               "players" => players,
               "move_history_input" => @move_history_input #to restore record of previous moves when loaded
               }) 
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

   data["gamestate"] = Statetree.from_json(data["gamestate"])
   data.transform_keys!(&:to_sym)

   Game.new(data)
 end
=end

 def save
   f = File.new('my_save.txt', 'a')
   f.puts to_json
   f.close 
   exit
 end

 def self.load(saved_game); end
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

   def self.unravel_move(move, state)
    pieces = []
    prev_pos_arr = []
    dest_pos_arr = []
    move.each do |piece, prev_pos, current_pos|
      pieces << piece
      prev_pos_arr << prev_pos
      dest_pos_arr << current_pos
    end

    en_passant = ""
    capture = ""
    promotion = ""
    move_type = move.get_attr(:type)
    if move_type == :en_passant
      en_passant = "e.p."
      capture = "x"
    elsif move_type == :castle
      return castle_notation(pieces.first, prev_pos_arr.first, dest_pos_arr.first)
    elsif move_type == :promotion
      promoted_to = move.promoted_to
      promotion = "=#{@@pieces[promoted_to.class.to_s]}"
    end
     
     if pieces.length > 1 && dest_pos_arr.last == nil 
         capture = "x"
     end

     detail = clarify_notation(pieces.first, dest_pos_arr.first, state)

     #check for check/checkmate 
     check = ""
     enemy_team = ["white", "black"].find { |t| t != pieces.first.team }
     if state.in_check?(team: enemy_team)
       check = "+"
       if state.checkmate?(enemy_team)
         check = "#"
       end
     end

     dest_pos = dest_pos_arr.first
     space_str = to_file(dest_pos) + to_rank(dest_pos).to_s
     to_piece_char(pieces.first) + detail + capture + space_str + promotion + en_passant + check 

   end

   def self.move_to_notation(move, state)
     notation = self.unravel_move(move, state)
   end

   #public interface from game move to chess notation
   def self.to_notation(prev_pos, new_pos, state)
     piece = state.get_piece_at(prev_pos)
     new_pos_piece = state.get_piece_at(new_pos)

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
     extra = clarify_notation(piece, new_pos, state)
     
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

   def self.from_notation(note, state)
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
     possible_pieces = Movement.who_can_reach?(pos, state, type: p)
     if possible_pieces.length > 1
       piece = possible_pieces.find do |p|
         current_pos = state.get_pos(p)
         current_pos[0] == dtl[0] || current_pos[1] == dtl[1]
       end
     elsif possible_pieces.length == 0
       return nil
     else
       piece = possible_pieces[0]
     end

     #Return move
     move_hash = { piece: piece, 
                   prev_pos: state.get_pos(piece), 
                   pos: pos, 
                   capture: capture,
                   removed: board.get_piece_at(pos) }
   end

   #return any clarifying notes if piece & move combo are unclear
   #otherwise returns an empty string
   def self.clarify_notation(piece, move, state)
     #gets set of moved piece
     team = piece.team
     similar_pieces = state.get_pieces(type: piece.class.to_s, team: team)
     #Get all pieces that are same kind as piece
     
     #Select a piece which can do the same move
     other = similar_pieces.find do |p|
       p.id != piece.id && p.can_reach?(move)
     end

     #return if no other piece exists
     return "" if other.nil?

     #Return file if rank is same, rank otherwise
     piece_pos = state.get_pos(piece)
     other_pos = state.get_pos(piece)
     if other_pos[0] == piece_pos[0]
       to_file(piece_pos)
     else
       to_rank(piece_pos)
     end
   end

end

