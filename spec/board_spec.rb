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
      piece = Pawn.new(team: "white", starting_pos: [1,4]) 
      board.place(piece, [0,0])
      expect(board.arr[0][0]).to eq(piece)
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

    it "doesn't change object_id of array" do
      board = Board.new
      piece = double("Piece")
      fill(board, piece)
      original_arr = board.arr
      board.clear
      expect(original_arr.object_id).to eq(board.arr.object_id)
    end
  end
end

