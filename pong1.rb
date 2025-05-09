require 'ruby2d'

#Storlek på skärm
set width: 600, height: 600

# Bakgrund och ljud
BACKGROUND   = Image.new('img/background.jpg', width: 600, height: 600)
PONG_SOUND   = Sound.new('sound/pongsound.wav')
PING_SOUND   = Sound.new('sound/pingsound.wav')
OUT_SOUND    = Sound.new('sound/outofbounds.mp3')

@game_state  = :start
@game_paused = true
@countdown   = 3.0
@last_time   = Time.now

# Startskärm
def draw_start_screen
  BACKGROUND.draw
  Text.new("WELCOME TO PONG!",
           x: (Window.width / 2) - 145,
           y: 100,
           size: 30,
           color: 'black')

  @start_button = { x: (Window.width/2) - 50, y: 250, width: 100, height: 40 }
  Rectangle.new(**@start_button, color: 'green')
  Text.new("Start",
           x: @start_button[:x] + 20,
           y: @start_button[:y] + 8,
           size: 20,
           color: 'white')

  @quit_button = { x: (Window.width/2) - 50, y: 320, width: 100, height: 40 }
  Rectangle.new(**@quit_button, color: 'red')
  Text.new("Quit",
           x: @quit_button[:x] + 25,
           y: @quit_button[:y] + 8,
           size: 20,
           color: 'white')
end

# Pausskärm
def draw_pause_screen
  BACKGROUND.draw

  @resume_button = { x: (Window.width/2) - 75, y: 200, width: 150, height: 50 }
  Rectangle.new(**@resume_button, color: 'green')
  Text.new("Resume",
           x: @resume_button[:x] + 35,
           y: @resume_button[:y] + 12,
           size: 24,
           color: 'white')

  @quit_to_menu_button = { x: (Window.width/2) - 100, y: 300, width: 200, height: 50 }
  Rectangle.new(**@quit_to_menu_button, color: 'red')
  Text.new("Quit to main menu",
           x: @quit_to_menu_button[:x] + 15,
           y: @quit_to_menu_button[:y] + 12,
           size: 20,
           color: 'white')
end

# Poängtavla
class Scoreboard
  attr_reader :left_score, :right_score

  def initialize
    @left_score  = 0
    @right_score = 0
  end

  def update(ball)
    @right_score += 1 if ball.x <= 0
    @left_score  += 1 if ball.shape.x2 >= Window.width
  end

  def draw
    Text.new("Left: #{@left_score}",
             x: 20, y: 20,
             size: 20,
             color: 'white')
    Text.new("Right: #{@right_score}",
             x: Window.width - 120, y: 20,
             size: 20,
             color: 'white')
  end

  def reset!
    @left_score = 0
    @right_score = 0
  end
end

# Paddel
class Paddle
  HEIGHT = 150

  attr_accessor :direction, :speed_multiplier, :slow_timer
  attr_reader :side, :x, :y, :movement_speed

  def initialize(side, speed)
    @side             = side
    @movement_speed   = speed
    @x                = side == :left ? 40 : Window.width - 60
    @y                = (Window.height - HEIGHT) / 2
    @direction        = nil
    @speed_multiplier = 1.0
    @slow_timer       = nil
  end

  def move
    # Återställ hastighet om slow-effekten löpt ut
    if @slow_timer && Time.now > @slow_timer
      @speed_multiplier = 1.0
      @slow_timer = nil
    end

    speed = @movement_speed * @speed_multiplier
    case @direction
    when :up   then @y = [@y - speed, 0].max
    when :down then @y = [@y + speed, Window.height - HEIGHT].min
    end
  end

  def draw
    @shape = Rectangle.new(
      x: @x,
      y: @y,
      width: 25,
      height: HEIGHT,
      color: 'black'
    )
  end

  def hit_ball?(ball)
    return false unless ball.shape
    corners = [
      [ball.shape.x1, ball.shape.y1],
      [ball.shape.x2, ball.shape.y2],
      [ball.shape.x2, ball.shape.y1],
      [ball.shape.x1, ball.shape.y2]
    ]
    corners.any? { |px, py| @shape.contains?(px, py) }
  end
end

# Boll
class Ball
  SIZE = 25

  attr_reader :x, :shape, :last_hit_side

  def initialize(speed, serve_side, spawn_y)
    @speed         = speed
    @serve_side    = serve_side
    @x             = serve_side == :left ? 60 : Window.width - 60 - SIZE
    @y             = spawn_y
    @x_velocity    = 0
    @y_velocity    = 0
    @last_hit_side = nil
  end

  def serve!
    @x_velocity = @serve_side == :left ? @speed : -@speed
    @y_velocity = 0
  end

  def move
    if @y <= 0 || @y + SIZE >= Window.height
      @y_velocity = -@y_velocity
      PONG_SOUND.play
    end
    @x += @x_velocity
    @y += @y_velocity
  end

  def draw
    @shape = Square.new(
      x: @x,
      y: @y,
      size: SIZE,
      color: 'orange'
    )
  end

  def bounce_off(paddle)
    return if @last_hit_side == paddle.side
    relative = ((@y - paddle.y) / Paddle::HEIGHT.to_f).clamp(0.2, 0.8)
    angle    = relative * Math::PI
    if paddle.side == :left
      @x_velocity =  Math.sin(angle) * @speed
      @y_velocity = -Math.cos(angle) * @speed
    else
      @x_velocity = -Math.sin(angle) * @speed
      @y_velocity =  Math.cos(angle) * @speed
    end
    @last_hit_side = paddle.side
  end

  def out_of_bounds?
    @x <= 0 || @x + SIZE >= Window.width
  end
end

class SuperPower
  SIZE = 25
  attr_accessor :active
  attr_reader :shape

  def initialize(x = Window.width / 2 - SIZE/2, y = rand(0..Window.height - SIZE))
    @x = x
    @y = y
    @active = true
  end

  def draw
    return unless @active
    @shape = Square.new(
      x: @x,
      y: @y,
      size: SIZE,
      color: 'blue'
    )
  end

  def hit_by?(ball)
    return false unless @shape && @active
    corners = [
      [ball.shape.x1, ball.shape.y1],
      [ball.shape.x2, ball.shape.y2],
      [ball.shape.x2, ball.shape.y1],
      [ball.shape.x1, ball.shape.y2]
    ]
    corners.any? { |px, py| @shape.contains?(px, py) }
  end
end

# Initiera spelobjekt
player1        = Paddle.new(:left, 10)
player2        = Paddle.new(:right, 10)
serving_player = :left
scoreboard     = Scoreboard.new
spawn_y        = player1.y + Paddle::HEIGHT/2 - Ball::SIZE/2
ball           = Ball.new(10, serving_player, spawn_y)
@power_up      = SuperPower.new

# Huvudloop
update do
  clear
  case @game_state
  when :start
    draw_start_screen

  when :paused
    draw_pause_screen
    next

  when :playing
    BACKGROUND.draw
    @power_up.draw

    # Kolla powerup-collision
    if @power_up.active && ball.shape && @power_up.hit_by?(ball)
      PING_SOUND.play
      if ball.last_hit_side == :left
        target = player2
      elsif ball.last_hit_side == :right
        target = player1
      end
      if target
        target.speed_multiplier = 0.5
        target.slow_timer = Time.now + 3
      end
      @power_up.active = false
    end

    [player1, player2].each do |p|
      p.move
      p.draw
    end
    scoreboard.draw

    if @game_paused
      srv = serving_player == :left ? player1 : player2
      x0  = srv.x + (srv.side == :left ? 25 : -Ball::SIZE)
      y0  = srv.y + Paddle::HEIGHT/2 - Ball::SIZE/2
      ball.instance_variable_set(:@x, x0)
      ball.instance_variable_set(:@y, y0)
      ball.draw

      now = Time.now
      dt  = now - @last_time
      @countdown = [@countdown - dt, 0].max
      @last_time = now

      Text.new(@countdown.ceil.to_s,
               x: (Window.width/2) - 5, y: 2,
               size: 20, color: 'white')
      Text.new(serving_player == :left ? "P1 serve" : "P2 serve",
               x: (Window.width/2) - 40, y: 20,
               size: 20, color: 'white')
      next
    end

    [player1, player2].each do |p|
      if p.hit_ball?(ball)
        ball.bounce_off(p)
        PING_SOUND.play
      end
    end

    ball.move
    ball.draw

    if ball.out_of_bounds?
      OUT_SOUND.play
      scoreboard.update(ball)
      serving_player = ball.x <= 0 ? :right : :left
      spawn_y = (serving_player == :left ? player1.y : player2.y) +
                Paddle::HEIGHT/2 - Ball::SIZE/2
      ball = Ball.new(10, serving_player, spawn_y)
      @game_paused = true
      @countdown   = 3.0
      @last_time   = Time.now
    end
  end
end

# Tangenthändelser
on :key_held do |e|
  next unless @game_state == :playing
  player1.direction = :up   if e.key == 'w'
  player1.direction = :down if e.key == 's'
  player2.direction = :up   if e.key == 'up'
  player2.direction = :down if e.key == 'down'
end

on :key_up do |_e|
  next unless @game_state == :playing
  player1.direction = nil
  player2.direction = nil
end

on :key_down do |e|
  if @game_state == :playing && e.key == 'escape'
    @game_state = :paused
  elsif @game_state == :paused && e.key == 'escape'
    @game_state = :playing
  end

  if @game_state == :playing && e.key == 'space' && @game_paused && @countdown <= 0
    ball.serve!
    @game_paused = false
  end
end

# Musklick
on :mouse_down do |e|
  if @game_state == :start
    if e.x.between?(@start_button[:x], @start_button[:x] + @start_button[:width]) &&
       e.y.between?(@start_button[:y], @start_button[:y] + @start_button[:height])
      @game_state = :playing
    elsif e.x.between?(@quit_button[:x], @quit_button[:x] + @quit_button[:width]) &&
          e.y.between?(@quit_button[:y], @quit_button[:y] + @quit_button[:height])
      close
    end

  elsif @game_state == :paused
    if e.x.between?(@resume_button[:x], @resume_button[:x] + @resume_button[:width]) &&
       e.y.between?(@resume_button[:y], @resume_button[:y] + @resume_button[:height])
      @game_state = :playing
    elsif e.x.between?(@quit_to_menu_button[:x], @quit_to_menu_button[:x] + @quit_to_menu_button[:width]) &&
          e.y.between?(@quit_to_menu_button[:y], @quit_to_menu_button[:y] + @quit_to_menu_button[:height])
      scoreboard.reset!
      serving_player = :left
      @game_state    = :start
      @game_paused   = true
      @countdown     = 3.0
      @last_time     = Time.now
    end
  end
end

# Starta spelet
show