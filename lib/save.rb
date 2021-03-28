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

  @@max_saves = 3
  @@file_loc = "./my_save.txt"
  @@save_file = nil
  @@saves = []

  def self.saves
    @@saves
  end

  def self.num_saves
    if @@saves.empty?
      self.load_save_file
      self.load_saves
      self.close_save_file
    end

    @@max_saves - @@saves.count { |sv| sv.kind_of?(EmptySave) }
  end

  def self.load_save_file(fmode = "r+")
    return true if @@save_file
    @@save_file = File.open(@@file_loc, fmode)
  end

  def self.close_save_file
    if @@save_file
      @@save_file.close
      @@save_file = nil
    end
  end

  def self._load_saves
    @@save_file.each do |line|
      @@saves << Save.from_json(line)
    end
    (@@max_saves - @@saves.length).times do
      @@saves << EmptySave.new
    end
  end

  #public version of method
  def self.load_saves
    self.load_save_file
    self.clear_saves
    self._load_saves
    self.close_save_file
  end

  def self.save(args)
    save = Save.new(args)
    self.load_saves

    if self.num_saves >= @@max_saves
      self.full_save_prompt
    end

    i = @@saves.find_index { |el| el.kind_of?(EmptySave) }
    $game_debug += "@@saves.find_index { |el| el.kind_of?(EmptySave) } = #{i}\n"
    unless i.nil?
      @@saves[i] = save
      saves_str = @@saves.map { |save| save.to_json }.join("\n")
      $game_debug += "@@saves:\n#{@@saves}\n"
      File.open(@@file_loc, "w") { |f| f.puts saves_str }
    end
    self.close_save_file
  end

  def self.full_save_prompt
      p = 2
      h = 19 + p * 2
      w = 40 + p * 2
      t = (Curses.lines - h) / 2
      l = (Curses.cols - w) / 2
      args = { padding: 2,
               height: h,
               width: w,
               top: t,
               left: l }

      loop do
        quit_without_save_bool = false
        delete_save_bool = false

        confirm_win = WindowTemplates.confirmation_screen(args.merge(title: "No Save Data Remaining", content: "There are no save files remaining. Would you like to delete a save and write over it?"))
        confirm_win.update
        delete_save_bool = InputHandler.new(in: confirm_win).get_input
        $game_debug += "delete_save_bool is: #{delete_save_bool}\n"

        if delete_save_bool == 1
          save_strs = @@saves.map { |save| save.to_s }
          save_menu = WindowTemplates.save_menu(title: "Delete Save", content: save_strs)
          save_menu.update
          save_to_delete = InputHandler.new(in: save_menu).get_input
          $game_debug += "save_to_delete: #{save_to_delete}\n"
          unless save_to_delete.nil?
            self.delete_save(save_to_delete)
          else
            delete_save_bool = false
          end
        end

        unless delete_save_bool
          confirm_win = WindowTemplates.confirmation_screen(args.merge(content: "Are you sure you want to quit the game without saving?"))
         confirm_win.update
         quit_without_save_bool = InputHandler.new(in: confirm_win).get_input
        end

        break if quit_without_save_bool || delete_save_bool
      end
  end

  def self.delete_save(i)
    @@saves[i] = EmptySave.new
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

class EmptySave < Save
  def initialize(args = {}); end

  def to_s
    return " \n \n \n \nEmpty\n \n \n \n "
  end
end

