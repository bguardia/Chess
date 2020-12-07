require 'spec_helper'



describe ChessNotation do
  include ChessNotation

  describe "#to_notation" do
    it "returns the chess notation of the move given for a particular board" do
      board = Board.new
      piece = Pawn.new(team: "white", starting_pos: [6,3])
      piece.add_to_board(board)

      expect(ChessNotation.to_notation([6,3], [4,3], board)).to eq("d4")
    end

    it "returns castle notation when appropriate" do
      board = Board.new
      king = King.new(team: "black", starting_pos: [0,4])
      rook = Rook.new(team: "black", starting_pos: [0,7])
      [king, rook].each { |p| p.add_to_board(board) }

      expect(ChessNotation.to_notation([0,4], [0,6], board)).to eq("O-O")
    end

    it "returns queenside castle when appropriate" do
      board = Board.new
      king = King.new(team: "black", starting_pos: [0,4])
      rook = Rook.new(team: "black", starting_pos: [0,0])
      [king, rook].each { |p| p.add_to_board(board) }

      expect(ChessNotation.to_notation([0,4], [0,2], board)).to eq("O-O-O")
    end

    it "returns notation with clarifying value when necessary" do
      board = Board.new
      p1 = Knight.new(team:"white", starting_pos: [5,2])
      p2 = Knight.new(team:"white", starting_pos: [1,4])
      [p1, p2].each { |p| p.add_to_board(board) }
      expect(ChessNotation.to_notation([1,4], [3,3], board)).to eq("N7d5")
    end
  end

  describe "#from_notation" do
    context "with valid input" do
      it "returns a hash" do 
        board = Board.new
        piece = Pawn.new(team: "black", starting_pos: [1, 4])
        piece.add_to_board(board)
        expect(ChessNotation.from_notation("e6", board)).to be_a_kind_of(Hash)
      end
    end

    context "with multiple piece choices" do
      it "returns the correct piece when given a clarifying file" do
        board = Board.new
        p1 = Knight.new(team:"white", starting_pos: [5,2])
        p2 = Knight.new(team:"white", starting_pos: [5,4])
        [p1, p2].each { |p| p.add_to_board(board) }
        expect(ChessNotation.from_notation("Ncd5", board)[:piece]).to be(p1)
      end

      it "returns the correct piece when given a clarifying rank" do
        board = Board.new
        p1 = Knight.new(team:"white", starting_pos: [5,2])
        p2 = Knight.new(team:"white", starting_pos: [1,4])
        [p1, p2].each { |p| p.add_to_board(board) }
        expect(ChessNotation.from_notation("N7d5", board)[:piece]).to be(p2)
      end
    end

    context "with invalid input" do
      it "returns nil when an empty string is given" do
        board = Board.new
        piece = Pawn.new(team: "black", starting_pos: [1, 4])
        piece.add_to_board(board)
        expect(ChessNotation.from_notation("", board)).to be_nil
      end
    end
  end
end

