require 'spec_helper'
require 'board'
require 'piece'

def get_full_piece_set
  return Pieces.new_set("white").concat(Pieces.new_set("black"))
end

def get_full_piece_hash
  pieces = get_full_piece_set
  piece_hash = {}
  pieces.each do |p|
    piece_hash[p] = { :pos => p.starting_pos }
  end
  return piece_hash
end

describe State do
  describe "#initialize" do
    it "can be initiated with an array of piece objects" do
      pieces = get_full_piece_set
      state = State.new(pieces: pieces)
    end

    it "can also be initiated with a piece hash" do
      piece_hash = get_full_piece_hash
      state = State.new(pieces: piece_hash)
    end
  end

  describe "#do" do
    it "takes a move as a parameter and returns the resulting state" do
      p1 = Pawn.new(team: "white", starting_pos: [3,3])
      p2 = Pawn.new(team: "black", starting_pos: [2,4])
      state = State.new(pieces: [p1, p2])
      move = Move.new(move: [[p1, [3,3],[2,4]],[p2, [2,4], nil]])
      next_state = state.do(move)
      expect(next_state.get_pos(p1)).to eq([2,4])
    end
  end

  describe "#get_pieces" do
    it "returns all pieces if no arguments are given" do
      pieces = get_full_piece_set
      state = State.new(pieces: pieces)
      got_pieces = state.get_pieces
      expect(got_pieces).to eq(pieces)
    end

    it "returns only pieces with given 'team' argument" do
      pieces = get_full_piece_set
      state = State.new(pieces: pieces)
      white_pieces = pieces.filter { |p| p.team == "white" }
      got_pieces = state.get_pieces(team: "white")
      expect(got_pieces).to eq(white_pieces)
    end

    it "returns only pieces with given 'type' argument" do
      pieces = get_full_piece_set
      state = State.new(pieces: pieces)
      pawns = pieces.filter { |p| p.kind_of?(Pawn) }
      got_pieces = state.get_pieces(type: "Pawn")
      expect(got_pieces).to eq(pawns)
    end

    it "returns only pieces that match multiple filters" do
      pieces = get_full_piece_set
      state = State.new(pieces: pieces)
      black_pieces = pieces.filter { |p| p.team == "black" }
      black_knights = black_pieces.filter { |p| p.kind_of?(Knight) }
      got_pieces = state.get_pieces(team: "black", type: "Knight")
      expect(got_pieces).to eq(black_knights)
    end
  end

  describe "#get_moves" do
    it "returns an array of all moves from state" do
      pieces = get_full_piece_set
      state = State.new(pieces: pieces)
      moves = state.get_moves
      expect(moves.length).to eq(106) #includes blocked moves
    end

    it "returns only moves of pieces that match given parameters" do
      pieces = get_full_piece_set
      state = State.new(pieces: pieces)
      black_pieces = pieces.filter { |p| p.team == "black" }
      got_moves =  state.get_moves(team: "black", type: "Knight")
      expect(got_moves.length).to eq(4)
    end
  end

  describe "#in_check?" do
    it "returns true if king is in check" do
      king = King.new(team: "white", starting_pos: [1,1])
      queen = Queen.new(team: "black", starting_pos: [1,5])
      state = State.new(pieces: [king, queen])
      expect(state.in_check?(king: king)).to be true 
    end

    it "returns false if king is not in check" do
      king = King.new(team: "white", starting_pos: [1,1])
      queen = Queen.new(team: "black", starting_pos: [2,5])
      state = State.new(pieces: [king, queen])
      expect(state.in_check?(king: king)).to be false
    end
  end

  describe "#checkmate?" do
    it "returns true if checkmate" do
      king = King.new(team: "white", starting_pos: [7,7])
      queen = Queen.new(team: "black", starting_pos: [6,5])
      bishop = Bishop.new(team: "black", starting_pos: [5,5])
      state = State.new(pieces: [king, queen, bishop])
      expect(state.checkmate?("white")).to be true
    end

    it "returns false if king can escape" do
      king = King.new(team: "white", starting_pos: [7,7])
      rook = Rook.new(team: "black", starting_pos: [7,5])
      state = State.new(pieces: [king, rook])
      expect(state.checkmate?("white")).to be false
    end

    it "returns false if king can escape through capture" do
      king = King.new(team: "white", starting_pos: [7,7])
      queen = Queen.new(team: "black", starting_pos: [6,6])
      state = State.new(pieces: [king, queen])
      expect(state.checkmate?("white")).to be false
    end

    it "returns false if ally piece can capture attacker" do
      king = King.new(team: "white", starting_pos: [7,7])
      pawn = Pawn.new(team: "white", starting_pos: [6,7])
      rook = Rook.new(team: "black", starting_pos: [7,5])
      queen = Queen.new(team: "white", starting_pos: [5,5])
      state = State.new(pieces: [king, pawn, rook, queen])
      expect(state.checkmate?("white")).to be false
    end
  end
end

describe StateTree do
  describe "#initialize" do
    it "takes an array of :pieces and creates a new StateTree" do
      pieces = get_full_piece_set
      statetree = StateTree.new(pieces: pieces)
    end
  end

  describe "#do" do
    it "applies a move to a copy of statetree and returns it" do
      pieces = get_full_piece_set
      statetree = StateTree.new(pieces: pieces)
      p1 = statetree.get_pieces(type: "Pawn")[0]
      move = statetree.get_moves(id: p1.id)[0]
      next_tree = statetree.do(move)
      expect(next_tree).to be_a(StateTree)
    end
  end

  describe "#do!" do
    it "applies a move to itself" do
      pieces = get_full_piece_set
      statetree = StateTree.new(pieces: pieces)
      p1 = statetree.get_pieces(type: "Pawn")[0]
      move = statetree.get_moves(id: p1.id)[0]
      prev_state = statetree.current_node
      statetree.do!(move)
      current_state = statetree.current_node
      expect(current_state).not_to eq(prev_state) 
    end
  end

  describe "#undo" do
    it "returns to the state before the last move" do
      pieces = get_full_piece_set
      statetree = StateTree.new(pieces: pieces)
      p1 = statetree.get_pieces(type: "Pawn")[0]
      move = statetree.get_moves(id: p1.id)[0]
      prev_state = statetree.current_node
      statetree.do!(move)
      statetree.undo
      current_state = statetree.current_node
      expect(current_state).to eq(prev_state) 
    end
  end
end
