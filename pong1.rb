require 'ruby2d'

set background: 'green'
set width: 600, height: 600

#PONG_SOUND = Sound.new('')
#PING_SOUND = Sound.new('')

class DividingLine
  WIDTH = 15
  HEIGHT = Window.height
  NUMBER_OF_LINES = 1

  def draw
    NUMBER_OF_LINES.times do |i|
      Rectangle.new(x: (Window.width + WIDTH) / 2, y: (Window.height / NUMBER_OF_LINES) * i, height: HEIGHT, width: WIDTH, color: 'white')
    end
  end
end

class Scoreboard
  attr_reader :left_score, :right_score

  def initialize
    @left_score = 0
    @right_score = 0
  end

  def update(ball)
  if ball.x <= 0
    @right_score += 1
  elsif ball.shape.x2 >= Window.width
    @left_score += 1
  end
end

  def draw
      Text.new("Left: #{@left_score}", x: 20, y: 20, size: 20, color: ('white'))
      Text.new("Right: #{@right_score}", x: Window.width - 120, y: 20, size: 20, color: ('white'))
  end
end

class Paddle
  HEIGHT = 150
  JITTER_CORRECTION = 4

  attr_writer :direction
  attr_reader :side
  
  def initialize(side, movement_speed)
    @side = side
    @movement_speed = movement_speed
    @direction = nil
    @y = 200
    if side == :left
      @x = 40
    elsif side == :right
      @x = Window.width - 60
    end
  end

  def move
    if @direction == :up
      @y = [@y - @movement_speed, 0].max
    elsif @direction == :down
      @y = [@y + @movement_speed, max_y].min
    end
  end

  def draw
    @shape = Rectangle.new(x: @x, y: @y, width: 25, height: HEIGHT, color: 'black')
  end

  def hit_ball?(ball)
    ball.shape && [[ball.shape.x1, ball.shape.y1], [ball.shape.x2, ball.shape.y2], 
    [ball.shape.x3, ball.shape.y3], [ball.shape.x4, ball.shape.y4]].any? do |coordinates|
      @shape.contains?(coordinates[0], coordinates[1])
    end
  end
  
  def track_ball(ball)
    if ball.y_middle > y_middle + JITTER_CORRECTION
      @y += @movement_speed
    elsif ball.y_middle < y_middle - JITTER_CORRECTION
      @y -= @movement_speed
    end
  end

  def y1
    @shape.y1
  end

  private

  def y_middle
    @y + (HEIGHT / 2)
  end

  private

  def max_y
    Window.height - HEIGHT
  end
end

class Ball
  HEIGHT = 25

  attr_reader :shape, :x, :y

  def initialize(speed)
    @x = 500
    @y = 450
    @speed = speed
    @y_velocity = speed
    @x_velocity = -speed
  end

  def move
    if hit_bottom?
      @y_velocity = -@y_velocity
      #PONG_SOUND.play
    elsif hit_top?
      @y_velocity = -@y_velocity
      #PONG_SOUND.play
    end
    
    @x = @x + @x_velocity
    @y = @y + @y_velocity
  end

  def draw
    @shape = Square.new(x: @x, y: @y, size: HEIGHT, color: 'yellow')
  end

  def bounce_off(paddle)
    if @last_hit_side != paddle.side
      position = ((@shape.y1 - paddle.y1) / Paddle::HEIGHT.to_f)
      angle = position.clamp(0.2, 0.8) * Math::PI

      if paddle.side == :left
        @x_velocity = Math.sin(angle) * @speed
        @y_velocity = -Math.cos(angle) * @speed
      else
        @x_velocity = -Math.sin(angle) * @speed
        @y_velocity = Math.cos(angle) * @speed
      end


      @last_hit_side =paddle.side
    end
  end

  def y_middle
    @y + (HEIGHT / 2)
  end

  def out_of_bounds?
    @x <= 0 || @shape.x2 >= Window.width
  end
  
  private 

  def hit_bottom?
    @y + HEIGHT >= Window.height
  end

  def hit_top?
    @y <= 0
  end
end

ball_velocity = 8 #snabbhet på bollen

player1 = Paddle.new(:left, 7) #ändra hastighet för spelare 1
player2 = Paddle.new(:right, 7) #hast för spelare 2
ball = Ball.new(ball_velocity)
scoreboard = Scoreboard.new

#music = Music.new('') #ladda ner musik
#music.loop = true
#music.play

update do
  clear 

  DividingLine.new.draw
  
  if player1.hit_ball?(ball)
    ball.bounce_off(player1)
    #PING_SOUND.play
  end

  if player2.hit_ball?(ball)
    ball.bounce_off(player2)
    #PING_SOUND.play
  end

  player1.move
  player1.draw

  player2.draw
  player2.move
  #player2.track_ball(ball) #ai motståndare

  ball.move
  ball.draw

  if ball.out_of_bounds?
    scoreboard.update(ball)
    ball = Ball.new(ball_velocity)
  end
  scoreboard.draw
end

on :key_held do |event| #spelare 1
  if event.key == 'w'
    player1.direction = :up
  elsif event.key == 's'
    player1.direction = :down
  end
end

on :key_held do |event| #spelare 2
  if event.key == 'up'
    player2.direction = :up
  elsif event.key == 'down'
    player2.direction = :down
  end
end

on :key_up do |event|
player1.direction = nil
player2.direction = nil
end


show