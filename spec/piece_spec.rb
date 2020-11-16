require 'spec_helper'
require 'piece'

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
