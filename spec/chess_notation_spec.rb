require 'spec_helper'



describe ChessNotation do
  include ChessNotation

  describe "#move_to_notation" do
    it "returns the chess notation of the move given for a particular board" do
      piece = Pawn.new(team: "white", starting_pos: [6,3])
      state = StateTree.new(pieces: [piece])
      move = Move.new(move: [[piece, [6,3], [4,3]]])

      expect(ChessNotation.move_to_notation(move, state)).to eq("d4")
    end

    it "returns castle notation when appropriate" do
      king = King.new(team: "black", starting_pos: [0,4])
      rook = Rook.new(team: "black", starting_pos: [0,7])
      state = StateTree.new(pieces: [king, rook])
      move = Move.new(move: [[king, [0,4], [0,6]], [rook, [0,7], [0,5]]], type: :castle)
      expect(ChessNotation.move_to_notation(move, state)).to eq("O-O")
    end

    it "returns queenside castle when appropriate" do
      board = Board.new
      king = King.new(team: "black", starting_pos: [0,4])
      rook = Rook.new(team: "black", starting_pos: [0,0])
      state = StateTree.new(pieces: [king, rook])
      move = Move.new(move: [[king, [0,4], [0,2]], [rook, [0,7], [0,3]]], type: :castle)
      expect(ChessNotation.move_to_notation(move, state)).to eq("O-O-O")
    end

    it "returns notation with clarifying value when necessary" do
      p1 = Knight.new(team:"white", starting_pos: [5,1]) #b3
      p2 = Knight.new(team:"white", starting_pos: [6,4]) #e2
      state = StateTree.new(pieces: [p1, p2])
      move = Move.new(move: [[p1, [5,1], [4,3]]])
      state.do!(move)
      possible_notes = ["N3d4", "Nbd4"]
      note = ChessNotation.move_to_notation(move, state)
      expect(possible_notes).to include(note)
    end
  end

  describe "#from_notation" do
    context "with valid input" do
      it "returns a move object" do 
        piece = Pawn.new(team: "black", starting_pos: [1, 4])
        state = StateTree.new(pieces: [piece])
        expect(ChessNotation.from_notation("e6", state)).to be_a_kind_of(Move)
      end
    end

    context "with multiple piece choices" do
      it "returns the correct piece when given a clarifying file" do
        p1 = Knight.new(team:"white", starting_pos: [5,2]) #c3
        p2 = Knight.new(team:"white", starting_pos: [5,4]) #e3
        state = StateTree.new(pieces: [p1, p2])
        move = ChessNotation.from_notation("Ncd5", state)
        moving_piece = move.get_piece
        expect(moving_piece).to be(p1)
      end

      it "returns the correct piece when given a clarifying rank" do
        p1 = Knight.new(team:"white", starting_pos: [5,2]) #c4
        p2 = Knight.new(team:"white", starting_pos: [1,4]) #e7
        state = StateTree.new(pieces: [p1, p2])
        move = ChessNotation.from_notation("N7d5", state)
        moving_piece = move.get_piece
        expect(moving_piece).to be(p2)
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

