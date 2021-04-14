require 'spec_helper'

#testing inheritance of Saveable
class SaveablePerson < Saveable

  attr_reader :name, :age, :favorites, :family
  def initialize(args = {})
    @name = args.fetch(:name, nil) || "John Smith"
    @age = args.fetch(:age, nil) || "27"
    @favorites = args.fetch(:favorites, nil) ||{ book: "A Clockwork Orange",
                                                 movie: "Zoolander",
                                                 number: 12,
                                                 music_genre: :rock }
    @family = args.fetch(:family, nil) || []
  end 
end

describe Saveable do
  let(:other_favorites) { { book: "To Kill a Mockingbird", movie: "Van Wilder", number: 6 } }
  let(:other) { SaveablePerson.new(name: "Jane Doe", age: "32", favorites: other_favorites) }

  describe "#to_json" do
    it "responds to :to_json with an optional hash parameter" do
      save = Saveable.new
      expect(save).to respond_to(:to_json).with(1).argument
    end

    it "returns a json string" do
      save = Saveable.new
      expect(save.to_json).to be_a_kind_of(String).and start_with("{").and end_with("}")
    end

    it "stores all class variable keys" do
      save = SaveablePerson.new
      json = save.to_json
      expect(json).to include("name").and include("age").and include("favorites").and include("family")
    end

    it "stores all class variable values" do
      save = SaveablePerson.new
      json = save.to_json
      expect(json).to include("John Smith").and include("27").and include(
        "\"book\":\"A Clockwork Orange\",\"movie\":\"Zoolander\",\"number\":12,\"music_genre\":\"rock\"").and include("[]")
    end

    it "stores a variable with the object's class" do
      save = SaveablePerson.new
      json = save.to_json
      expect(json).to include("\"class\":\"SaveablePerson\"")
    end

    it "stores the json of any Saveable object stored within itself" do
      save = SaveablePerson.new(family: [other])
      json = save.to_json
      other_json = JSON.load json.slice(/\[.*\]/)[1...-1] #get portion of json string between brackets and load string
      expect(other_json).to eq(other.to_json) #substring should be equal to other's json string
    end
  end

  describe "#from_json" do
    it "loads a Saveable object from a json string" do
      favorites = { :book => "Dune", :movie => "Zoolander", :number => 17 }
      save = SaveablePerson.new(favorites: favorites)
      json = save.to_json
      loaded = Saveable.from_json(json)
      expect(loaded).to be_a_kind_of(SaveablePerson).and have_attributes(:name => "John Smith", :age => 27, :favorites => favorites)
    end

    it "loads any Saveable objects stored within itself" do
      save = SaveablePerson.new(family: [other])
      json = save.to_json
      loaded = Saveable.from_json(json)
      loaded_other = loaded.family[0]
      expect(loaded_other).to be_a_kind_of(SaveablePerson).and have_attributes(:name => "Jane Doe", :age => 32, :favorites => other_favorites)
    end
  end
end

describe SaveHelper do
  let(:test_file_loc) { "./my_save_test.txt" }
  let(:test_data) { { board_state: "a", data: "b", title: "c" } }
  
  def save_data
      SaveHelper.class_variable_set(:@@file_loc, test_file_loc)
      File.open(test_file_loc, "a+") {}
      SaveHelper.save(test_data)
  end
  
  def delete_data
    if File.exists?(test_file_loc)
      File.delete(test_file_loc)
    end
  end

  describe "#save" do
    it "saves JSON data to a file specified in file_loc class var" do
      delete_data #in case the file remained from a previous test
      save_data

      json = Save.new(test_data).to_json
      #read saved_json from test_file and delete file
      saved_json = nil
      File.open(test_file_loc, "r") do |file|
        saved_json = file.readlines[0].chomp
      end  
      delete_data

      expect(saved_json).to eq(json)
    end
  end

  describe "#load_saves" do
    it "loads all saves from the file specified in file_loc class var" do
      save_data
      SaveHelper.load_saves
      loaded_save = SaveHelper.saves[0]
      test_save = Save.new(test_data)
      a_match = loaded_save.instance_variables.all? do |v|
        sym = :"#{v}"
        loaded_save_var = loaded_save.instance_variable_get(sym)
        test_save_var = test_save.instance_variable_get(sym)
        loaded_save_var == test_save_var
      end
      delete_data
      expect(a_match).to be true
    end
  end
end
