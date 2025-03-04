require 'ruby2d'

set background: 'green'
set width: 600, height: 600

class Paddle
  HEIGHT = 150

  attr_writer :direction
  def initialize(side, movement_speed)
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
    if ball.y_middle > y_middle
      @y += @movement_speed
    elsif ball.y_middle < y_middle
      @y -= @movement_speed
    end
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

  attr_reader :shape

  def initialize(speed)
    @x = 500
    @y = 450
    @y_velocity = speed
    @x_velocity = -speed
  end

  def move
    if hit_bottom?
      @y_velocity = -@y_velocity
    elsif hit_top?
      @y_velocity = -@y_velocity
    end
    
    @x = @x + @x_velocity
    @y = @y + @y_velocity
  end

  def draw
    @shape = Square.new(x: @x, y: @y, size: HEIGHT, color: 'yellow')
  end

  def bounce
    @x_velocity = -@x_velocity
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

ball_velocity = 8

player1 = Paddle.new(:left, 8)
player2 = Paddle.new(:right, 3)
ball = Ball.new(ball_velocity)


update do
  clear 

  if player1.hit_ball?(ball)
    ball.bounce
  end

  if player2.hit_ball?(ball)
    ball.bounce
  end

  player1.move
  player1.draw

  player2.draw
  player2.move
  #player2.track_ball(ball) #ai motståndare

  ball.move
  ball.draw

  if ball.out_of_bounds?
    ball = Ball.new(ball_velocity)
  end
end

on :key_down do |event| #spelare 1
  if event.key == 'w'
    player1.direction = :up
  elsif event.key == 's'
    player1.direction = :down
  end
end

on :key_down do |event| #spelare 2
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