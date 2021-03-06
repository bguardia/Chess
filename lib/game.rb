#require './lib/chess.rb'

$game_debug = ""

class Game < Saveable

 attr_reader :players, :board 

 def initialize(args = {})
   @players = args.fetch(:players, false) || create_players
   @gamestate = args.fetch(:gamestate, false) || set_gamestate
   @current_player = args.fetch(:current_player, nil)
   @move_history = args.fetch(:move_history, [])
   @turn_num = args.fetch(:turn_num, 1)
   @break_game_loop = false
   set_ui(args)
   initialize_gamestate
 end

 def create_players
   [ Player.new, Player.new ]
 end
 
 def create_sets
   [ Pieces.new_set("white"), Pieces.new_set("black") ]
 end

 def start
   unless @current_player
     @players[0].team = "white"
     @players[1].team = "black"
     @current_player = @players[0]
   end

   #initialize_gamestate 
  
   @input_handler = InputHandler.new(in: @io_stream)
   @players.each do |p|
     p.set_input_handler(@input_handler)
   end
   @turn_num ||= 1

   #load move_history into move_history_input (for loading games)
   if @move_history.length != @move_history_input.length
     @move_history.each_index do |i|
       if @move_history_input.length - 1 >= i
         @move_history_input[i] = @move_history[i]
       else
         @move_history_input << @move_history[i]
       end
     end
   end

   play
 end

 def initialize_gamestate
   #Pieces and Board observe changes in gamestate and update themselves accordingly 
   piece_observer = Observer.new(to_do: ->(state) { Piece.update_pieces(state) })
   board_observer = Observer.new(to_do: ->(state) { @board.update(state) })
   @gamestate.add_observer(piece_observer)
   @gamestate.add_observer(board_observer)
   @gamestate.notify_observers
 end

=begin
 ///////////////////////////////////////////////////////////////
 Public Setter Functions
 \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
=end

 public
 def set_ui(args)
   @io_stream = args.fetch(:io_stream, nil)
   @move_history_input = args.fetch(:move_history_input, nil)
   @turn_display_input = args.fetch(:turn_display_input, nil)
   @board = args.fetch(:board, nil) || Board.new
   @message_input = args.fetch(:message_input, nil)
 end


 def set_gamestate
  pieces = create_sets.flatten
  StateTree.new(pieces: pieces)
 end

=begin
 /////////////////////////////////////////////////////////////////
 Periodic Update Functions/UI Related Functions
 \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
=end

 def update_turn_display(current_player, turn)
   @turn_display_input[0] =  "#{current_player.team.capitalize}'s Turn (#{turn})"
 end

 def update_move_history(move)
   #load move_history into input array if sizes don't match
   if @move_history_input
   if @move_history.length != @move_history_input.length
     @move_history.each_index do |i|
       if @move_history_input.length - 1 >= i
         @move_history_input[i] = @move_history[i]
       else
         @move_history_input << @move_history[i]
       end
     end
   end
   end

   note = ChessNotation.move_to_notation(move, @gamestate)
  
   l = @move_history.length
   if @turn_num == l 
     @move_history[@turn_num - 1] += " #{note}"
     if @move_history_input
       @move_history_input[@turn_num - 1] += " #{note}"
     end
   else
     @move_history << "#{@turn_num} #{note}"
     if @move_history_input
       @move_history_input << "#{@turn_num} #{note}"
     end
   end
 end

 def update_turn_num
   if @current_player.team == "white"
     @turn_num += 1
   end
 end

 def change_current_player
   @current_player = @players.find { |p| p != @current_player }
 end

 def break_game_loop
   @break_game_loop = true
 end

=begin
 //////////////////////////////////////////////////////////
 Main Gameplay Functions
 \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
=end

 def game_over?
   return @gamestate.checkmate?(@current_player.team)
 end

 def play
   game_over = false
   until game_over
     update_turn_display(@current_player, @turn_num)
     @io_stream.update
     player_turn
     break if @break_game_loop
     #$game_debug += "play loop not broken\n"
     change_current_player
     game_over = game_over?
     update_turn_num
   end

   #$game_debug += "Broke out of play loop\n"

   unless @break_game_loop
     @message_input << "Checkmate. #{@current_player.team.capitalize} loses."
     @io_stream.update
     @io_stream.get_input
   else
     #$game_debug += "Broke game loop and closed io_stream\n"
     @io_stream.close
   end
 end


 def player_turn(player = @current_player)
   move = nil

   #Get player's possible moves and validate them
   move_list = @gamestate.get_moves(team: player.team)
   valid_moves = Movement.validate_moves(move_list, @gamestate)
   @gamestate.update_moves(valid_moves)

   #input loop
   loop do
     input = player.get_input(key_map: { 's' => -> { save; @input_handler.break },
                                         'q' => -> { @input_handler.break; break_game_loop }},
                              gamestate: @gamestate)
     break if @break_game_loop
     move = input.kind_of?(Move) ? input : to_move(input)
     valid_move = valid?(move) 
     @io_stream.update
     break if valid_move
   end

   unless @break_game_loop
     @gamestate.do!(move)
     update_move_history(move)
     piece = move.get_piece
     pos = move.destination(piece)
     #$game_debug += "pos: #{pos}, note: #{ChessNotation.pos_notation(pos)}\n"
     @message_input << "#{player.team.capitalize} moves #{piece} to #{ChessNotation.pos_notation(pos)}."
   end
 end

=begin
 ////////////////////////////////////////////////////////////////
 Functions that involve Move Logic (Promotions, Validation, etc.)
 \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
=end

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
   if move.nil?
     move = EmptyMove.new
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

   @message_input << ""
   return true
 end

 def draw

   #dead positions
   #knight + king vs. king
   #
 end

=begin
  //////////////////////////////////////////////////////////////
  Saving and Loading Functions
  \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
=end

 def ignore_on_serialization
   ["@io_stream",
    "@board",
    "@message_input",
    "@move_history_input",
    "@turn_display_input",
    "@break_game_loop"]
 end

 def save
   save_title = "#{@players[0].name} vs. #{@players[1].name}"
   notation = @move_history.reduce([]) do |arr, str| 
     subarr = str.split(' ')
     subarr.shift
     arr.concat(subarr)
   end

   data = { notation: notation,
            players: @players,
            turn_num: @turn_num }  #self.to_json

   board_state = @board.to_s
   SaveHelper.save(title: save_title,
                   data: data,
                   board_state: board_state)
   
   break_game_loop
 end

 def load(save_data)
   @players = save_data.fetch(:players)
   @current_player = @players.find { |p| p.team = "white" }
   notation = save_data.fetch(:notation)
=begin
   piece_observer = Observer.new(to_do: ->(state) { Piece.update_pieces(state) })
   @gamestate.add_observer(piece_observer)
   @gamestate.notify_observers
=end
   notation.each do |note|
     #$game_debug += "note is: #{note}\n"
     move = ChessNotation.from_notation(note, @gamestate)
     #$game_debug += "move is: #{move}\n"
     @gamestate.do!(move)
     #$game_debug += "gamestate updated\n"
     update_move_history(move)
     change_current_player     
     update_turn_num
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

=begin
  /////////////////////////////////////////////////
  Move to Notation Functions
  \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
=end
   #main public interface
   def self.move_to_notation(move, state)
     notation = self.unravel_move(move, state)
   end

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

     #Rewind state to check for any other pieces that could move to the same position
     #If so, add clarifying rank or file
     state.undo
     detail = clarify_notation(pieces.first, dest_pos_arr.first, state)
     state.do!(move)

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

   def self.pos_notation(pos)
     "#{self.to_file(pos)}#{self.to_rank(pos)}"
   end

=begin
  //////////////////////////////////////////////////////
  Notation to Move Functions
  \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
=end

   #main public interface for notation to move translations
   def self.from_notation(note, state)
     #$game_debug += "note before clean: #{note}\n"
     note = clean(note)
     #$game_debug += "note after clean: #{note}\n"
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
       #Remove any pieces of the non-active team
       possible_pieces.select! { |p| p.team == state.get_active_team }
       #If still multiple pieces, check the clarifying detail
       if possible_pieces.length > 1
         possible_pieces.select! do |p|
           current_pos = state.get_pos(p)
           current_pos[0] == dtl[0] || current_pos[1] == dtl[1]
         end
       end
     elsif possible_pieces.length == 0
       return nil
     end
     piece = possible_pieces[0]
     #Return move
     move_hash = { piece: piece, 
                   prev_pos: state.get_pos(piece), 
                   pos: pos, 
                   capture: capture,
                   removed: state.get_piece_at(pos) }
     #$game_debug += "move_hash:\n#{move_hash}\n"
     move = Movement.return_move(state.get_pos(piece), pos, state)[0]
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
       $game_debug += "count of 'abcdefgh' or '0123456789' is >= 2\n"
       f = from_file(note[/([a-h]).*[a-h]/, 1]) || "*"
       r = from_rank(note[/([0-9]).*[0-9]/, 1]) || "*"
       $game_debug += "detail is: f:#{f}, r: #{r}\n"
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

   #return any clarifying notes if piece & move combo are unclear
   #otherwise returns an empty string
   def self.clarify_notation(piece, dest_pos, state)
     $game_debug += "#{piece.team} #{piece.class} #{piece.id}, dest_pos: #{dest_pos}\n"
     #gets set of moved piece
     team = piece.team
     similar_pieces = state.get_pieces(type: piece.class.to_s, team: team)

     $game_debug += "similar_pieces: #{similar_pieces.map { |p| "#{p.team} #{p.class} #{p.id}\n" }}\n"
     #Get all pieces that are same kind as piece
     
     #Select a piece which can do the same move
     other = similar_pieces.find do |p|
       moves = state.get_moves(id: p.id)
       can_reach = moves.find { |mv| mv.destination(p) == dest_pos }
       $game_debug += "For #{p.team} #{p.class} #{p.id}: moves: #{moves.length}, can_reach: #{can_reach}\n"
       p.id != piece.id && can_reach
     end
     
     $game_debug += "other piece: #{other ? other : "nil" }\n"
     #return if no other piece exists
     return "" if other.nil?

     #Return file if rank is same, rank otherwise
     piece_pos = state.get_pos(piece)
     other_pos = state.get_pos(other)
     if other_pos[0] == piece_pos[0]
       f = to_file(piece_pos)
       $game_debug +=" returning #{f}\n"
       f
     else
       r = to_rank(piece_pos)
       $game_debug += " returning #{r}\n"
       r
     end
   end

end

