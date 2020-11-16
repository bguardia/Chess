
class Player

  attr_reader :name, :team

  def initialize(args = {})
    @name = args.fetch(:name, "")
    @team = args.fetch(:team, "")
  end

end
