#require './lib/chess.rb'

$movement_debug = ""

module Movement

  #create a new MovementArray with the given board and piece 
  #MovementArray's methods can be chained from here to create an array of possible moves
  def moves(piece, board)
    MovementArray.new(piece, board)
  end

  def pawn_moves(pawn, state)
    #Forward movement
    if pawn.moved? == false
      positions = MovementArray.new(pawn, state).forward(1..2).spaces
    else
      positions = MovementArray.new(pawn, state).forward(1).spaces
    end

    #Diagonal captures
    diag_forward = MovementArray.new(pawn, state).forward(1).and.horizontally(1).spaces(pawn_cap: true)
    diag_forward.each do |dest_pos|
      dest_piece = state.get_piece_at(dest_pos)
      if dest_piece && dest_piece.team != pawn.team
        positions << dest_pos
      end
    end

    moves = create_moves(positions, pawn, state)
    
    #check for and add promotions
    to_remove = [] #array of all old moves to be removed 
    promotions = [] #array of new promotion moves
    last_rank = pawn.team == "white" ? 0 : 7 
    moves.each do |mv|
      if mv.destination(pawn)[0] == last_rank
        t = pawn.team
        promotion_pieces = [Rook.new(team: t), Bishop.new(team: t), Queen.new(team: t), Knight.new(team: t)]
        promotion_pieces.each do |p|
          new_move = Move.new(move: mv.instructions) 
          new_move.set_promotion_piece(p)
          promotions << new_move
        end        
        to_remove << mv
      end
    end

    moves.concat(promotions) #add promotion versions of created moves
    to_remove.each do |mv|
      moves.delete(mv) #remove any previous versions of same moves
    end

    #moves << en_passant(pawn, state)
    moves.compact
  end

  def bishop_moves(bishop, state)
     positions = MovementArray.new(bishop, state).diagonally(1..7).spaces
     moves = create_moves(positions, bishop, state)
     #$game_debug += "#{bishop.team} Bishop (#{bishop.id}) moves:\n"
     #moves.each do |mv|
      # $game_debug += "#{mv}\n captures: #{mv.get_attr(:capture)}, blocked?: #{mv.blocked?}, invalid?: #{mv.get_attr(:invalid)}\n"
     #end
     moves
  end

  def queen_moves(queen, state)
    positions = MovementArray.new(queen, state).diagonally(1..7).or.horizontally(1..7).or.vertically(1..7).spaces
    create_moves(positions, queen, state)
    moves = create_moves(positions, queen, state)
=begin
    $game_debug += "#{queen.team} #{queen.class} (#{queen.id}) moves:\n"
    moves.each do |mv|
      $game_debug += "#{mv}\n captures: #{mv.get_attr(:capture)}, blocked?: #{mv.blocked?}, invalid?: #{mv.get_attr(:invalid)}\n\n"
    end
=end
    moves

  end

  def king_moves(king, state)
    positions = MovementArray.new(king, state).diagonally(1).or.horizontally(1).or.vertically(1).spaces
    moves = create_moves(positions, king, state)
    #moves.concat(castling(king, state))
  end

  def knight_moves(knight, state)
    positions = MovementArray.new(knight, state).vertically(2).and.horizontally(1).or.horizontally(2).and.vertically(1).spaces
    create_moves(positions, knight, state)
  end

  def rook_moves(rook, state)
    positions = MovementArray.new(rook, state).vertically(1..7).or.horizontally(1..7).spaces
    create_moves(positions, rook, state)
  end

  #Special moves
  def en_passant(pawn, state)
    current_rank = (pawn.current_pos[0] - pawn.starting_pos[0]).abs + 2
    if current_rank == 5
      en_passant = nil
      diag_forward = MovementArray.new(pawn, state).forward(1).and.horizontally(1).spaces
      adj_spaces = MovementArray.new(pawn, state).horizontally(1).spaces(pawn_cap: true)

      adj_spaces.each_index do |i|
        adj_pos = adj_spaces[i]
        adj_piece = state.get_piece_at(adj_pos)
        if adj_piece && adj_piece.team != pawn.team && adj_piece.kind_of?(Pawn)
          moved_last = state.get_last_moved == adj_piece
          two_spaces_in_one_turn = state.get_previous_pos(adj_piece) == adj_piece.starting_pos

          if moved_last && two_spaces_in_one_turn
            en_passant = [[self, self.current_pos, diag_forward[i]],
                          [adj_piece, adj_piece.current_pos, nil]]
            break
          end
        end
      end

      if en_passant
        return [Move.new(move: en_passant, type: :en_passant)]
      end     
    end

    return []
  end

  def castling(king, state)
    $game_debug += "called castling\n"
    in_check = state.in_check?(king: king)
    $game_debug += "in_check is: #{in_check}\n"
    unless state.get_moved_status(king) || in_check
      castles = []
      rooks = state.get_pieces(type: "Rook", team: king.team, moved: false)
      rooks.each do |rook|
        #check spaces between rook and king are open
        spaces_between = Movement.get_spaces_between(king.current_pos, rook.current_pos)
        #$game_debug += "spaces_between king and rook are: #{spaces_between}\n"
        piece_array = spaces_between.map { |pos| state.get_piece_at(pos) }
        #$game_debug += "piece array is:\n"
=begin
        piece_array.each do |p|
          if p.kind_of?(Piece)
            $game_debug += "#{p.team} #{p.class} (#{p.id})\n"
          end
        end
=end

         not_blocked = piece_array.compact.empty?
        #$game_debug += "not_blocked is: #{not_blocked}\n"
        if not_blocked
          king_pos = state.get_pos(king)
          rook_pos = state.get_pos(rook)
          king_dest = [ king_pos[0], rook_pos[1] < king_pos[1] ? 2 : 6]
          rook_dest = [ rook_pos[0], rook_pos[1] < king_pos[1] ? 3 : 5]

          #check that the spaces the king traverses are not attackable
          king_traverse = Movement.get_spaces_between(king.current_pos, king_dest) 
          #$game_debug += "checking for attacking pieces...\n"
          #$game_debug  += "king_traverse is: #{king_traverse}\n"
          enemy_team = ["white", "black"].find { |t| t != king.team }
          enemy_moves = state.get_moves(team: enemy_team).filter { |mv| !mv.blocked? }
          #$game_debug += "enemy moves it:\n"
          #enemy_moves.each do |mv|
            #$game_debug += "#{mv}\n"
          #end
          attackable = enemy_moves.any? do |mv|
            king_traverse.any? do |space|
              mv.include?(space)
            end
          end
          
          $game_debug += "attackable is: #{attackable}\n"
          unless attackable
          castles << Move.new(move: [[king, king.current_pos, king_dest],
                                     [rook, rook.current_pos, rook_dest]],
                              type: :castle)
          end
        end
      end
=begin
      $game_debug += "castles is:\n"
      castles.each do |mv|
        $game_debug += "#{mv}\n"
      end
=end      
      return castles
    end
    #$game_debug += "king has already moved. returning empty array.\n"
    return []
  end

  def create_moves(moves, piece, state)
    move_hash_arr = []
    move_arr = []

    moves.each do |dest_pos|
      dest_piece = state.get_piece_at(dest_pos)
=begin
      if piece.kind_of?(Queen)
        dest_team = dest_piece.nil? ? "-" : dest_piece.team
        dest_class = dest_piece.nil? ? "-" : dest_piece.class
        $game_debug += "Queen: #{state.get_pos(piece)} -> #{dest_pos}; dest_piece: #{dest_team} #{dest_class}\n" 
      end
=end
      if dest_piece && dest_piece.team == piece.team
        next
      end

      current_pos = state.get_pos(piece)
      spaces_between = Movement.get_spaces_between(current_pos, dest_pos)
      blocked = spaces_between.any? do |space|
        state.get_piece_at(space)
      end
      blocked = false if piece.kind_of?(Knight)

      move = [[piece, current_pos, dest_pos]]
      move << [dest_piece, state.get_pos(dest_piece), nil] if dest_piece

      move_hash_arr << { move: move,
                         blocked: blocked,
                         capture: dest_piece }     
      end

    move_hash_arr.each do |mvh|
      move = Move.new(mvh)
      move_arr << move 
    end

    return move_arr
  end

  class MovementArray
   
    attr_reader :moves, :modifiable_moves, :origin 
    
    def initialize(piece, board)    
      @piece = piece
      @board = board
      @origin = board.get_pos(piece)
      @moves = []
      @modifiable_moves = [[0,0]]
      #$movement_debug += "MovementArray.new called. @piece: #{@piece.class}, @origin: #{@origin}\n"
    end

    private
    def add_moves
      @modifiable_moves.each do |move|
        @moves << move.dup
      end
    end

    #applies a moves_arr to any currently modifiable moves (any moves defined before an #or call, or [0,0])
    def modify_moves(moves_arr)
      modified_moves = []
      @modifiable_moves.each do |one|
        moves_arr.each do |two|
          modified_moves << [ one[0] + two[0], one[1] + two[1] ]
        end
      end
      @modifiable_moves = modified_moves.dup
    end

    #creates an array of moves from separate x and y arrays
    #works well for two arrays of equal length, or one single element with another array of any size
    def create_moves_array(args)
      move_arr = []
      x = args.fetch(:x, [0])
      y = args.fetch(:y, [0])
      y_i = 0
      x_i = 0

      loop do
        move_arr << [y[y_i], x[x_i]]
        x_i += 1 if more_x = x_i < x.length - 1
        y_i += 1 if more_y = y_i < y.length - 1
        break unless more_x || more_y
      end

      return move_arr
    end

    def reset_modifiable_moves
      @modifiable_moves = [[0,0]]
    end
    
    def to_arr(n)
      if n.kind_of?(Array)
        return n
      elsif n.kind_of?(Integer)
        return [n]
      elsif n.kind_of?(Range)
        return n.to_a
      end
    end

    def reset_moves
      @moves = []
    end

    #Movement methods are chained to create arrays of possible positions
    #Methods can accept an Integer or a Range/Array of Integers
    #  A single Integer creates a single move
    #  A Range or Array will create a position for each element
    #Methods can be changed with #and, #or and #up_to methods to create more complex movements
    #
    #Finally, ending the chain with #spaces will return a final array of moves based on the origin
    public
    def horizontally(n)
      n = to_arr(n)
      n = n.concat(n.map { |n| -n })
      moves_arr = create_moves_array(x: n)
      modify_moves(moves_arr)
      return self
    end

    def diagonally(n)
      positive_n = to_arr(n)
      negative_n = positive_n.map { |num| -num }

      moves_arr = []
      moves_arr.concat create_moves_array(x: positive_n, y: positive_n ) #down-right
      moves_arr.concat create_moves_array(x: positive_n, y: negative_n ) #up-right
      moves_arr.concat create_moves_array(x: negative_n, y: negative_n ) #down-left
      moves_arr.concat create_moves_array(x: negative_n, y: positive_n ) #up-left

      modify_moves(moves_arr)
      return self
    end

    def vertically(n)
      n = to_arr(n)
      n = n.concat(n.map { |n| -n })
      moves_arr = create_moves_array(y: n)
      modify_moves(moves_arr)
      return self
    end

    def up(n) 
      num_moves = to_arr(n).map { |y| -y }
      moves_arr = create_moves_array(y: num_moves)
      modify_moves(moves_arr)
      return self
    end

    def down(n) 
      num_moves = to_arr(n)
      moves_arr = create_moves_array(y: num_moves)
      modify_moves(moves_arr)
      return self
    end

    def left(n)
      num_moves = to_arr(n).map { |x| -x }
      moves_arr = create_moves_array(x: num_moves)
      modify_moves(moves_arr)
      return self
    end

    def right(n)
      num_moves = to_arr(n)
      moves_arr = create_moves_array(x: num_moves)
      modify_moves(moves_arr)
      return self
    end

    #Generates a different direction based on piece's team
    def forward(n)
      if @piece.team == "black"
        down(n)
      elsif @piece.team == "white"
        up(n)
      end
      return self
    end
    
    #Will multiply @modifiable_moves n times
    def up_to(n)
      return self unless n >= 2
      m = 1
      modified_moves = []
      n.times do
        @modifiable_moves.each do |move|
          modified_moves << [ move[0] * m, move[1] * m ]
        end
        m += 1
      end
      @modifiable_moves = modified_moves.dup
      return self
    end

    #Currently has no logical purpose, only exists in contrast with #or, and makes method chains more human-readable
    def and
      return self
    end

    #Takes all moves generated up to this method and moves them to the @moves array, protecting them from further modification
    #For example, a knight's possible moves can be described as: #horizontally(2).and.vertically(1).or.vertically(2).and.horizontally(1).spaces
    def or
      add_moves
      reset_modifiable_moves
      return self
    end

    def spaces(args = {})
      add_moves
      moves = @moves.map { |move| [move[0] + @origin[0], move[1] + @origin[1]] }
      
      #$movement_debug += "Spaces called. Calculated positions are: #{moves}\n"

      on_board = moves.filter do |pos|
        valid_r = pos[0] >= 0 && pos[0] <= 7
        valid_f = pos[1] >= 0 && pos[1] <= 7
        valid_r && valid_f
      end

      #$movement_debug += "Positions off board have been filtered. Now: #{on_board}\n"

=begin
      unless @piece.kind_of?(Knight)
        $movement_debug += "Piece is not a knight. Filtering blocked moves...\n"
        on_board.filter! do |move|
          !Movement.blocked?(@piece, move, @board)
        end
        $movement_debug += "Blocked moves have been filtered. Remaining moves: #{on_board}\n"
      end
=end

      #pawns cannot capture pieces unless moving diagonally,
      #so set :pawn_cap to true for diagonal movement
      if @piece.kind_of?(Pawn)
        unless args.fetch(:pawn_cap, false)
          #$movement_debug += "Piece is a pawn and :pawn_cap is false. Filtering positions with pieces...\n"
          on_board.filter! do |move|
            @board.get_piece_at(move).nil?
          end
          #$movement_debug += "Positions have been filtered. Remaining moves: #{on_board}\n"
        end
      end

      reset_moves
      reset_modifiable_moves
      return on_board
    end

  end

  def self.blocked?(piece, move, board, args = {})
    #return false if piece.kind_of?(Knight) #Knights can jump over pieces
    unless piece.kind_of?(Knight)
      #get the number of spaces between current_pos and move
      pos = board.get_pos(piece)
      spaces_between = get_spaces_between(pos, move)

      #If piece is a pawn, add destination to spaces_between array
      #Pawns can't take enemy pieces through normal movement
      
      
      #return true if there are any pieces between the piece and the destination
      pieces = spaces_between.map { |s| board.get_piece_at(s) }.compact
      
      return true unless pieces.empty?
    end

    #Check destination space unless explicitly :ignore_dest is true
    unless args.fetch(:ignore_dest, false)
      dest_piece = board.get_piece_at(move)  
      return false if dest_piece.nil?
      return true if dest_piece.team == piece.team
    end

    return false
  end

  def self.who_can_reach?(pos, board, args = {})
    pieces = board.get_pieces(args)
    $game_debug += "pieces: #{pieces}\n"
    pieces.filter! do |piece|
      can_reach = piece.can_reach?(pos)
      $game_debug += "for #{piece.class} (#{piece.id}): can_reach is #{can_reach}\n"
      can_reach
    end

    $game_debug += "pieces is now: #{pieces}\n"
    return pieces
  end

  #Returns an array of coordinates between two given coordinates
  def self.get_spaces_between(a, b)
    spaces_between = []

    #Get duplicates of arrays so as not to harm originals
    start = a.dup
    dest = b.dup

    while start[0] != dest[0] || start[1] != dest[1]
      if start[0] < dest[0]
        start[0] += 1
      elsif start[0] > dest[0]
        start[0] -= 1
      end

      if start[1] < dest[1]
        start[1] += 1
      elsif start[1] > dest[1]
        start[1] -= 1
      end
      
      spaces_between << start.dup
    end

    spaces_between.pop #removes the destination coordinates

    return spaces_between
  end

  def self.validate_moves(moves, state)
    p = moves[0].get_piece
    king = state.get_pieces(type: "King", team: p.team)[0]
    enemy_team = ["white", "black"].find { |t| t != p.team }
    enemy_pieces = state.get_pieces(team: enemy_team)
  
    return [] if king.nil?
    #$game_debug += "Listing moves sent to validate_moves:\n"
    #moves.each do |mv|
      #$game_debug += "#{mv}\n"
    #end
    
    #get moves that would reach king (blocked and unblocked)
    attacking_moves = []
    blocked_moves = []
    enemy_pieces.each do |ep|
      ep.possible_moves.each do |mv|
        if mv.captures?(king)
          attacking_moves << mv
        end
      end
      ep.blocked_moves.each do |mv|
        if mv.captures?(king)
          blocked_moves << mv
        end
      end
    end

    #$game_debug += "Attacking moves (length:#{attacking_moves.length}) includes:\n"
    #attacking_moves.each { |mv| $game_debug += "#{mv}" }
    #If attackers, make sure move stops any possible attacks

    valid_moves = []
    unless attacking_moves.empty?
      #get spaces between king and attackers
      spaces_arr = []
      #$game_debug += "Attackers are: \n"
      attacking_moves.each do |atkmv|
        attacker = atkmv.get_piece
        spaces_between = []
        unless attacker.kind_of?(Knight)
          spaces_between = get_spaces_between(king.current_pos, attacker.current_pos)
        end
        spaces_between << attacker.current_pos
        spaces_arr << spaces_between 
     end
     #get intersection of spaces (in case of multiple attackers 
     spaces = spaces_arr.reduce(spaces_arr[0]) { |a,b| a.intersection(b) }
     #check each move for matches (or escapes if king)
     #$game_debug += "\nSpaces to check are: #{spaces}\n"
     #$game_debug += "Checking moves that match the spaces given...\n"
     moves.each do |mv|
       #$game_debug += "#{mv}\n"
       blocks = false
       king_escapes = false
       piece = mv.get_piece
       unless piece.kind_of?(King)
         blocks = spaces.any? do |space|
           mv.destination(piece) == space
         end
       else
        temp_state = state.do(mv)
        king_escapes = !temp_state.in_check?(king: king)
        #$game_debug += "Move:\n #{mv}\n king_escapes: #{king_escapes}\n"
       end
      #$game_debug += "blocks: #{blocks}, king_escapes: #{king_escapes}\n\n"
      mv.set_attr(:invalid, true) unless blocks || king_escapes
      end
     #$game_debug += "\n\n"
    end
    
    #Check moves against any blocked checks
    blocked_valid_moves = []
    unless blocked_moves.empty?
      blocked_moves.each do |blkdmv|
        #Get all spaces between blocked piece and king (including blocked piece)
        blkd_atk_pos = blkdmv.get_piece.current_pos
        spaces_between = get_spaces_between(king.current_pos, blkd_atk_pos)
        blocking_pieces = spaces_between.map { |s| state.get_piece_at(s) }.compact #get blocking pieces before adding blocked piece space
        spaces_between << blkd_atk_pos
        #$game_debug += "blocking pieces is: #{blocking_pieces}\n"
        moves.each do |move|
          piece = move.get_piece
          if blocking_pieces.include?(piece) && !spaces_between.include?(move.destination(piece)) && blocking_pieces.length == 1     
            move.set_attr(:invalid, true)
          end
        end
      end
    end

=begin  
  #for debugging
  $game_debug += "Move Validation Report: \n"
  moves.each do |move|
    p = move.get_piece
    t = p.team
    id = p.id
    prev_pos = p.current_pos
    pos = move.destination(p)
    invalid = move.get_attr(:invalid)
    $game_debug += "#{t} #{p} (#{id}): #{prev_pos} -> #{pos}, invalid?: #{invalid}, obj_id: #{move.object_id}\n"
  end
=end

  #Check king moves for possible self-checks
    moves.each do |mv|
      if mv.get_piece == king
       temp_state = state.do(mv)
       king_escapes = !temp_state.in_check?(king: king)
       mv.set_attr(:invalid, true) unless king_escapes
      end
    end

  return moves
  end

  def self.in_check?(king, board)
    op_team = ["white", "black"].find { |t| t != king.team }

    enemy_pieces = board.get_pieces(team: op_team)

    king_pos = king.current_pos
    #$pieces_debug+=  "king's position is: #{king_pos}"

    can_reach = enemy_pieces.filter do |piece|
      piece.can_reach?(king_pos)
    end

    return nil if can_reach.empty?
    return can_reach
  end

  def self.checkmate?(king, board)
    #return false unless king is in check
    can_reach = in_check?(king, board)
    return false unless can_reach


    #first check if king can escape from check on its own
    king_can_escape = king.possible_moves.any? do |move|
      board.do(move)
      not_in_check = !Movement.in_check?(king, board)
      board.undo(move)
      not_in_check
    end

    return false if king_can_escape

    #get important spaces to help cut down on calculations
    #important spaces include spaces between king and attacker,
    #as well as attacker positions
    king_pos = king.current_pos
    important_spaces = []
    can_reach.each do |attacker|
      attack_pos = attacker.current_pos
      important_spaces << Movement.get_spaces_between(king_pos, attack_pos)
      important_spaces << attack_pos
    end 

    #check possible moves of other ally pieces
    pieces = board.get_pieces(team: king.team)
    checkmate = pieces.all? do |piece|
      piece.possible_moves.all? do |mv|
        #if move can block or take attacking piece
        #simulate move and check state
        mv.all? do |piece, pos_arr|
          pos = pos_arr[1]
          if important_spaces.include?(pos)
            board.do(mv)
            check = Movement.in_check?(king, sim_board)
            board.undo(mv)
            check
          else
            true
          end
        end
      end
    end
    return checkmate
  end

  def self.return_move(piece_pos, dest_pos, board)
    #$game_debug += "called Movement.return_move(#{piece_pos}, #{dest_pos}, board)\n"
    piece = board.get_piece_at(piece_pos)
    return [EmptyMove.new] if piece.nil?

    moves = piece.possible_moves

    #$game_debug += "Piece is: #{piece.class} (#{piece.id})\n"
    #$game_debug += "Moves are:\n"
    #moves.each do |mv|
      #$game_debug += mv.to_s
    #end

    #check for any moves matching given destination
    #and return first match
    possible_moves = []
    moves.each do |mv|
      #$game_debug += mv.to_s
      if mv.destination(piece) == dest_pos
        #$game_debug += "Move matched to #{dest_pos}\n"
        possible_moves << mv
      end
    end

    return possible_moves unless possible_moves.empty?
    #return nil if none match
    return [EmptyMove.new] #empty move 
  end

  def self.create_move(move_arr, type)
    move = Move.new(move: move_arr, type: type) 
    return move
  end

  def self.add_to_move(move, piece2, dest_pos2)
     move.merge({ piece2 => [piece2.current_pos, dest_pos2] })
  end

  def promotion?(piece)
    if piece.kind_of?(Pawn)
      final_rank = piece.team == "white" ? 0 : 7
      if piece.current_pos[0] == final_rank
        return true
      end
    end
    return false
  end
end

class Move < Saveable

  def initialize(args = {})
    @instructions = prepare_arr(args.fetch(:move, nil)) # [ [piece, current_pos, next_pos] ] 
    @turn = args.fetch(:team, nil) || get_team #:white, :black
    #additional information about a move
    @attributes = args.fetch(:attr, nil) || { :type => args.fetch(:type, nil),        #:normal, :en_passant, :castle, :promotion   
                    :blocked => args.fetch(:blocked, nil),  
                    :capture => args.fetch(:capture, nil),
                    :check => false,
                    :checkmate => false,
                    :notation => nil,
                    :promoted_to => nil,
                    :invalid => false    }
  end

  def get_team
    if @instructions
      @instructions.first[0].team
    else
      nil
    end
  end

  public
  def add(move_arr)
    new_instruct = @instructions.dup
    move_arr = prepare_arr(move_arr)
    move_arr.each do |mv|
      new_instruct << mv
    end

    @instructions = new_instruct
=begin
    Move.new(move: new_instruct,
             team: @turn,
             attr: @attributes.dup)
=end  
  end

  def instructions
    @instructions
  end

  def ==(other)
    if other.respond_to?(:instructions)
      instructions == other.instructions
    end
  end

  def set_promotion_piece(piece)
    pawn_move = @instructions.first
    pawn = pawn_move.first
    pawn_dest = pawn_move.last

    add([[ pawn, pawn_dest, nil ],
                    [ piece, nil, pawn_dest ]])

    set_attr(:type, :promotion)
    set_attr(:promoted_to, piece)
=begin
    new_move.set_attr(:promoted_to, piece)
    return new_move
=end
  end

  def promoted_to
    get_attr(:promoted_to)
  end

  def prepare_arr(arr)
    return nil if arr.nil?

    if arr.flatten == arr
      return [arr.dup]
    else
      return arr.map { |row| row.dup }
    end
  end

  def type
    get_attr(:type)
  end

  def set_attr(attr, val)
    return nil unless @attributes.has_key?(attr)
    @attributes[attr] = val
  end

  def get_attr(attr)
    @attributes[attr]
  end

  def include?(pos)
    @instructions.each do |move_arr|
      move_arr[1..2].each do |move_pos|
        return true if move_pos == pos
      end
    end

    return false
  end

  def blocked?
    get_attr(:blocked)
  end

  def captures?(piece)
    get_attr(:capture) == piece
  end

  def each (&block)
    @instructions.each do |move|
      block.call(move)
    end
  end

  def get_piece
    if @instructions
      @instructions.first.first
    else
      nil
    end
  end

  def destination(piece)
    @instructions.each do |move_arr|
      if move_arr[0] == piece
        return move_arr[2]
      end
    end

    return nil
  end
=begin
  def to_json
    JSON.dump({ "instructions" => @instructions,
                "attributes" => @attributes,
                "turn" => @turn })
  nil
  end
=end

  def to_h
    nil
  end

  def self.from_json(json)
    data = JSON.load json
    instructions = data["instructions"].map do |arr|
      [Piece.from_json(arr[0]), arr[1], arr[2]]
    end

    attributes = data["attributes"].transform_keys(&:to_sym)

    Move.new(move: instructions,
             attr: attributes,
             team: turn)
  end

  def to_s
    str = "Move (#{self.object_id}) :\n"
    each do |p, cur_pos, dest_pos|
      str += "-> #{p.class} (#{p.id}), #{cur_pos}, #{dest_pos}\n"
    end
    return str
  end
end

class EmptyMove < Move
  
  def each (&block); end
  def destination(piece); end
  def include?(pos); end
  def set_attr(attr, val); end
  def get_attr(attr); end

end
