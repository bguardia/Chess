#require './lib/chess.rb'
require 'json'

class SaveHelper

  def initialize
    @file_loc = "./save.txt"
    @save_file = nil
    @saves = []
  end

  def load_save_file
    return true if @save_file
    if File.exists?(@file_loc)
      @save_file = File.open(@file_loc, "a+")
    end  
  end

  def close_save_file
    if @save_file
      @save_file.close
    end
  end

  def load_saves
    load_save_file
    @save_file.each do |line|
      @saves << Save.from_json(line)
    end
    close_save_file
  end

  def save(args)
    save = Save.new(args)
    load_save_file
    @save_file.puts save.to_json
    close_save_file
  end

  def to_s
    str = ""
    num = 1
    @saves.each do |save|
      str += "#{num}. #{save}"
      num += 1
    end

    return str
  end

end

class Save

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

  def self.from_json(json)
    data = JSON.load json
    data.transform_keys!(&:to_sym)
    self.new(data)
  end

  def to_json
    JSON.dump({ "date" => @date,
                "board_state" => @board_state,
                "title" => @title,
                "data" => @data })
  end

  def to_s
    
    str += "#{@board_state[0]}     #{@title}    \n" +
           "#{@board_state[1]}     #{@date}       \n" +
    @board_state[2..-1].each do |line|
      str += "#{line}\n"
    end

    return str
  end

  def load
    
  end
end

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
      $game_debug += "Called #{self.class}.to_h\n"
      serialized = instance_variables.map do |iv|
        unless ignore_on_serialization.include?(iv.to_s)
          val = instance_variable_get(iv)
          $game_debug += "instance_var: #{iv}, val: #{val.to_s[0..9]}\n"
          [
            iv.to_s[1..-1],
            case val
            when Saveable then val.to_h
            when Array 
              handle_array(val)
            else val
            end
          ]
        else
          nil
        end
      end.compact.to_h.merge({ "class" => self.class })

      @@saved_objects[self] = serialized
      $game_debug += "Leaving #{self.class}.to_h\n"
      return serialized
    end
  end

  def handle_array(arr)
    arr.map do |e|
      if e.kind_of?(Array)
        handle_array(e)
      else
        e.respond_to?(:to_h) ? e.to_h : e
      end
    end
  end

  def to_json(options = {})
    JSON.generate(self.to_h, options)
  end

  def self.from_json(json_str)
    data = JSON.load json_str

    data.transform_keys!(&:to_sym)
    
    self.new(data)
  end
end

