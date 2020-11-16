require 'chess'

class Game

 attr_reader :players, :board

 def initialize(args = {})
   @players = []
   @board = Board.new
 end

end
