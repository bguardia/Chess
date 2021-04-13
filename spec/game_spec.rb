require 'spec_helper'
require 'game'

describe Game do

  describe "#initialize" do
    context "without arguments" do
      it "creates a game object with an array called players" do
        game = Game.new
        expect(game.players).to be_an_instance_of(Array)
      end

      it "creates a board object" do
        game = Game.new
        expect(game.board).to be_an_instance_of(Board)
      end
    end
  end

  describe "#play" do
    
  end

  describe "#save" do
    let(:save_helper) { class_double("SaveHelper").as_stubbed_const(:transfer_nested_constants => true) }
    it "sends a save message to the SaveHelper class" do
      expect(save_helper).to receive(:save)
      game = Game.new
      game.save
    end

    it "with a hash containing :title, :data and :board_state keys" do
      contains_appropriate_keys = nil
      allow(save_helper).to receive(:save) do |args|
        contains_appropriate_keys = args.has_key?(:title) && args.has_key?(:board_state) && args.has_key?(:data)
      end

      game = Game.new
      game.save
      
      expect(contains_appropriate_keys).to be true
    end
  end

  describe "#load" do
    let(:notation) { ["e4", "e5"] }
    let(:players) { [Player.new(name: "Timmy", team: "white"), Player.new(name: "Jimmy", team: "black")] }
    let(:game) { Game.new() }
    it "loads a game from a hash containing players and notation keys" do
      game.load(players: players, notation: notation)
    end

    it "loads players properly" do
      game.load(players: players, notation: notation)
      expect(game.players).to eq(players)
    end

    it "loads moves properly" do
      game.load(players: players, notation: notation)
      board = game.board
      piece1 = board.get_piece_at([4, 4]) #e4
      piece2 = board.get_piece_at([3, 4]) #e5
      expect([piece1, piece2]).to satisfy { |a| a.all? { |p| p.kind_of?(Piece) } }
    end
  end

end
