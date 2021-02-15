#require 'chess'

$board_debug = ""
=begin
module Gamestate

  REMOVED = nil

  def update 
    prev_state = get_previous_state(0)
    pieces = self.get_pieces
    pieces_hash = {} 

    #Check for pieces which have been removed from game since last state
    prev_state.each_key do |key|
      pieces_hash[key] = REMOVED unless pieces.find { |p| p.id == key.to_i }
    end

    #Check for pieces which have changed position since last state
    pieces.each do |p|
      p_arr = [p, get_coords(p)]
      p_key = p.id.to_s
      if prev_state[p_key] == p_arr
        next
      else
        pieces_hash[p_key] = p_arr
      end
    end

    #Add state to log
    @log << pieces_hash 
  end

  def get_previous_state(n)
    arr = @log[0..(@log.length - (n + 1))]
    arr.reduce({}) do |sum, state|
      sum.merge(state)
    end
  end

  def revert_to_previous_state(n)
    n.times { @log.pop }
    state = get_previous_state(0)
  end

  def return_last_moved
    $board_debug += "called return_last_moved.\n"
    $board_debug += "@log.length = #{@log.length}\n"
    log_str = ""
    @log.last.each_pair do |key, val|
      name = val.nil? ? "empty" : val[0].class
      pos = val.nil? ? "none" : val[1]
      log_str += "#{key} => #{name}, #{pos}\n"
    end
    $board_debug += "@log.last: #{log_str}\n"
    @log.last.each_value do |val|
      if val
        return val[0]
      end
    end
  end
end
=end

class Board
  attr_reader :arr

  def initialize(args = {})
    @height = args.fetch(:height, 8)
    @width = args.fetch(:width, 8)
    @arr = args.fetch(:arr, nil) || create_array
  end
  
  def create_array
    Array.new(@height) { Array.new(@width, nil) }
  end

  public
  def update(state)
    @arr.each_index do |r|
      @arr[r].each_index do |f|
        piece = state.get_piece_at([r, f])
        @arr[r][f] = piece
      end
    end 
  end

  public
  def place(piece, pos)
    return nil unless cell_exists?(pos)
    x = pos[0]
    y = pos[1]
    @arr[x][y] = piece
    piece.set_pos(pos)
  end

  def get_piece_at(pos)
    r = pos[0]
    f = pos[1]
    @arr[r][f]
  end

  public
  def cell_exists?(pos)
    valid_x = pos[1] >= 0 && pos[1] < @width
    valid_y = pos[0] >= 0 && pos[0] < @height
    if valid_x && valid_y
      return true
    else
      return false
    end
  end

  def remove(piece)
    pos = get_coords(piece)
    remove_at(pos)
  end

  def remove_at(pos)
    x = pos[0]
    y = pos[1]

    @arr[x][y] = nil
  end

  private
  def ruled_arr
    width_ruler = ("a".."z").to_a.first(@width)
    height_index = @height
    ruled_arr = []
    ruled_arr.push( [nil].concat(width_ruler) )
    @arr.each do |row|
      ruled_arr.push( [height_index].concat(row) )
      height_index -= 1
    end

    return ruled_arr
    end


  public
  def clear
    @arr.map! do |row|
      row = Array.new(@width, nil)  
    end
  end

  def set_arr (arr)
    @arr = arr
  end
  
  def copy
    board_copy = self.dup
    arr = @arr.map do |row|
      row.dup.map do |cell|
              cell.dup
      end
    end

    board_copy.set_arr(arr)
    board_copy.set_log(@log.map { |h| h.dup })
    return board_copy
  end

=begin
   def get_previous_pos(piece)
    $board_debug += "called get_previous_pos\n"
    return nil if piece.nil?
    prev_state = get_previous_state(1)
    val = prev_state.fetch(piece.id.to_s, nil)
    $board_debug += "val fetched from prev_state: #{val}\n"
    if val
      return val[1]
    else
      return nil
    end 
  end
=end

  public
  def to_s
    
    separator = "|"
    board_str = ""
    ruled_arr.each do |row|
      row.each do |cell|
        cell_str = cell.nil? ? " " : cell.to_s
        board_str += cell_str + separator
      end
      board_str += "\n" 
    end
    return board_str
  end

end

class Node

  def initialize(data = nil, parent = nil)
    @parent_node = parent
    @data = data
    @child_nodes = []
  end

  def set_parent(parent)
    @parent_node = parent
  end

  def parent_node
    @parent_node
  end

  def data
    @data
  end

  def child_nodes
    @child_nodes
  end

  def add_child(child_node)
    @child_nodes << child_node
    child_node.set_parent(self)
  end

  def remove_child(child_node)
  end
end

module TreeSearch

  def bf_search_by_block(parent_node, &block)
    queue = [parent_node]
    loop do
      break if queue.empty?
      current_node = queue.shift
      block.call(current_node)
      queue.concat(current_node.child_nodes)
    end

    return nil
  end

  def df_search_by_block(parent_node, &block)
    stack = [parent_node]
    loop do
      break if stack.empty?
      current_node = stack.pop
      block.call(current_node)
      stack.concat(current_node.child_nodes)
    end

    return nil
  end
end

class StateTree

  def initialize(pieces)
    @first_node = Node.new(State.new(pieces: pieces))
    @current_node = @first_node
    @observers = []
  end

  def set_current_node(node)
    @current_node = node
    notify_observers
  end

  def add_observer(o)
    @observers << o
  end

  public
  def notify_observers
    @observers.each do |o|
      o.update(self) #send current state data
    end
  end

  def do(move)
    next_state = @current_node.child_nodes.find do |node|
      state = node.data
      state.last_move == move
    end

    if next_state
      next_state
    else
      new_state(move)
    end
  end

  def do!(move)
    set_current_node(self.do(move))
  end

  def new_state(move)
    new_state = @current_node.data.do(move)
    new_node = Node.new(new_state)
    @current_node.add_child(new_node)
    return new_node 
  end

  def undo
    parent_node = @current_node.parent_node
    if parent_node
      set_current_node(parent_node)
    end
  end

=begin

 State methods

=end
  def get_previous_pos(piece)
    prev_state = @current_node.parent_node.data
    return nil unless prev_state
    prev_state.get_pos(piece)
  end

  def get_pos(piece)
    @current_node.data.get_pos(piece)
  end

  def get_piece_at(pos)
    @current_node.data.get_piece_at(pos)
  end

  def get_moved_status(piece)
    @current_node.data.get_moved_status(piece)
  end

  def get_last_move
    @current_node.data.last_move
  end

  def get_last_moved
    @current_node.data.get_last_moved
  end

  def get_moves(args = {})
    @current_node.data.get_moves(args)
  end

  def get_pieces(args = {})
    @current_node.data.get_pieces(args)
  end

  def in_check?(args)
    @current_node.data.in_check?(args)
  end

  def get_current_state
    @current_node.data
  end

  def checkmate?(team)
    #@current_node.data.checkmate?(team)
    state = @current_node.data
    return false unless in_check?(team: team)
    
    #get team's king and check if king can escape on its own
    king = state.get_pieces(type: "King", team: team)[0]
    king_cant_escape = king.possible_moves.all? do |mv|
      next_state = self.do(mv).data
      check = next_state.in_check?(king: king)
    end

    return false unless king_cant_escape

    #get important spaces (spaces between king and attackers, and attacker positions)
    king_pos = state.get_pos(king)
    enemy_team = ["white", "black"].find { |t| t != king.team }
    attackers = state.get_pieces(team: enemy_team).filter do |atk|
      atk.possible_moves.any? do |mv|
        mv.include?(king_pos)
      end
    end

    important_spaces = attackers.reduce([]) do |spaces, atk|
      atk_pos = state.get_pos(atk)
      spaces.concat(Movement.get_spaces_between(king_pos, atk_pos)).concat(atk_pos)
    end

    ally_pieces = get_pieces(team: team)

    checkmate = ally_pieces.all? do |p|
      p_moves = p.possible_moves 
      p_moves.all? do |mv|
        if important_spaces.include?(mv.destination(p))
          next_state = self.do(mv).data
          check = next_state.in_check?(king: king)
        else
          true
        end
      end
    end

    return checkmate
  end

end


class State

  def initialize(args)
    @pieces = args.fetch(:pieces_hash, nil) || set_pieces(args.fetch(:pieces), true)
    @positions = get_positions #inverse of positions and pieces
    @check = args.fetch(:check, nil) || { "white" => nil, "black" => nil }
    @checkmate = args.fetch(:checkmate, nil) || { "white" => nil, "black" => nil }
    @last_move = args.fetch(:last_move, nil)

    set_moves 
  end

  def get_positions
    @pieces.keys.reduce({}) do |hash, piece|
      hash.merge({ @pieces[piece][:pos] => piece })
    end
  end

  def last_move
    @last_move
  end

  def last_move=(last_move)
    @last_move = last_move
  end

  def set_moves
    @pieces.each_key do |piece|
      exists = @pieces[piece][:pos]
      @pieces[piece].merge!({ :moves => exists ? piece.generate_possible_moves(self) : nil }) 
    end
  end

  def set_pieces(pieces, initial = false)
    pieces_hash = {}
    pieces.each do |piece|
      pieces_hash[piece] = { :prev_pos => piece.starting_pos,
                             :pos => initial ? piece.starting_pos : piece.current_pos,
                             :moved => initial ? false : piece.moved }
    end

    return pieces_hash
  end

  public
  def do(move)
    $game_debug += "Called State.do\n"

    pieces_hash = @pieces.merge({}) #make a copy

    $game_debug += "current state is: \n"
    pieces_hash.each_pair do |p, val|
      prev = val[:prev_pos]
      pos = val[:pos]
      $game_debug += "#{p.class} (#{p.id}) => :prev_pos #{prev}, :pos #{pos}\n"
    end

    move.each do |piece, current_pos, dest_pos|
      $game_debug += "move: [#{piece.class} (#{piece.id}), #{current_pos}, #{dest_pos}]\n"
      if dest_pos
        $game_debug += "-> has dest_pos \n"
        pieces_hash[piece] = { :prev_pos => current_pos,
                               :pos => dest_pos,
                               :moved => true }
      else
        pieces_hash.delete(piece)
      end
    end
    
    $game_debug += "state now is: \n"
    pieces_hash.each_pair do |p, val|
      prev = val[:prev_pos]
      pos = val[:pos]
      $game_debug += "#{p.class} (#{p.id}) => :prev_pos #{prev}, :pos #{pos}\n"
    end

    check = { "white" => nil,
              "black" => nil }
    
    last_move = move

    return State.new(pieces_hash: pieces_hash,
                     check: check,
                     last_move: move)
  end

  def get_pos(piece)
    if @pieces[piece]
      @pieces[piece][:pos]
    else
      nil
    end
  end

  def get_piece_at(pos)
    @positions[pos]
  end

  def get_previous_pos(piece)
    if @pieces[piece]
      @pieces[piece][:prev_pos]
    end
  end

  def get_last_moved
    if @last_move
      @last_move.get_piece
    else
      nil
    end
  end

  def get_moved_status(piece)
    if @pieces[piece]
      @pieces[piece][:moved]
    end
  end

  def get_moves(args = {})
    pieces = get_pieces(args)
   
    moves = pieces.map do |piece|
      @pieces[piece][:moves]
    end

    return moves.flatten
  end

  def get_pieces(args = {})
    pieces = []

    @pieces.keys.each do |piece|
      match_all = args.keys.all? do |key|
        if key == :type
          clz = Kernel.const_get(args[key])
          piece.kind_of?(clz)
        else
          inst_var = "@#{key}".to_sym
          piece.instance_variable_get(inst_var) == args[key]
        end
      end
      if match_all
        pieces << piece
      end
    end 

    return pieces
  end

  def in_check?(args)
    team = args.fetch(:team, nil)
    king = args.fetch(:king, nil)|| get_pieces(type: "King", team: team)[0]
    team ||= king.team

    unless @check[team].nil?
      return @check[team]
    end

    king_pos = get_pos(king)
    enemy_pieces = get_pieces.filter { |p| p.team != team }
    attackers = enemy_pieces.filter do |ep|
      ep_moves = get_moves(id: ep.id).flatten
      ep_moves.any? do |move|
        next if move.blocked?
        move.include?(king_pos)
      end
    end

    if attackers.empty?
      @check[team] = false
      return nil
    else
      @check[team] = true
      return attackers
    end
  end

  def checkmate?(team)
    attackers = in_check?(team: team)
    return false unless attackers
    
    unless @checkmate[team].nil?
      return @checkmate[team]
    end

    #get team's king and check if king can escape on its own
    king = get_pieces(type: "King", team: team)[0]
    king_cant_escape = king.possible_moves.all? do |mv|
      next_state = self.do(mv)
      check = next_state.in_check?(king: king)
    end

    return false unless king_cant_escape

    #get important spaces (spaces between king and attackers, and attacker positions)
    king_pos = get_pos(king)
    important_spaces = attackers.reduce([]) do |spaces, atk|
      atk_pos = get_pos(atk)
      spaces.concat(Movement.get_spaces_between(king_pos, atk_pos)).concat(atk_pos)
    end

    ally_pieces = get_pieces(team: team)

    checkmate = ally_pieces.all? do |p|
      p_moves = p.possible_moves 
      p_moves.all? do |mv|
        if important_spaces.include?(mv.destination(p))
          next_state = self.do(mv)
          check = next_state.in_check?(king: king)
        else
          true
        end
      end
    end

    @checkmate[team] = checkmate
    return checkmate
  end

end


class Observer

  def initialize(args)
    @to_do = args.fetch(:to_do)
  end

  def update(args)
    @to_do.call(args)
  end

end
