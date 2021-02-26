#require './lib/chess.rb'

$board_debug = ""

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
    $game_debug += "Called board.update\n"
    @arr.each_index do |r|
      @arr[r].each_index do |f|
        piece = state.get_piece_at([r, f])
        @arr[r][f] = piece
        if piece
          $game_debug += "Piece at [#{r},#{f}] is #{piece.team} #{piece.class} (#{piece.id})\n" 
        end
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

class Node < Saveable

  def initialize(args)
    @parent_node = args.fetch(:parent, nil)
    @data = args.fetch(:data, nil)
    @child_nodes = args.fetch(:child_nodes, [])
    #if child nodes are passed during initialization, set parent of each node
    @child_nodes.each { |n| n.set_parent(self) } 
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

  def ignore_on_serialization
    ["@parent_node"]
  end

=begin
  def to_json
    JSON.dump({ "data" => @data,
                "child_nodes" => @child_nodes })
    
  end

  def self.from_json(json)
    data = JSON.load json

    node = self.new(data["data"])

    queue = data["child_nodes"]
    loop do
      child_node_data = queue.pop
      break unless child_node_data
      node.add_child(self.from_json(child_node_data))
    end

    return node
  end
=end

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

class StateTree < Saveable
  attr_reader :current_node

  def initialize(args)
    if args.fetch(:pieces, nil)
      @first_node = Node.new(data: State.new(args))
      @current_node = @first_node
    elsif args.fetch(:first_node, nil)
      @first_node = args.fetch(:first_node)
      @current_node = args.fetch(:current_node)
    end
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
    $game_debug += "called statetree.do\n"
    $game_debug += "Checking if child node for move already exists...\n"
    $game_debug += "#{move}\n"
    next_state = @current_node.child_nodes.find do |node|
      state = node.data
      $game_debug += "child node is:\n #{state}\n"
      $game_debug += "last move is: \n#{state.last_move}\n"
      state.last_move == move
    end

    if next_state
      $game_debug += "Moves matched. Next state is: \n #{next_state}\n"
      next_state
    else
      $game_debug += "Move did not match any child nodes. Creating new state.\n"
      new_state(move)
    end
  end

  def do!(move)
    set_current_node(self.do(move))
  end

  def new_state(move)
    new_state = @current_node.data.do(move)
    new_node = Node.new(data: new_state)
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

  def update_moves(moves)
    @current_node.data.update_moves(moves)
    notify_observers
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
    $game_debug += "Called statetree.checkmate?\n"
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

=begin
  def to_json
    JSON.dump({"first_node" => @first_node,
               "last_move" => @current_node.last_move})
  end

  def self.from_json(json)
    data = JSON.load json
    
    first_node = Node.from_json(data["first_node"])
    last_move = Move.from_json(data["last_move"])

    #Check node tree for node whose last_move matches
    #Matching node is current_node
    queue = [first_node]
    current_node = nil
    loop do
      node = queue.pop
      break if node.nil?
      if node.last_move == last_move
        current_node = node
        break
      end
    end

    return self.new(first_node: Node.from_json(data["first_node"]),
                         current_node: current_node)
  end
=end

  def to_s
    queue = [@first_node]
    str = ""
    loop do
      node = queue.pop
      unless node.nil?
        node.child_nodes.each do |child_node|
          queue << child_node
        end
      end
      if node == @current_node
        str += "*Current Node*\n"
      end
      str += node.data.to_s
      break if queue.empty?
    end
    return str
  end

end


class State < Saveable

  def initialize(args)
    pieces = args.fetch(:pieces)
    
    @pieces = pieces.kind_of?(Array) ? set_pieces(pieces, true) : pieces
    @positions = args.fetch(:positions, nil) || get_positions #inverse of positions and pieces
    @check = args.fetch(:check, nil) || { "white" => nil, "black" => nil }
    @checkmate = args.fetch(:checkmate, nil) || { "white" => nil, "black" => nil }
    @last_move = args.fetch(:last_move, nil)

    $game_debug += "pieces: #{@pieces}\n"
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

  def update_moves(moves)

    #sort moves by piece
    move_hash = moves.reduce({}) do |hash, move|
      piece = move.get_piece
      if hash.has_key?(piece)
        hash[piece] << move
      else
        hash[piece] = [move]
      end
      hash
    end

    #merge movesets into @pieces hash
    move_hash.each_pair do |piece, moves|
      @pieces[piece].merge!({ :moves => moves })
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
    #make a copy of every piece hash
    pieces_hash = {}
    @pieces.each_key do |piece|
      if @pieces[piece].kind_of?(Hash)
        pieces_hash[piece] = @pieces[piece].merge
      end 
    end 
    
    #Apply move instructions to pieces_hash
    move.each do |piece, current_pos, dest_pos|
      if dest_pos
        pieces_hash[piece] = { :prev_pos => current_pos,
                               :pos => dest_pos,
                               :moved => true }
      else
        pieces_hash.delete(piece)
      end
    end

    #Reset check values
    check = { "white" => nil,
              "black" => nil }
    
    last_move = move

    #Return as new state
    return State.new(pieces: pieces_hash,
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

  def to_s
    str = "State #{self.object_id}\n { \n"
    @pieces.each_key do |piece|
      prev_pos = @pieces[piece][:prev_pos]
      pos = @pieces[piece][:pos]
      num_moves = @pieces[piece][:moves].filter { |mv| !mv.blocked? }.length
      str += "#{piece.id}. #{piece.team} #{piece.class}: prev_pos: #{prev_pos}, pos: #{pos}, num_moves: #{num_moves}"
      str += "\n"
    end
    str += "\n } \n"

    return str
  end

  def ignore_on_serialization
    ["@positions"]
  end
=begin
  def to_json

    pieces_hash = {}
    @pieces.each_pair do |key, val|
      key_json = key.to_json
      pieces_hash[key_json] = val
    end

    state_hash = { "pieces" => pieces_hash,
                   "last_move" => @last_move,
                   "check" => @check,
                   "checkmate" => @checkmate }

    return state_hash.to_json
  end

  def self.from_json(json)
    data = JSON.load json
    
    pieces_hash = {}
    data["pieces"].each_pair do |key, val|
      pieces_hash[Piece.from_json(key)] = val
    end

    return State.new(pieces_hash: pieces_hash,
                     check: data["check"],
                     checkmate: data["checkmate"],
                     last_move: data["last_move"])
  end
=end

end


class Observer

  def initialize(args)
    @to_do = args.fetch(:to_do)
  end

  def update(args)
    @to_do.call(args)
  end

end
