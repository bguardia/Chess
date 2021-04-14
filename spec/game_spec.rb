require 'spec_helper'
require 'game'

describe Game do

   let (:white) { Player.new(team: "white") }
   let (:black) { Player.new(team: "black") }
   let (:interactive) { x = double("InteractiveScreen") 
                        allow(x).to receive(:update)       
                        allow(x).to receive(:get_input)
                        allow(x).to receive(:close)
                        x    }
   let (:game) { g = Game.new(players: [white, black], current_player: white)
                 g.set_ui(io_stream: interactive, move_history_input: [], turn_display_input: [], message_input: []) 
                 g }

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
   it "loops until checkmate is reached" do
     #passes two moves each to game to get fastest possible checkmate. :banana should not be passed
     #if checkmate isn't recognized, game will throw an error due to invalid input
     allow(white).to receive(:get_input).and_return("g4", "f3", :banana)
     allow(black).to receive(:get_input).and_return("e6", "Qh4")
     game.play
     #after game exits, get_input should return :banana
     expect(white.get_input({})).to be :banana 
   end 
  end

  describe "#player_turn" do
    it "gets input from the current player" do
      allow(white).to receive(:get_input).and_return("e4")
      expect(white).to receive(:get_input)
      game.player_turn
    end

    it "loops if valid input isn't received" do
      #player_turn should loop until it receives an appropriate value: "e4", then exit
      allow(white).to receive(:get_input).and_return("hello", "how are you?", "I'm fine", "e4", :banana)
      game.player_turn
      expect(white.get_input({})).to be :banana
    end

    it "preemptively quits if @break_game_loop is true" do
      #white will return "e4", but player_turn should break and exit due to break_game_loop being true
      allow(white).to receive(:get_input).and_return("e4")
      game.break_game_loop
      game.player_turn
      at_e4 = game.board.get_piece_at([4,4])
      expect(at_e4).not_to be_a_kind_of(Piece)
    end 
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
