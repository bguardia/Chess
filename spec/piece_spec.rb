require 'spec_helper'
require 'piece'
require 'board'


def return_filled_board(pieces)
  board = Board.new
  pieces.each do |p|
    p.add_to_board(board)
  end
  return board
end

def create_piece_stub(args = {})
  pos = args.fetch(:pos, [0,0])
  clz = Kernel.const_get(args.fetch(:type, "Pawn").capitalize)
  piece = clz.new( team: args.fetch(:team, "white"), starting_pos: pos )
  allow(piece).to receive(:current_pos).and_return(pos)
  return piece
end

describe Piece do

  describe "#initialize" do
    it "sets a team attribute" do
      piece = Piece.new(team: "black")
      expect(piece).to have_attributes( :team => "black" )
    end

    it "sets a current_pos attribute" do
      piece = Piece.new
      expect(piece).to respond_to(:current_pos)
    end

    it "sets an icon attribute" do
    end
  end

  describe "#possible_moves" do
    it "returns all possible moves from piece's current_position" do
    end
  end
end

describe Movement do
  include Movement
  

  describe "#from" do
    it "creates and returns a new Movement::MovementArray" do
      pawn = create_piece_stub
      marr = from(pawn)
      expect(marr).to be_a_kind_of(Movement::MovementArray)
    end
  end

  describe "#who_can_reach?" do
    it { expect(Movement).to respond_to(:who_can_reach?).with(2).arguments }
    it "returns all pieces that can reach a given space on given board" do
      bishop = create_piece_stub( type: "Bishop", team: "white", pos: [1,5])
      pawn = create_piece_stub(team: "black", pos: [1, 6])
      knight = create_piece_stub( type: "Knight", team: "white", pos: [4,7])
      dest = [2, 6]
      pieces = [bishop, pawn, knight]
      board = Board.new
      pieces.each { |p| p.add_to_board(board) }
      expect(Movement.who_can_reach?(dest, board)).to match_array pieces
    end
  end

   describe "#blocked?" do
     it { expect(Movement).to respond_to(:blocked?).with(3).arguments }
     it "returns true if a space between piece and destination is occupied" do
       rook = create_piece_stub(type: "Rook", pos: [7,0])
       queen = create_piece_stub(type: "Queen", pos: [5,0])
       dest = [4,0]
       board = Board.new
       [rook, queen].each { |p| p.add_to_board(board) }
       expect(Movement.blocked?(rook, dest, board)).to be true
     end

     it "returns false if the piece is a knight" do
       knight = create_piece_stub(type: "Knight", pos: [7,5])
       queen = create_piece_stub(type: "Queen", pos: [6,5])
       pawn = create_piece_stub(pos: [5,5])
       board = return_filled_board([knight, queen, pawn])
       dest = [5, 4]
       expect(Movement.blocked?(knight, dest, board)).to be false
     end

     it "returns true if a pawn's destination is occupied" do
       dest = [4,4]
       pawn = create_piece_stub(pos: [6,4])
       knight = create_piece_stub(type: "Knight", pos: dest)
       board = return_filled_board([pawn, knight])
       expect(Movement.blocked?(pawn, dest, board)).to be true
     end
   end

  describe Movement::MovementArray do
=begin    
    describe "#initialize" do
      it "creates a new MovementArray with a given piece" do
        some_coords = [1,5]
        pawn = create_piece_stub(pos: some_coords)
        marr = Movement::MovementArray.new(pawn)
        expect(marr).to have_attributes( :piece => pawn )
      end
    end
=end
   
    def test_movement_methods(msg, ans_arr = [1,5,3])
      piece = create_piece_stub 
      board = Board.new
      piece.add_to_board(board)
      marr = Movement::MovementArray.new(piece)
      moves_arr = []

      moves_arr << marr.send(msg, 2).spaces(on_board: false)
      moves_arr << marr.send(msg, 1..5).spaces(on_board: false)
      moves_arr << marr.send(msg,  [1, 3, 5]).spaces(on_board: false)

      expect(moves_arr[0].length).to eq(ans_arr[0])
      expect(moves_arr[1].length).to eq(ans_arr[1])
      expect(moves_arr[2].length).to eq(ans_arr[2])
    end

    describe "#up" do
      it "accepts an integer, range of integers or array of integers" do
        test_movement_methods(:up)
      end
    end

    describe "#down" do
      it "accepts an integer, range of integers or array of integers" do
        test_movement_methods(:down)
      end
    end

    describe "#left" do
      it "accepts an integer, range of integers or array of integers" do 
        test_movement_methods(:left)
      end
    end

    describe "#right" do
      it "accepts an integer, range of integers or array of integers" do 
        test_movement_methods(:right)
      end
    end

    describe "#horizontally" do
      it "accepts an integer, range of integers or array of integers" do 
        test_movement_methods(:horizontally, [2, 10, 6])
      end
    end

    describe "#vertically" do
      it "accepts an integer, range of integers or array of integers" do 
        test_movement_methods(:vertically, [2, 10, 6])
      end
    end

    describe "#diagonally" do
      it "accepts an integer, range of integers or array of integers" do 
        test_movement_methods(:diagonally, [4, 20, 12])
      end
    end

    describe "#and" do
      it "combines movements together to create a single movement" do
        piece = create_piece_stub
        board = Board.new
        piece.add_to_board(board)
        marr = Movement::MovementArray.new(piece)
        moves = marr.up(2).and.left(1).spaces(on_board: false)
        expect(moves).to match_array [[-2, -1]]
      end
    end
  
    describe "#or" do
      it "separates movements from one another" do
        piece = create_piece_stub
        board = Board.new
        piece.add_to_board(board)
        marr = Movement::MovementArray.new(piece)
        moves = marr.up(2).and.left(1).or.down(1).and.right(2).spaces(on_board: false)
        expect(moves).to match_array [[-2,-1], [1, 2]]
      end
    end

    describe "#spaces" do
      it "#ends a movement chain, returning an array" do
        piece = create_piece_stub
        board = Board.new
        piece.add_to_board(board)
        marr = Movement::MovementArray.new(piece)
        moves = marr.down(1).spaces
        expect(moves).to be_a_kind_of(Array)
      end
    end
  end
end


describe Pawn do
  
  describe "#special_moves" do
    it "returns an diagonally adjacent squares in front of it that have an enemy piece" do
      pawn = create_piece_stub(team: "white", pos: [4,4])
      p2 = create_piece_stub(team: "black", pos: [3,3])
      p3 = create_piece_stub(type: "Knight", team: "black", pos: [3,5])
      board = Board.new
      [pawn, p2, p3].each { |p| p.add_to_board(board) }

      expect(pawn.special_moves).to match_array [[3,3], [3,5]]
    end

    it "returns en passant when applicable" do
      pawn = Pawn.new(team: "white", starting_pos: [6,4]) 
      p2 = Pawn.new(team: "black", starting_pos: [3,5]) 
      allow(p2).to receive(:moved_last_turn?).and_return(true)
      allow(p2).to receive(:starting_pos).and_return([1,5])
      allow(p2).to receive(:previous_pos).and_return([1,5])
      board = Board.new
      [pawn, p2].each { |p| p.add_to_board(board) } 
      board.move(pawn, [3,4])
      board.move(p2, [3,5])
      
      expect(pawn.special_moves).to match_array [[2,5]]
    end
  end
end

describe King do

  describe "#special_moves" do
    it "returns the spaces that the king can move when castling is available" do
      king = create_piece_stub(type: "King", team: "white", pos: [7, 4])
      rook = create_piece_stub(type: "Rook", team: "white", pos: [7, 0])
      rook2 = create_piece_stub(type: "Rook", team: "white", pos: [7, 7])
      board = Board.new
      [king, rook, rook2].each { |p| p.add_to_board(board) }
      castle_positions = [ [7, 2], [7, 6] ]
      expect(king.special_moves).to match_array castle_positions
    end

    it "does not return a castle if king would be in check in any position in between" do
      king = create_piece_stub(type: "King", team: "white", pos: [7,4])
      rook = create_piece_stub(type: "Rook", team: "white", pos: [7,0])
      bishop = create_piece_stub(type: "Bishop", team: "black", pos: [5,1])
      board = Board.new
      [king, rook, bishop].each { |p| p.add_to_board(board) }
      expect(king.special_moves).to match_array []
    end
  end

end

