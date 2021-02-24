#require './lib/chess.rb'

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

class Piece < Saveable

  include Movement

  @@next_piece_id = 0
  @@moved_last_turn = nil #stores the piece that moved last
  @@pieces = []

  attr_reader :team, :id

  def initialize(args = {})
    @team = args.fetch(:team, "")
    @starting_pos = args.fetch(:starting_pos, [0,0]) 
    @current_pos = @starting_pos 
    @icon = args.fetch(:icon, false) || get_icon
    @moved = args.fetch(:moved, false)
    
    @possible_moves = []
    @blocked_moves = []

    set_id(args)

    @@pieces << self
  end

  def set_id(args)
    id = args.fetch(:id, false)
    if id
      @id = id
    else
      @id = @@next_piece_id
      @@next_piece_id += 1
    end
  end

  def set_pos(pos)
    @current_pos = pos
  end

  def set_moves(moves)
    @possible_moves = []
    @blocked_moves = []
    moves.each do |mv|
      unless mv.blocked?
        @possible_moves << mv
      else
        @blocked_moves << mv
      end
    end
  end

  def set_moved(bool)
    @moved = bool
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

=begin
  def to_json
    JSON.dump({ :class => self.class,
                :starting_pos => @starting_pos,
                :team => @team,
                :id => @id })
  end

  def self.from_json(json_string)
    data = JSON.load json_string
    data.transform_keys!(&:to_sym)

    #check if a piece with the same id already exists
    existing_piece = @@pieces.find { |p| p.id == data["id"] }
    if existing_piece
      return existing_piece
    else
      return Kernel.const_get(data[:class]).new(data)
    end
  end
=end

  def self.create_observer
    Observer.new(to_do:->(state) { self.update_pieces(state) })
  end

  def self.update_pieces(state)
    pieces = state.get_pieces

    pieces.each do |piece|
      pos = state.get_pos(piece)
      moves = state.get_moves(id: piece.id).flatten
      moved = state.get_moved_status(piece)
      piece.set_pos(pos)
      piece.set_moves(moves)
      piece.set_moved(moved)
    end
  end

  #Subclasses must define their own behavior for possible_moves and special_moves
  #Special moves are any moves that require a greater context, such as en passant or castling,
  #therefore requiring board to be passed as an argument
  def generate_possible_moves(state)
  end

  def possible_moves
    @possible_moves.filter { |mv| !mv.get_attr(:invalid) }
  end

  def blocked_moves
    @blocked_moves
  end

  def moved?
    @moved
  end

  def can_reach?(pos)
    @possible_moves.any? do |move|
      move.destination(self) == pos
    end
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

  def generate_possible_moves(state)
    queen_moves(self, state)
  end
end

class Rook < Piece

  def white_icon
    "\u2656" 
  end

  def black_icon
    "\u265C"
  end

  def generate_possible_moves(state)
    rook_moves(self, state)
  end
end

class Knight < Piece

  def white_icon
    "\u2658"
  end

  def black_icon
    "\u265E"
  end

  def generate_possible_moves(state)
    knight_moves(self, state)
  end
end

class King < Piece

  def white_icon
    "\u2654"
  end

  def black_icon
    "\u265A"
  end

  def generate_possible_moves(state)
    king_moves(self, state)
  end
end

class Bishop < Piece

  def white_icon
    "\u2657"
  end

  def black_icon
    "\u265D"
  end

  def generate_possible_moves(state)
    bishop_moves(self, state)
  end
end

class Pawn < Piece

  def white_icon
    "\u2659"
  end

  def black_icon
    "\u265F"
  end

  def generate_possible_moves(state)
    pawn_moves(self, state)
  end
end

