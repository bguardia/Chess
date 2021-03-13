#require './lib/chess.rb'
require 'json'

class Saveable

  @@saved_objects = {}
  @@loaded_objects = {}

  def saved_objects
    @@saved_objects 
  end

  def loaded_objects
    @@loaded_objects
  end

  #put names of instance variables to be ignored on serialization
  def ignore_on_serialization
    []
  end

  def to_h
    if @@saved_objects.has_key?(self)
      @@saved_objects[self]
    else
      #$game_debug += "Called #{self.class}.to_h\n"
      serialized = instance_variables.map do |iv|
        unless ignore_on_serialization.include?(iv.to_s)
          val = instance_variable_get(iv)
          #$game_debug += "instance_var: #{iv}, val: #{val.to_s[0..9]}\n"
          [
            iv.to_s[1..-1],
            save_delegate(val)
          ]
        else
          nil
        end
      end.compact.to_h.merge({ "class" => self.class })

      @@saved_objects[self] = serialized
      #$game_debug += "Leaving #{self.class}.to_h\n"
      return serialized
    end
  end

  def handle_array(arr)
    arr.map do |val|
      save_delegate(val)
    end
  end

  def save_delegate(val)
    case val
    when Saveable then val.to_json
    when Array then handle_array(val)
    when Hash then handle_hash(val)
    else val
    end
  end

  def handle_hash(h)
    h.transform_values! do |val|
      save_delegate(val)
    end

    h.transform_keys! do |val|
      save_delegate(val)
    end

    return h
  end

  def self.load_array(arr)
    arr.map do |e|
      Saveable.load_delegate(e)
    end 
  end 

  def self.load_hash(h)
    h.transform_values! do |val|
      Saveable.load_delegate(val)
    end

    h.transform_keys! do |key|
      new_key = Saveable.load_delegate(key)
      if new_key.kind_of?(String) 
        new_key.to_sym
      else
        new_key
      end
    end
  end

  def self.load_delegate(val)
      case val
      when Hash
        if val.has_key?("class")
          Saveable.load(val) #Create object from hash
        else
          Saveable.load_hash(val) #Iterate through hash
        end
      when Array then Saveable.load_array(val) #Iterate through Array
      when String
        if Saveable.is_json?(val)
          Saveable.from_json(val) #load json string
        else
          val
        end
      else val
      end
  end

  def self.is_json?(str)
    return false unless str.kind_of?(String)
    return true if str[0] == "{" && str[-1] == "}"
    return true if str[0] == "[" && str[-1] == "]"
  end

  def to_json(options = {})
    JSON.generate(self.to_h, options)
  end

  def self.from_json(json_str)
    #$game_debug += "Called Saveable.from_json\n"
    data = JSON.load json_str
    #$game_debug += "Data is:\n #{data}\n"
    Saveable.load(data) 
  end

  def self.load(data)
    #$game_debug += "Called Saveable.load\n Data is:\n #{data}\n"
    if @@loaded_objects.has_key?(data)
      @@loaded_objects[data]
    else
      data.transform_values! do |val|
        Saveable.load_delegate(val)
      end.transform_keys!(&:to_sym)
   
      if data.has_key?(:class)
        clz = Kernel.const_get(data[:class])
      else
        clz = self.class
      end

      loaded = clz.new(data)
      @@loaded_objects[data] = loaded
      return loaded
      #$game_debug += "Loaded object: \n #{loaded}\n"
    end
  end
end

module SaveHelper

  @@file_loc = "./my_save.txt"
  @@save_file = nil
  @@saves = []

  def self.saves
    @@saves
  end

  def self.load_save_file
    return true if @@save_file
    @@save_file = File.open(@@file_loc, "a+")
  end

  def self.close_save_file
    if @@save_file
      @@save_file.close
      @@save_file = nil
    end
  end

  def self.load_saves
    self.load_save_file
    self.clear_saves
    @@save_file.each do |line|
      @@saves << Save.from_json(line)
    end
    self.close_save_file
  end

  def self.save(args)
    save = Save.new(args)
    self.load_save_file
    @@save_file.puts save.to_json
    self.close_save_file
  end

  def self.clear_saves
    @@saves = []
  end

  def self.to_s
    str = ""
    num = 1
    @@saves.each do |save|
      str += "#{num}. #{save}"
      num += 1
    end

    return str
  end

end

class Save < Saveable

  attr_reader :data

  def initialize(args)
    @date = args.fetch(:date, false) || set_date
    @board_state = args.fetch(:board_state)
    @data = args.fetch(:data) 
    @title = args.fetch(:title)
  end

  def set_date
    time = Time.now
    date_str = "#{time.year}/#{time.month}/#{time.day} #{time.hour}:#{time.min}:#{time.sec}"
  end

  def to_s
    board_arr = @board_state.split("\n")    
    str = "#{board_arr[0]}     #{@title}    \n" +
           "#{board_arr[1]}     #{@date}       \n" 
    board_arr[2..-1].each do |line|
      str += "#{line}\n"
    end

    return str
  end

end


