require 'spec_helper'
require 'player'

describe Player do
  describe "#initialize" do
    it "creates a new player with a team variable" do
      player = Player.new(name: "testing")
      expect(player.name).to eq("testing")
    end

    it "creates a new player with a name variable" do
      player = Player.new(team: "white")
      expect(player.team).to eq("white")
    end
  end
end
