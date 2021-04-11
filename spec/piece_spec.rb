require 'spec_helper'
require 'piece'
require 'board'


def return_filled_board(pieces)
  state = State.new(pieces: pieces)
  return state
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
  

  describe "#moves" do
    it "creates and returns a new Movement::MovementArray" do
      pawn = create_piece_stub
      state = State.new(pieces: [pawn])
      marr = moves(pawn, state)
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
      board = return_filled_board(pieces) 
      expect(Movement.who_can_reach?(dest, board)).to match_array pieces
    end
  end

   describe "#blocked?" do
     it { expect(Movement).to respond_to(:blocked?).with(3).arguments }
     it "returns true if a space between piece and destination is occupied" do
       rook = create_piece_stub(type: "Rook", pos: [7,0])
       queen = create_piece_stub(type: "Queen", pos: [5,0])
       dest = [4,0]
       board = return_filled_board([rook, queen])
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
   
    def test_movement_methods(msg, pos = [0,0], ans_arr = [1,5,3])
      piece = create_piece_stub(pos: pos)
      board = State.new(pieces: [piece]) 
      marr = Movement::MovementArray.new(piece, board)
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
        test_movement_methods(:up, [7,3])
      end
    end

    describe "#down" do
      it "accepts an integer, range of integers or array of integers" do
        test_movement_methods(:down, [0,3])
      end
    end

    describe "#left" do
      it "accepts an integer, range of integers or array of integers" do 
        test_movement_methods(:left, [3,7])
      end
    end

    describe "#right" do
      it "accepts an integer, range of integers or array of integers" do 
        test_movement_methods(:right, [3,0])
      end
    end

    describe "#horizontally" do
      it "accepts an integer, range of integers or array of integers" do 
        test_movement_methods(:horizontally, [3,3], [2, 7, 4])
      end
    end

    describe "#vertically" do
      it "accepts an integer, range of integers or array of integers" do 
        test_movement_methods(:vertically, [3,3], [2, 7, 4])
      end
    end

    describe "#diagonally" do
      it "accepts an integer, range of integers or array of integers" do 
        test_movement_methods(:diagonally, [3,3], [4, 13, 8])
      end
    end

    describe "#and" do
      it "combines movements together to create a single movement" do
        piece = create_piece_stub(pos: [7,7])
        board = State.new(pieces: [piece])
        marr = Movement::MovementArray.new(piece, board)
        moves = marr.up(2).and.left(1).spaces(on_board: false)
        expect(moves).to match_array [[5, 6]]
      end
    end
  
    describe "#or" do
      it "separates movements from one another" do
        piece = create_piece_stub(pos: [3,3])
        board = State.new(pieces: [piece])
        marr = Movement::MovementArray.new(piece, board)
        moves = marr.up(2).and.left(1).or.down(1).and.right(2).spaces(on_board: false)
        expect(moves).to match_array [[1,2], [4, 5]]
      end
    end

    describe "#spaces" do
      it "#ends a movement chain, returning an array" do
        piece = create_piece_stub
        board = State.new(pieces: [piece])
        marr = Movement::MovementArray.new(piece, board)
        moves = marr.down(1).spaces
        expect(moves).to be_a_kind_of(Array)
      end
    end
  end

  describe "#en_passant" do
    it "returns en_passant moves when applicable" do
      p1 = Pawn.new(team: "white", starting_pos: [6,4]) 
      p2 = Pawn.new(team: "black", starting_pos: [1,5]) 
      statetree = StateTree.new(pieces:[p1, p2])
      move1 = Move.new(move: [[p1, [6, 4], [4,4]]])
      move2 = Move.new(move: [[p1, [4,4], [3,4]]])
      move3 = Move.new(move: [[p2, [1,5], [3,5]]])
      statetree.do!(move1)
      statetree.do!(move2)
      statetree.do!(move3)
      got_move = en_passant(p1, statetree)
      expect(got_move.length).to eq(1)
    end
  end

  describe "#castling" do
    it "returns the spaces that the king can move when castling is available" do
      king = create_piece_stub(type: "King", team: "white", pos: [7, 4])
      rook = create_piece_stub(type: "Rook", team: "white", pos: [7, 0])
      rook2 = create_piece_stub(type: "Rook", team: "white", pos: [7, 7])
      board = State.new(pieces: [king, rook, rook2])
      expect(castling(king, board).length).to eq(2) 
    end

    it "does not return a castle if king would be in check in any position in between" do
      king = create_piece_stub(type: "King", team: "white", pos: [7,4])
      rook = create_piece_stub(type: "Rook", team: "white", pos: [7,0])
      bishop = create_piece_stub(type: "Bishop", team: "black", pos: [5,1])
      board = State.new(pieces: [king, rook, bishop])
      expect(castling(king, board)).to match_array []
    end
  end
end
