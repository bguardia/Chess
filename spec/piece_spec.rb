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

describe Movement do
  include Movement

  describe "#from" do
    it "creates and returns a new Movement::MovementArray" do
      marr = from([0,0])
      expect(marr).to be_a_kind_of(Movement::MovementArray)
    end
  end

  describe Movement::MovementArray do
    
  
    describe "#initialize" do
      it "creates a new MovementArray with a given starting coordinate" do
        some_coords = [1,5]
        marr = Movement::MovementArray.new(some_coords)
        expect(marr).to have_attributes( :origin => some_coords )
      end
    end
    
    def test_movement_methods
      yield 2
      yield 1..5
      yield [1, 3, 5]
    end

    describe "#up" do
      it "accepts an integer, range of integers or array of integers" do
        marr = Movement::MovementArray.new([0,0])
        moves_arr = []
        test_movement_methods { |var| moves_arr << marr.up(var).spaces }
        expect(moves_arr[0].length).to eq(1)
        expect(moves_arr[1].length).to eq(5)
        expect(moves_arr[2].length).to eq(3)
      end
    end

    describe "#down" do
      it "accepts an integer, range of integers or array of integers" do
        marr = Movement::MovementArray.new([0,0])
        moves_arr = []
        test_movement_methods { |var| moves_arr << marr.down(var).spaces }
        expect(moves_arr[0].length).to eq(1)
        expect(moves_arr[1].length).to eq(5)
        expect(moves_arr[2].length).to eq(3)
      end
    end

    describe "#left" do
      it "accepts an integer, range of integers or array of integers" do 
        marr = Movement::MovementArray.new([0,0])
        moves_arr = []
        test_movement_methods { |var| moves_arr << marr.left(var).spaces }
        expect(moves_arr[0].length).to eq(1)
        expect(moves_arr[1].length).to eq(5)
        expect(moves_arr[2].length).to eq(3)
      end
    end

    describe "#right" do
      it "accepts an integer, range of integers or array of integers" do 
        marr = Movement::MovementArray.new([0,0])
        moves_arr = []
        test_movement_methods { |var| moves_arr << marr.right(var).spaces }
        expect(moves_arr[0].length).to eq(1)
        expect(moves_arr[1].length).to eq(5)
        expect(moves_arr[2].length).to eq(3)
      end
    end

    describe "#horizontally" do
      it "accepts an integer, range of integers or array of integers" do 
        marr = Movement::MovementArray.new([0,0])
        moves_arr = []
        test_movement_methods { |var| moves_arr << marr.horizontally(var).spaces }
        expect(moves_arr[0].length).to eq(2)
        expect(moves_arr[1].length).to eq(10)
        expect(moves_arr[2].length).to eq(6)
      end
    end

    describe "#vertically" do
      it "accepts an integer, range of integers or array of integers" do 
        marr = Movement::MovementArray.new([0,0])
        moves_arr = []
        test_movement_methods { |var| moves_arr << marr.vertically(var).spaces }
        expect(moves_arr[0].length).to eq(2)
        expect(moves_arr[1].length).to eq(10)
        expect(moves_arr[2].length).to eq(6)
      end
    end

    describe "#diagonally" do
      it "accepts an integer, range of integers or array of integers" do 
        marr = Movement::MovementArray.new([0,0])
        moves_arr = []
        test_movement_methods { |var| moves_arr << marr.diagonally(var).spaces }
        expect(moves_arr[0].length).to eq(4)
        expect(moves_arr[1].length).to eq(20)
        expect(moves_arr[2].length).to eq(12)
      end
    end

    describe "#and" do
      it "combines movements together to create a single movement" do
        marr = Movement::MovementArray.new([0,0])
        moves = marr.up(2).and.left(1).spaces
        expect(moves).to match_array [[-2, -1]]
      end
    end
  
    describe "#or" do
      it "separates movements from one another" do
        marr = Movement::MovementArray.new([0,0])
        moves = marr.up(2).and.left(1).or.down(1).and.right(2).spaces
        expect(moves).to match_array [[-2,-1], [1, 2]]
      end
    end

    describe "#spaces" do
      it "#ends a movement chain, returning an array" do
        marr = Movement::MovementArray.new([0,0])
        moves = marr.down(1).spaces
        expect(moves).to be_a_kind_of(Array)
      end
    end
  end
end
