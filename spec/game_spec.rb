require 'spec_helper'
require 'game'

describe Game do

  describe "#initialize" do
    context "without arguments" do
      it "creates a game object with an array called players" do
        game = Game.new
        expect(game.players).to be_an_instance_of(Array)
      end

      it "creates an array that contains sets of pieces" do
        game = Game.new
        expect(game.sets).to be_an_instance_of(Array)
      end

      it "creates a board object" do
        game = Game.new
        expect(game.board).to be_an_instance_of(Board)
      end
    end
  end

  describe "#game_over?" do
  
  end

  describe "#save" do
  end


end
