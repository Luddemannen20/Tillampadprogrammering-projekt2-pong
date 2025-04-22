require 'ruby2d'

set width: 600, height: 600

# Bakgrund och ljud
image          = Image.new('img/background.jpg', width: 600, height: 600)
PONG_SOUND     = Sound.new('sound/pongsound.wav')
PING_SOUND     = Sound.new('sound/pingsound.wav')
out_of_bounds  = Sound.new('sound/outofbounds.mp3')

# Power‑up inställningar
POWERUP_IMAGE       = 'img/powerup.png'
POWERUP_SIZE        = 30
POWERUP_SLOW_FACTOR = 0.5    # 0.5 = halva hastigheten
POWERUP_DURATION    = 3.0    # varaktighet i sekunder

@game_state = :start

def draw_start_screen
  Image.new('img/background.jpg', width: 600, height: 600).draw
  Text.new("WELCOME TO PONG!",
           x: (Window.width / 2) - 145, y: 100, size: 30, color: 'black')
  @start_button = { x: (Window.width/2)-50, y: 250, width: 100, height: 40 }
  Rectangle.new(x: @start_button[:x], y: @start_button[:y],
                width: @start_button[:width], height: @start_button[:height],
                color: 'green')
  Text.new("Start", x: @start_button[:x]+20, y: @start_button[:y]+8,
           size: 20, color: 'white')

  @quit_button = { x: (Window.width/2)-50, y: 320, width: 100, height: 40 }
  Rectangle.new(x: @quit_button[:x], y: @quit_button[:y],
                width: @quit_button[:width], height: @quit_button[:height],
                color: 'red')
  Text.new("Quit", x: @quit_button[:x]+25, y: @quit_button[:y]+8,
           size: 20, color: 'white')
end

def draw_pause_screen
  Image.new('img/background.jpg', width: 600, height: 600).draw
  @resume_button = { x: (Window.width/2)-75, y: 200, width: 150, height: 50 }
  Rectangle.new(x: @resume_button[:x], y: @resume_button[:y],
                width: @resume_button[:width], height: @resume_button[:height],
                color: 'green')
  Text.new("Resume", x: @resume_button[:x]+35, y: @resume_button[:y]+12,
           size: 24, color: 'white')

  @quit_to_menu_button = { x: (Window.width/2)-100, y: 300, width: 200, height: 50 }
  Rectangle.new(x: @quit_to_menu_button[:x], y: @quit_to_menu_button[:y],
                width: @quit_to_menu_button[:width],
                height: @quit_to_menu_button[:height],
                color: 'red')
  Text.new("Quit to main menu", x: @quit_to_menu_button[:x]+15,
           y: @quit_to_menu_button[:y]+12, size: 20, color: 'white')
end

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
    Text.new("Left: #{@left_score}",  x: 20, y: 20, size: 20, color: 'white')
    Text.new("Right: #{@right_score}", x: Window.width-120, y: 20,
             size: 20, color: 'white')
  end
end

class Paddle
  HEIGHT = 150
  attr_writer :direction
  attr_reader :side, :y, :x, :movement_speed

  def initialize(side, movement_speed)
    @side           = side
    @movement_speed = movement_speed
    @direction      = nil
    @y              = 200
    @x              = (side == :left ? 40 : Window.width - 60)
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
    return false unless ball.shape
    [[ball.shape.x1,ball.shape.y1],
     [ball.shape.x2,ball.shape.y2],
     [ball.shape.x3,ball.shape.y3],
     [ball.shape.x4,ball.shape.y4]].any? do |px, py|
      @shape.contains?(px, py)
    end
  end

  def y1; @shape.y1; end

  private
  def max_y; Window.height - HEIGHT; end
end

class Ball
  HEIGHT = 25
  attr_reader :shape, :x, :y, :last_hit_side

  def initialize(speed, serve=nil, spawn_y=nil)
    @speed      = speed
    @serve_side = serve
    @x = case serve
         when :left  then 60
         when :right then Window.width - 60 - HEIGHT
         else           Window.width / 2
         end
    @y             = spawn_y || Window.height / 2
    @x_velocity    = 0
    @y_velocity    = 0
    @last_hit_side = nil
  end

  def serve!
    @x_velocity = (@serve_side == :left ? @speed : -@speed)
    @y_velocity = 0
  end

  def move
    if hit_bottom? || hit_top?
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
    return if @last_hit_side == paddle.side
    pos   = ((@shape.y1 - paddle.y1) / Paddle::HEIGHT.to_f).clamp(0.2,0.8)
    angle = pos * Math::PI
    if paddle.side == :left
      @x_velocity = Math.sin(angle) * @speed
      @y_velocity = -Math.cos(angle) * @speed
    else
      @x_velocity = -Math.sin(angle) * @speed
      @y_velocity =  Math.cos(angle) * @speed
    end
    @last_hit_side = paddle.side
  end

  def out_of_bounds?; @x <= 0 || @shape.x2 >= Window.width; end

  private
  def hit_bottom?; @y + HEIGHT >= Window.height; end
  def hit_top?;    @y <= 0;                 end
end

class PowerUp
  attr_reader :shape

  def initialize(img, size)
    @size = size
    @x    = (Window.width  - size) / 2    # centrerat på X
    @y    = rand(0...(Window.height - size))  # slumpad Y
    @image = Image.new(img, x: @x, y: @y,
                       width: @size, height: @size)
    @shape = Rectangle.new(x: @x, y: @y,
                           width: @size, height: @size,
                           color: [0,0,0,0])
  end

  def draw
    @image.draw
  end

  def hit_ball?(ball)
    return false unless ball.shape
    [[ball.shape.x1,ball.shape.y1],
     [ball.shape.x2,ball.shape.y2],
     [ball.shape.x3,ball.shape.y3],
     [ball.shape.x4,ball.shape.y4]].any? { |px,py| @shape.contains?(px,py) }
  end
end

# Init spelobjekt
ball_velocity    = 10
player1          = Paddle.new(:left, 10)
player2          = Paddle.new(:right, 10)
@serving_player  = :left
scoreboard       = Scoreboard.new

@powerup          = nil
@powerup_active   = false
@powerup_target   = nil
@powerup_original = nil
@powerup_end_time = nil

spawn_y = (@serving_player == :left ? player1.y : player2.y) +
          Paddle::HEIGHT/2 - Ball::HEIGHT/2
ball    = Ball.new(ball_velocity, @serving_player, spawn_y)

@game_paused    = true
@countdown_time = 3.0
@last_time      = Time.now

def start_countdown
  @game_paused    = true
  @countdown_time = 3.0
  @last_time      = Time.now
end

update do
  clear
  case @game_state
  when :start   then draw_start_screen
  when :paused  then draw_pause_screen; next
  when :playing
    image.draw
    [player1, player2].each { |p| p.move; p.draw }
    scoreboard.draw

    # skapa powerup om ej existerar
    if @powerup.nil? && !@powerup_active
      @powerup = PowerUp.new(POWERUP_IMAGE, POWERUP_SIZE)
    end

    if @game_paused
      serving = (@serving_player == :left ? player1 : player2)
      x_pos   = serving.side == :left ?
                serving.x + 25 : serving.x - Ball::HEIGHT
      y_pos   = serving.y + Paddle::HEIGHT/2 - Ball::HEIGHT/2
      ball.instance_variable_set(:@x, x_pos)
      ball.instance_variable_set(:@y, y_pos)
      ball.draw
      now = Time.now
      dt  = now - @last_time
      @countdown_time = [@countdown_time - dt, 0].max
      @last_time = now
      Text.new(@countdown_time.ceil.to_s,
               x: (Window.width/2)-5, y: 2,
               size: 20, color: 'white')
      serve_text = @serving_player == :left ? "P1 serve" : "P2 serve"
      Text.new(serve_text,
               x: (Window.width/2)-40, y: 20,
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

    @powerup.draw if @powerup

    if @powerup && @powerup.hit_ball?(ball)
      target           = ball.last_hit_side == :left ? player2 : player1
      @powerup_original = target.movement_speed
      target.instance_variable_set(:@movement_speed,
                                   @powerup_original * POWERUP_SLOW_FACTOR)
      @powerup_target   = target
      @powerup_end_time = Time.now + POWERUP_DURATION
      @powerup          = nil
      @powerup_active   = true
    end

    if @powerup_active && Time.now >= @powerup_end_time
      @powerup_target.instance_variable_set(:@movement_speed,
                                             @powerup_original)
      @powerup_active   = false
      @powerup_target   = nil
      @powerup_original = nil
      @powerup_end_time = nil
    end

    if ball.out_of_bounds?
      out_of_bounds.play
      scoreboard.update(ball)
      @serving_player = ball.x <= 0 ? :right : :left
      spawn_y = (@serving_player == :left ? player1.y : player2.y) +
                Paddle::HEIGHT/2 - Ball::HEIGHT/2
      ball = Ball.new(ball_velocity, @serving_player, spawn_y)
      start_countdown
    end
  end
end

# Input-hantering
on :key_held do |e|
  if @game_state == :playing
    player1.direction = :up   if e.key == 'w'
    player1.direction = :down if e.key == 's'
    player2.direction = :up   if e.key == 'up'
    player2.direction = :down if e.key == 'down'
  end
end

on :key_up do |_e|
  if @game_state == :playing
    player1.direction = nil
    player2.direction = nil
  end
end

on :key_down do |e|
  if @game_state == :playing && e.key == 'escape'
    @game_state = :paused
  elsif @game_state == :paused && e.key == 'escape'
    @game_state = :playing
  end
  if @game_state == :playing && e.key == 'space' &&
     @game_paused && @countdown_time <= 0
    ball.serve!
    @game_paused = false
  end
end

on :mouse_down do |e|
  if @game_state == :start
    if e.x.between?(@start_button[:x], @start_button[:x]+@start_button[:width]) &&
       e.y.between?(@start_button[:y], @start_button[:y]+@start_button[:height])
      @game_state = :playing
    elsif e.x.between?(@quit_button[:x], @quit_button[:x]+@quit_button[:width]) &&
          e.y.between?(@quit_button[:y], @quit_button[:y]+@quit_button[:height])
      close
    end
  elsif @game_state == :paused
    if e.x.between?(@resume_button[:x], @resume_button[:x]+@resume_button[:width]) &&
       e.y.between?(@resume_button[:y], @resume_button[:y]+@resume_button[:height])
      @game_state = :playing
    elsif e.x.between?(@quit_to_menu_button[:x],
                      @quit_to_menu_button[:x]+@quit_to_menu_button[:width]) &&
          e.y.between?(@quit_to_menu_button[:y],
                      @quit_to_menu_button[:y]+@quit_to_menu_button[:height])
      scoreboard = Scoreboard.new
      @serving_player = :left
      start_countdown
      @game_state = :start
    end
  end
end

show