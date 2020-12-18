require './lib/chess.rb'
require 'json'

$pieces_debug = ""

module Pieces

  @@positions = { "black" => { :pawns => Array.new(8,1).zip((0..7).to_a),
                               :rooks => Array.new(2,0).zip([0,7]),
                               :knights => Array.new(2,0).zip([1,6]),
                               :bishops => Array.new(2,0).zip([2,5]),
                               :queen => [0,3],
                               :king => [0,4]       },
                  "white" =>  { :pawns => Array.new(8,6).zip((0..7).to_a),
                                :rooks => Array.new(2,7).zip([0,7]),
                                :knights => Array.new(2,7).zip([1,6]),
                                :bishops => Array.new(2,7).zip([2,5]),
                                :queen => [7,3],
                                :king => [7,4]       }
  }

  def Pieces.new_set(team)
    set = []
    set.concat(pawns(team))
    set.concat(rooks(team))
    set.concat(bishops(team))
    set.concat(knights(team))
    set << king(team)
    set << queen(team)
    
    return set
  end

  def Pieces.pawns(team)
    pawns = []
    @@positions[team][:pawns].each do |pos|
      pawns << Pawn.new(team: team, starting_pos: pos)
    end
    return pawns
  end

  def Pieces.rooks(team)
    rooks = []
    @@positions[team][:rooks].each do |pos|
      rooks << Rook.new(team: team, starting_pos: pos)
    end
    return rooks
  end

  def Pieces.bishops(team)
    bishops = []
    @@positions[team][:bishops].each do |pos|
      bishops << Bishop.new(team: team, starting_pos: pos)
    end
    return bishops
  end
 
  def Pieces.knights(team)
    knights = []
    @@positions[team][:knights].each do |pos|
      knights << Knight.new(team: team, starting_pos: pos)
    end
    return knights
  end

  def Pieces.king(team)
    pos = @@positions[team][:king]
    king = King.new(team: team, starting_pos: pos)
  end

  def Pieces.queen(team)
    pos = @@positions[team][:queen]
    queen = Queen.new(team: team, starting_pos: pos)
  end

end

class Piece

  include Movement

  @@next_piece_id = 0
  @@moved_last_turn = nil #stores the piece that moved last

  attr_reader :team, :board, :id

  def initialize(args = {})
    @team = args.fetch(:team, "")
    @starting_pos = args.fetch(:starting_pos, [0,0]) 
    @current_pos = nil
    @icon = args.fetch(:icon, false) || get_icon
    @moved = args.fetch(:moved, false)
    @id = @@next_piece_id
    @@next_piece_id += 1
  end

  def set_pos(pos)
    @current_pos = pos
  end

  def starting_pos
    @starting_pos
  end
  
  def previous_pos
  end

  def current_pos
    @current_pos
  end

  #Get either white_icon or black_icon from subclasses
  def get_icon
    if @team == "white"
      white_icon
    else
      black_icon
    end
  end

  def white_icon; end
  def black_icon; end

  def to_json
    JSON.dump({ :class => self.class,
                :icon => @icon,
                :team => @team,
                :current_pos => @current_pos,
                :moved => @moved })
  end

  def self.from_json(json_string)
    data = JSON.load json_string
    data.transform_keys!(&:to_sym)
    Kernel.const_get(data[:class]).new(data)
  end

  public
  def moved_last_turn?(board)
    last_moved = board.return_last_moved
    $pieces_debug += "last_moved: #{last_moved} (id: #{last_moved.id}\n"
    $pieces_debug += "self.id: #{self.id}\n"
    self == board.return_last_moved 
  end

  #Subclasses must define their own behavior for possible_moves and special_moves
  #Special moves are any moves that require a greater context, such as en passant or castling,
  #therefore requiring board to be passed as an argument
  def possible_moves(board)
    moves = normal_moves(board).map { |pos| Movement.create_move(self, pos)  }  
    moves.concat(special_moves(board))
  end

  def normal_moves(board); end
  def special_moves(board) 
    []
  end

  def can_move_to?(pos, board)
    moves = possible_moves(board)
    moves.any? do |mv|
      mv[self][1] == pos
    end
  end

  def set_moved(bool)
    @moved = bool
  end

  def moved?
    @moved
  end

  def add_to_board(board)
    board.place(self, self.starting_pos)
    @board = board
  end

  def to_s
    @icon
  end

  def ==(other)
    if other.kind_of?(Piece)
      self.id == other.id
    else
      false
    end
  end
  #Pieces require a possible_moves class
  #An array of possible moves can be created using the Movement module (see above)
end

class Queen < Piece

  def white_icon
    "\u2655"
  end

  def black_icon
    "\u265B"
  end

  def normal_moves(board)
    moves(self, board).vertically(1..7).or.
      horizontally(1..7).or.
      diagonally(1..7).spaces
  end

end

class Rook < Piece

  def white_icon
    "\u2656" 
  end

  def black_icon
    "\u265C"
  end

  def normal_moves(board)
    moves(self, board).horizontally(1..7).or.
      vertically(1..7).spaces
  end

end

class Knight < Piece

  def white_icon
    "\u2658"
  end

  def black_icon
    "\u265E"
  end

  def normal_moves(board)
    moves(self, board).horizontally(2).and.vertically(1).or.
      vertically(2).and.horizontally(1).spaces
  end

end

class King < Piece

  def white_icon
    "\u2654"
  end

  def black_icon
    "\u265A"
  end

  def normal_moves(board)
    moves(self, board).horizontally(1).or.vertically(1).or.diagonally(1).spaces
  end

  def special_moves(board)
    special_moves_arr = []

    #Castling
    #Only works if king hasn't moved
    if !moved?
      rooks = board.get_pieces(type: "Rook", team: self.team)

      if !rooks.empty?
        #Check if spaces_on(board) between rook and king are empty
        rooks.filter! do |rook|
          !Movement.blocked?(rook, self.current_pos, board, ignore_dest: true)
        end

        return [] if rooks.empty?

        moves = []

        rooks.each do |rook|
          if rook.current_pos[1] > self.current_pos[1]
            move = Movement.create_move(self, [self.current_pos[0], self.current_pos[1] + 2],
                                        rook, [rook.current_pos[0], self.current_pos[1] + 1]) #rook one space right of king's current_pos

          else
            move = Movement.create_move(self, [self.current_pos[0], self.current_pos[1] - 2],
                                        rook, [rook.current_pos[0], self.current_pos[1] - 1] ) #rook one space left of king's current_pos
          end
          moves << move
        end

        #Check for check at any square along the path
        moves.select! do |move|
          #Get spaces_on(board) between moves
          #Check if any space between moves can be reached by an enemy piece
          !Movement.get_spaces_between(self.current_pos, move[self][1]).any? do |space|
            Movement.who_can_reach?(space, board).any? do |piece|
              piece.team != self.team
            end
          end
        end

        special_moves_arr = moves
      end
    end
    return special_moves_arr
  end 
end

class Bishop < Piece

  def white_icon
    "\u2657"
  end

  def black_icon
    "\u265D"
  end

  def normal_moves(board = @board)
    moves(self, board).diagonally(1..7).spaces
  end

end

class Pawn < Piece

  def white_icon
    "\u2659"
  end

  def black_icon
    "\u265F"
  end

  def normal_moves(board)

    #forward movement
    unless @moved
      moves_arr = moves(self, board).forward(1..2).spaces
    else
      moves_arr = moves(self, board).forward(1).spaces
    end

    #diagonal movement
    diag_capture = moves(self, board).forward(1).and.horizontally(1).spaces(pawn_cap: true)
    diag_capture.each do |mv|
      p = board.get_piece_at(mv)
      if p && p.team != self.team
        moves_arr << mv
      end
    end

    return moves_arr
  end

  def special_moves(board)
    special_moves_arr = []
    
    #En passant
    #If an enemy piece moves to a square horizontally adjacent to a pawn
    #the pawn can capture it on the next turn
    current_pos = board.get_coords(self)
    diag_moves = moves(self, board).forward(1).and.horizontally(1).spaces
    if (current_pos[0] - self.starting_pos[0]).abs == 3
      adj_moves = moves(self, board).horizontally(1).spaces(pawn_cap: true)

      adj_moves.each_index do |index|
        something = board.get_piece_at(adj_moves[index])
        if something && something.kind_of?(Pawn)
          prev_pos = board.get_previous_pos(something)
          if something.moved_last_turn?(board) && prev_pos == something.starting_pos
            special_moves_arr << Movement.create_move(self, diag_moves[index], something)
          end
        end
      end
    end

=begin Promotion
    rank = current_pos[0]
    eligible_for_promotion = self.team == "white" ? rank == 1 : rank == 6 
    if eligible_for_promotion
    
    end
=end
    return special_moves_arr
  end
end

