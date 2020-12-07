require 'chess'

module ChessNotation

   @@rank = [8, 7, 6, 5, 4, 3, 2, 1]
   @@file = ("a".."h").to_a
   @@pieces = {  "Pawn" => "",
                 "Knight" => "N",
                 "Bishop" => "B",
                 "Queen" => "Q",
                 "King" => "K",
                 "Rook" => "R" }

   #public interface from game move to chess notation
   def self.to_notation(args)
     piece = args[:piece]
     move = args[:move]
     game = args[:game]
     
     return castle_notation(piece, move) if args.fetch(:castle, false)

     cap_char = args.fetch(:capture, false) ? "x" : ""
     extra = clarify_notation(piece, move, game)
     
     #notation string
     to_piece_char(piece) + cap_char + to_file(move) + to_rank(move)
   end

   #create castle notation
   def self.castle_notation(piece, move)
     if move[1] < piece.current_pos[1] #queenside
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
     @@rank[move[0]]
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
     
     #Doesn't work if there are exclamation points, pluses or octothorpes
     note_hash[:rank] = note[-1] #get rank
     note_hash[:file] = note[-2] #get file
     
     #if note has two lowercase letters or two numbers, it contains a clarifying value
     if note.count("abcdefgh") >= 2 || note.count("12345678") >= 2
       note_hash[:detail] = [ from_file(note[/([0-9]).*[0-9]/,1]) , "*"] || ["*", from_rank(note[/[[:lower:]]/])]
     end

     note_hash[:capture] = note.include?("x") #get capture bool
     
     return note_hash
   end

   def self.notation_to_move(note)
     #If castle notation, run separate function
     return from_castle_notation(note) if note.start_with?("O-O")

     #break down note into individual pieces
     note_hash = decomp_note(note)
     p = note_hash[:piece]
     dtl = note_hash[:detail]
     capt = note_hash[:capture]
     r = note_hash[:rank]
     f = note_hash[:file]

     #return movement hash
     move_hash = { :piece => p,
                   :detail => dtl, #rank or file
                   :move => [from_rank(r), from_file(f)],
                   :capture => capt,
                   :castle => false }
   end

   #return any clarifying notes if piece & move combo are unclear
   #otherwise returns an empty string
   def self.clarify_notation(piece, move, game)
     #gets set of moved piece
     team = piece.team.to_sym
     set = game.sets[team]
     #Get all pieces that are same kind as piece
     same_pieces = set.filer { |p| p.is_a?(piece.class) }
     
     #Select a piece which can do the same move
     other = same_pieces.select do |p|
       next if p.object_id == piece.object_id
       p.possible_moves.include?(move)
     end

     #return if no other piece exists
     return "" if other.nil?

     #Return file if rank is same, rank otherwise
     if other.current_pos[0] == piece.current_pos[0]
       to_file(piece.current_pos)
     else
       to_rank(piece.current_pos)
     end
   end

end
