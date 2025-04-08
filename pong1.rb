require 'ruby2d'

set width: 600, height: 600

image = Image.new('img/background.jpg', width: 600, height: 600)
PONG_SOUND = Sound.new('sound/pongsound.wav')
PING_SOUND = Sound.new('sound/pingsound.wav')
out_of_bounds = Sound.new('sound/outofbounds.mp3')
@game_state = :start

#Startskärm
def draw_start_screen
 start_image = Image.new('img/background.jpg', width: 600, height: 600)
 start_image.draw
  Text.new("WELCOME TO PONG!", 
           x: (Window.width / 2) - 145,
           y: 100, 
           size: 30, 
           color: 'black')

  @start_button = { x: (Window.width / 2) - 50, y: 250, width: 100, height: 40 }
  Rectangle.new(
    x: @start_button[:x], 
    y: @start_button[:y], 
    width: @start_button[:width], 
    height: @start_button[:height], 
    color: 'green'
  )
  Text.new("Start", 
           x: @start_button[:x] + 20, 
           y: @start_button[:y] + 8, 
           size: 20, 
           color: 'white')
  
  @quit_button = { x: (Window.width / 2) - 50, y: 320, width: 100, height: 40 }
  Rectangle.new(
    x: @quit_button[:x], 
    y: @quit_button[:y], 
    width: @quit_button[:width], 
    height: @quit_button[:height], 
    color: 'red'
  )
  Text.new("Quit", 
           x: @quit_button[:x] + 25, 
           y: @quit_button[:y] + 8, 
           size: 20, 
           color: 'white')
end

#Status i matchen
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
    Text.new("Left: #{@left_score}", x: 20, y: 20, size: 20, color: 'white')
    Text.new("Right: #{@right_score}", x: Window.width - 120, y: 20, size: 20, color: 'white')
  end
end

class Paddle
  HEIGHT = 150
  JITTER_CORRECTION = 4

  attr_writer :direction
  attr_reader :side, :y, :x
  
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
    ball.shape && [[ball.shape.x1, ball.shape.y1],
                    [ball.shape.x2, ball.shape.y2],
                    [ball.shape.x3, ball.shape.y3],
                    [ball.shape.x4, ball.shape.y4]].any? do |coordinates|
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

  def max_y
    Window.height - HEIGHT
  end
end

class Ball
  HEIGHT = 25

  attr_reader :shape, :x, :y

  def initialize(speed, serve = nil, spawn_y = nil)
    @speed = speed
    @serve_side = serve
    spawn_y ||= Window.height / 2
    if serve == :left
      @x = 60
    elsif serve == :right
      @x = Window.width - 60 - HEIGHT
    else
      @x = Window.width / 2
    end
    @y = spawn_y
    @y_velocity = 0
    @x_velocity = 0
    @last_hit_side = nil
  end

  def serve!
    if @serve_side == :left
      @x_velocity = @speed
      @y_velocity = 0
    elsif @serve_side == :right
      @x_velocity = -@speed
      @y_velocity = 0
    end
  end

  def move
    if hit_bottom?
      @y_velocity = -@y_velocity
      PONG_SOUND.play
    elsif hit_top?
      @y_velocity = -@y_velocity
      PONG_SOUND.play
    end
    @x += @x_velocity
    @y += @y_velocity
  end

  def draw
    @shape = Square.new(x: @x, y: @y, size: HEIGHT, color: 'orange')
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

      @last_hit_side = paddle.side
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

ball_velocity = 10 
player1 = Paddle.new(:left, 10)
player2 = Paddle.new(:right, 10)
@serving_player = :left
scoreboard = Scoreboard.new
spawn_y = (@serving_player == :left) ? (player1.y + Paddle::HEIGHT / 2 - Ball::HEIGHT / 2) :
          (player2.y + Paddle::HEIGHT / 2 - Ball::HEIGHT / 2)
ball = Ball.new(ball_velocity, @serving_player, spawn_y)
@game_paused = true
@countdown_time = 3.0
@last_time = Time.now

def start_countdown
  @game_paused = true
  @countdown_time = 3.0
  @last_time = Time.now
end

update do
  clear

  case @game_state
  when :start
    draw_start_screen
  
  when :playing
    image.draw

    player1.move
    player1.draw
    player2.move
    player2.draw

    scoreboard.draw

    if @game_paused
      if @serving_player == :left
        ball.instance_variable_set(:@x, player1.x + 25)
        ball.instance_variable_set(:@y, player1.y + Paddle::HEIGHT / 2 - Ball::HEIGHT / 2)
      else
        ball.instance_variable_set(:@x, player2.x - Ball::HEIGHT)
        ball.instance_variable_set(:@y, player2.y + Paddle::HEIGHT / 2 - Ball::HEIGHT / 2)
      end
      ball.draw
      current_time = Time.now
      elapsed = current_time - @last_time
      @countdown_time = [@countdown_time - elapsed, 0].max
      @last_time = current_time

      countdown_display = @countdown_time.ceil
      Text.new(countdown_display.to_s, x: (Window.width / 2) - 5, y: 2, size: 20, color: 'white')
      
      serve_text = @serving_player == :left ? "P1 serve" : "P2 serve"
      Text.new(serve_text, x: (Window.width / 2) - 40, y: 20, size: 20, color: 'white')

      if @countdown_time <= 0
      end
      
      next
    end
    if player1.hit_ball?(ball)
      ball.bounce_off(player1)
      PING_SOUND.play
    end
    if player2.hit_ball?(ball)
      ball.bounce_off(player2)
      PING_SOUND.play
    end

    ball.move
    ball.draw

    if ball.out_of_bounds?
      out_of_bounds.play
      if ball.x <= 0
        scoreboard.update(ball)
        @serving_player = :right
      elsif ball.shape.x2 >= Window.width
        scoreboard.update(ball)
        @serving_player = :left
      end

      spawn_y = if @serving_player == :left
                  player1.y + Paddle::HEIGHT / 2 - Ball::HEIGHT / 2
                else
                  player2.y + Paddle::HEIGHT / 2 - Ball::HEIGHT / 2
                end
      ball = Ball.new(ball_velocity, @serving_player, spawn_y)
      start_countdown
    end
  end
end

on :key_held do |event|
  if @game_state == :playing
    # Spelare 1
    if event.key == 'w'
      player1.direction = :up
    elsif event.key == 's'
      player1.direction = :down
    end

    # Spelare 2
    if event.key == 'up'
      player2.direction = :up
    elsif event.key == 'down'
      player2.direction = :down
    end
  end
end

on :key_up do |_event|
  if @game_state == :playing
    player1.direction = nil
    player2.direction = nil
  end
end

on :key_down do |event|
  if @game_state == :playing && event.key == 'space' && @game_paused && @countdown_time <= 0
    ball.serve!
    @game_paused = false
  end
end

on :mouse_down do |event|
  if @game_state == :start
    if event.x >= @start_button[:x] && event.x <= (@start_button[:x] + @start_button[:width]) &&
       event.y >= @start_button[:y] && event.y <= (@start_button[:y] + @start_button[:height])
      @game_state = :playing
    end

    if event.x >= @quit_button[:x] && event.x <= (@quit_button[:x] + @quit_button[:width]) &&
       event.y >= @quit_button[:y] && event.y <= (@quit_button[:y] + @quit_button[:height])
      close 
    end
  end
end

show