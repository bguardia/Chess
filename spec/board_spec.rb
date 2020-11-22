require 'spec_helper'
require 'board'
require 'piece'

describe Board do
  def fill(board, piece)
    x = 0
    y = 0

    8.times do
      8.times do
        board.arr[x][y] = piece
        y += 1
      end
      x += 1
    end

  end

  describe "#initialize" do
    context "without arguments" do
      it "creates a 2D, 8x8 array" do
        board = Board.new
        test_arr = Array.new(8) { Array.new(8) }
        expect(board.arr).to match_array test_arr
      end
    end
  end

  describe "#place" do
    it "puts target object at the given position in the board arr" do
      board = Board.new
      piece = double("Piece")
      board.place(piece, [0,0])
      expect(board.arr[0][0]).to eq(piece)
    end
  end

  describe "#get_pieces" do
    context "without arguments" do
      it "returns all pieces on the board" do
        i = 0
        pawns = []
        board = Board.new
        8.times { pawns << Pawn.new }
        pawns.each { |p| board.place(p, [6, i]); i += 1 }

        expect(board.get_pieces).to match_array pawns
      end
    end

    context "with arguments" do
      it "only returns pieces that match arguments" do
        pawns, white_pawns, black_pawns = [], [], []
        4.times { white_pawns << Pawn.new(team: "white") }
        4.times { black_pawns << Pawn.new(team: "black") }
        pawns = pawns.concat(white_pawns, black_pawns)
        board = Board.new
        
        i = 0
        pawns.each { |p| board.place(p, [4, i]); i += 1 }

        expect(board.get_pieces(team: "white")).to match_array white_pawns
      end
    end
  end

  describe "#move" do
    it "moves an existing object from its previous position to target position" do
      board = Board.new
      piece = double("Piece")
      board.place(piece, [0,0])
      board.move(piece, [3,3])
      expect(board.arr[0][0]).to be_nil
      expect(board.arr[3][3]).to eq(piece)
    end
  end

  describe "#clear" do
    it "resets the board's array" do
      board = Board.new
      piece = double("Piece")
      fill(board, piece)
      board.clear
      empty_arr = Array.new(8) { Array.new(8, nil) }
      expect(board.arr).to match_array empty_arr
    end
  end
end
