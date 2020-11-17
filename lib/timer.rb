#require 'chess'

class Timer

  def initialize
    @start = 0
    @current = 0
    @elapsed_time = 0
    @paused = true
    @paused_time = 0
  end

  def current
    unless @paused
      @current = Time.new
    else
      @current
    end
  end

  def start
    @current = @start = Time.new
    @elapsed_time = @paused_time 
    @paused = false
  end

  def get_time
    time = @elapsed_time + (current - @start)
  end

  def pause
    @paused_time += current - @start
    @paused = true 
  end

  def reset
    @start = 0
    @current = 0
    @elapsed_time = 0
    @pause = true
    @paused_time = 0
  end

  def seconds(time)
    time % 60
  end

  def minutes(time)
    (time / 60) % 60
  end

  def hours(time)
    (time / 360) % 60
  end

  def format_time(time)
    s = seconds(time).to_s.rjust(2, "0")
    m = minutes(time).to_s.rjust(2, "0")
    h = hours(time).to_s.rjust(2, "0")
    "#{h}:#{m}:#{s}"
  end

  def to_s
    format_time(get_time.round)
  end
end

class CountdownTimer < Timer

  def initialize(alloted_time)
    @alloted_time = alloted_time
    @thread = nil
    super()
  end

  def get_time
    time = @alloted_time - (@elapsed_time + (current - @start))
    
    if time < 0
      return 0
    else
      time
    end
  end

  def time_up?
    if get_time == 0
      return true
    end
  end

  def countdown
    @thread = Thread.new do
      start
      loop do
        #puts self
        sleep(1)
        break if time_up?
      end
    end
    reset
  end

  def countdown_to(func)
    @thread = Thread.new do
      start
      loop do
        #puts self
        sleep(1)
        break if time_up?
      end
      func.call
    end
    reset
  end
end

class Countdown

  def initialize(alloted_time)
    @alloted_time = alloted_time
    @count = 0
    @thread = nil
    @pause = true
  end

  def create_thread
    @thread = Thread.new do
      @count = 0
      loop do
        #puts @alloted_time - count
        sleep(1)
        Thread.stop if @pause
        @count += 1
        break if @count >= @alloted_time
      end
      puts "Time's up"
      reset
    end
  end

  def kill_thread
    unless @thread.nil?
      @thread.kill
    end
  end

  def start
    @pause = false
    if @thread.nil?
      create_thread
    else
      @thread.run
    end
  end

  def pause
    @pause = true
  end

  def reset
    kill_thread
    @count = 0
    @pause = true
    @thread = nil
  end

  def get_remaining
    @alloted_time - @count
  end
end
