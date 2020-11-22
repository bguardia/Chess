require 'spec_helper'
require 'piece'

def return_filled_board(pieces)
  board = Board.new
  pieces.each do |p|
    board.place(p, p.current_pos)
  end
  return board
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
      marr = from([0,0])
      expect(marr).to be_a_kind_of(Movement::MovementArray)
    end
  end

  describe "#who_can_reach?" do
    it { expect(Movement).to respond_to(:who_can_reach?).with(2).arguments }
    it "returns all pieces that can reach a given space on given board" do
      bishop = Bishop.new(team: "white", current_pos: [4,4])
      pawn = Pawn.new(team: "black", current_pos: [1, 6])
      knight = Knight.new(team: "white", current_pos: [4,7])
      dest = [2, 6]
      pieces = [bishop, pawn, knight]
      board = Board.new
      pieces.each { |p| board.place(p, p.current_pos) }
      expect(Movement.who_can_reach?(dest, board)).to match_array pieces
    end
  end

   describe "#blocked?" do
     it { expect(Movement).to respond_to(:blocked?).with(3).arguments }
     it "returns true if a space between piece and destination is occupied" do
       rook = Rook.new(current_pos: [7,0])
       queen = Queen.new(current_pos: [5,0])
       dest = [4,0]
       board = return_filled_board([rook, queen])
       expect(Movement.blocked?(rook, dest, board)).to be true
     end

     it "returns false if the piece is a knight" do
       knight = Knight.new(current_pos: [7,5])
       queen = Queen.new(current_pos: [6,5])
       pawn = Pawn.new(current_pos: [5,5])
       board = return_filled_board([knight, queen, pawn])
       dest = [5, 4]
       expect(Movement.blocked?(knight, dest, board)).to be false
     end

     it "returns true if a pawn's destination is occupied" do
       dest = [4,4]
       pawn = Pawn.new(current_pos: [6,4])
       knight = Knight.new(current_pos: dest)
       board = return_filled_board([pawn, knight])
       expect(Movement.blocked?(pawn, dest, board)).to be true
     end
   end

  describe Movement::MovementArray do
    
    describe "#initialize" do
      it "creates a new MovementArray with a given starting coordinate" do
        some_coords = [1,5]
        marr = Movement::MovementArray.new(some_coords)
        expect(marr).to have_attributes( :origin => some_coords )
      end
    end
    
    def test_movement_methods
      yield 2
      yield 1..5
      yield [1, 3, 5]
    end

    describe "#up" do
      it "accepts an integer, range of integers or array of integers" do
        marr = Movement::MovementArray.new([0,0])
        moves_arr = []
        test_movement_methods { |var| moves_arr << marr.up(var).spaces }
        expect(moves_arr[0].length).to eq(1)
        expect(moves_arr[1].length).to eq(5)
        expect(moves_arr[2].length).to eq(3)
      end
    end

    describe "#down" do
      it "accepts an integer, range of integers or array of integers" do
        marr = Movement::MovementArray.new([0,0])
        moves_arr = []
        test_movement_methods { |var| moves_arr << marr.down(var).spaces }
        expect(moves_arr[0].length).to eq(1)
        expect(moves_arr[1].length).to eq(5)
        expect(moves_arr[2].length).to eq(3)
      end
    end

    describe "#left" do
      it "accepts an integer, range of integers or array of integers" do 
        marr = Movement::MovementArray.new([0,0])
        moves_arr = []
        test_movement_methods { |var| moves_arr << marr.left(var).spaces }
        expect(moves_arr[0].length).to eq(1)
        expect(moves_arr[1].length).to eq(5)
        expect(moves_arr[2].length).to eq(3)
      end
    end

    describe "#right" do
      it "accepts an integer, range of integers or array of integers" do 
        marr = Movement::MovementArray.new([0,0])
        moves_arr = []
        test_movement_methods { |var| moves_arr << marr.right(var).spaces }
        expect(moves_arr[0].length).to eq(1)
        expect(moves_arr[1].length).to eq(5)
        expect(moves_arr[2].length).to eq(3)
      end
    end

    describe "#horizontally" do
      it "accepts an integer, range of integers or array of integers" do 
        marr = Movement::MovementArray.new([0,0])
        moves_arr = []
        test_movement_methods { |var| moves_arr << marr.horizontally(var).spaces }
        expect(moves_arr[0].length).to eq(2)
        expect(moves_arr[1].length).to eq(10)
        expect(moves_arr[2].length).to eq(6)
      end
    end

    describe "#vertically" do
      it "accepts an integer, range of integers or array of integers" do 
        marr = Movement::MovementArray.new([0,0])
        moves_arr = []
        test_movement_methods { |var| moves_arr << marr.vertically(var).spaces }
        expect(moves_arr[0].length).to eq(2)
        expect(moves_arr[1].length).to eq(10)
        expect(moves_arr[2].length).to eq(6)
      end
    end

    describe "#diagonally" do
      it "accepts an integer, range of integers or array of integers" do 
        marr = Movement::MovementArray.new([0,0])
        moves_arr = []
        test_movement_methods { |var| moves_arr << marr.diagonally(var).spaces }
        expect(moves_arr[0].length).to eq(4)
        expect(moves_arr[1].length).to eq(20)
        expect(moves_arr[2].length).to eq(12)
      end
    end

    describe "#and" do
      it "combines movements together to create a single movement" do
        marr = Movement::MovementArray.new([0,0])
        moves = marr.up(2).and.left(1).spaces
        expect(moves).to match_array [[-2, -1]]
      end
    end
  
    describe "#or" do
      it "separates movements from one another" do
        marr = Movement::MovementArray.new([0,0])
        moves = marr.up(2).and.left(1).or.down(1).and.right(2).spaces
        expect(moves).to match_array [[-2,-1], [1, 2]]
      end
    end

    describe "#spaces" do
      it "#ends a movement chain, returning an array" do
        marr = Movement::MovementArray.new([0,0])
        moves = marr.down(1).spaces
        expect(moves).to be_a_kind_of(Array)
      end
    end
  end
end


describe Pawn do
  
  describe "#special_moves" do
    it "returns an diagonally adjacent squares in front of it that have an enemy piece" do
      pawn = Pawn.new(team: "white", current_pos: [4,4])
      p2 = Pawn.new(team: "black", current_pos: [3,3])
      p3 = Knight.new(team: "black", current_pos: [3,5])

      board = return_filled_board([pawn, p2, p3])
      expect(pawn.special_moves(board)).to match_array [[3,3], [3,5]]
    end

    it "returns en passant if enemy piece moved next to pawn on last turn" do
      pawn = Pawn.new(team: "white", current_pos: [4,4])
      bishop = double("Bishop")
      bishop.stub( :moved_last_turn? => true )
      bishop.stub( :current_pos => [4,3] )
      bishop.stub( :team => "black" )
      board = return_filled_board([pawn,bishop])
      expect(pawn.special_moves(board)).to match_array [[3,3]]
    end
  end
end

describe King do

  describe "#special_moves" do
    it "returns the spaces that the king can move when castling is available" do
      king = King.new(team: "white", current_pos: [7, 4])
      rook = Rook.new(team: "white", current_pos: [7, 0])
      rook2 = Rook.new(team: "white", current_pos: [7, 7])
      board = return_filled_board([king, rook, rook2])
      castle_positions = [ [7, 2], [7, 6] ]
      expect(king.special_moves(board)).to match_array castle_positions
    end

    it "does not return a castle if king would be in check in any position in between" do
      king = King.new(team: "white", current_pos: [7,4])
      rook = Rook.new(team: "white", current_pos: [7,0])
      bishop = Bishop.new(team: "black", current_pos: [5,1])
      board = return_filled_board([king, rook, bishop])
      expect(king.special_moves(board)).to match_array []
    end
  end

end

