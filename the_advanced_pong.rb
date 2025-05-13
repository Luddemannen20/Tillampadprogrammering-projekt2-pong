# File: the_advanced_pong.rb
# Author: Ludvig Larsson
# Date: 05/13 - 2025
# Description: Jag har gjort en modernare version av pong med hjälp av ruby 2D, spelet har både start- och pausmeny samt en powerup som gör motståndaren långsamare vid träff.
# Links to inspiration: 
# 1. https://www.youtube.com/watch?v=kgK3be5wvwI
# 2. https://www.youtube.com/watch?v=jBFBV7dByGw
# 3. https://www.youtube.com/watch?v=e3B8m4vBzB0
# 4. https://www.youtube.com/watch?v=sWsD_r_DQ4c
# 5. https://www.youtube.com/watch?v=-F2Q4wBpCoI, för att serva bollen med hjälp av space
require 'ruby2d'

#Sätter bredden och höjden på spelfönstret till 600 px
#Output: skapar själva spelfönstret med angiven storlek
set width: 600, height: 600

#Laddar in och skapar bakgruden och alla soundeffects
BACKGROUND   = Image.new('img/background.jpg', width: 600, height: 600)
PONG_SOUND   = Sound.new('sound/pongsound.wav') #studs mot vägg
PING_SOUND   = Sound.new('sound/pingsound.wav') #studs mot paddel
OUT_SOUND    = Sound.new('sound/outofbounds.mp3') #målljud

#Alla globalavariabler för spelets tillstånd
@game_state  = :start #vikket tillstånd spelet befinner sig i, kan anta :start, :pause eller :playing
@game_paused = true #är spelet pausat?, kan anta true eller false (Bool)
@countdown   = 3.0 #nedräkningsveriabel för serven, då countdown == 0 kan man serva bollen
@last_time   = Time.now #Tar tiden för senaste updaten

#Funktionen ritar upp startsmenyn
#Input: inget
#Output: ritar ut bakgrunden, titeln på spelet och kapparna start och quit
def draw_start_screen
  BACKGROUND.draw
  Text.new("WELCOME TO PONG!",
           x: (Window.width / 2) - 145,
           y: 100,
           size: 30,
           color: 'black')
  @start_button = { x: (Window.width/2) - 50, y: 250, width: 100, height: 40 }
  #Start knapp, färg: grön, textfärg: vit
  Rectangle.new(**@start_button, color: 'green')
  Text.new("Start",
           x: @start_button[:x] + 20,
           y: @start_button[:y] + 8,
           size: 20,
           color: 'white')
  #Stopp knapp, färg: röd, textfärg: vit
           @quit_button = { x: (Window.width/2) - 50, y: 320, width: 100, height: 40 }
  Rectangle.new(**@quit_button, color: 'red')
  Text.new("Quit",
           x: @quit_button[:x] + 25,
           y: @quit_button[:y] + 8,
           size: 20,
           color: 'white')
end

#Ritar upp pausemenyn 
#Input: inget
#Output: ritar ut bakgrunden samt knapparna resume och exit to menu
def draw_pause_screen
  BACKGROUND.draw
  @resume_button = { x: (Window.width/2) - 75, y: 200, width: 150, height: 50 }
  #Återupptaknapp, färg: grön, textfärg: vit
  Rectangle.new(**@resume_button, color: 'green')
  Text.new("Resume",
           x: @resume_button[:x] + 35,
           y: @resume_button[:y] + 12,
           size: 24,
           color: 'white')
  #Gåtillbaks till startmenyn knapp, färg: röd, textfärg: vit
           @quit_to_menu_button = { x: (Window.width/2) - 100, y: 300, width: 200, height: 50 }
  Rectangle.new(**@quit_to_menu_button, color: 'red')
  Text.new("Quit to main menu",
           x: @quit_to_menu_button[:x] + 15,
           y: @quit_to_menu_button[:y] + 12,
           size: 20,
           color: 'white')
end

#Klass för att kunna räkna alla poäng samt att skriva ut dom på spelskärmen
class Scoreboard
  attr_reader :left_score, :right_score
 
  #skapar en ny scoreboard med 0-0
  def initialize
    @left_score  = 0 #Poäng för spelare 1
    @right_score = 0 #Poäng för spelare 2
  end
 
  #Updatterar poängen efter att bollen har gått ut ur spelplanen
  #Input: Bollobjektet
  #Output:inkrementerar (ökar) värdet på scoreboard med 1 beroende för vem som gjort mål
  def update(ball)
    @right_score += 1 if ball.x <= 0 #Spelare 2 får poäng då bollen går ut på vänster sida
    @left_score  += 1 if ball.shape.x2 >= Window.width #Spelare 1 får poäng då bollen går ut på höger sidan
  end
 
  #Ritar ut poängen i vardera hörn
  #Input: inget
  #Output: skriver ut text med den aktuella poängen
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
  
  #nollställer poängen
  #Input: inget
  #Output: left_score och right_score blir 0
  def reset!
    @left_score = 0
    @right_score = 0
  end
end

#Klassen hanterar båda spelarnas paddelracks position, rörelse och hur kollision ska fungera
class Paddle
  HEIGHT = 150
  attr_accessor :direction, :speed_multiplier, :slow_timer
  attr_reader :side, :x, :y, :movement_speed
  
  #skapar en paddel
  #Input: vilken sida? (:left, :right), speed(bashastighet)
  #Output: placerar paddeln i mitten på storleken av skärmens y-värde
  def initialize(side, speed)
    @side             = side
    @movement_speed   = speed
    @x                = side == :left ? 40 : Window.width - 60
    @y                = (Window.height - HEIGHT) / 2
    @direction        = nil
    @speed_multiplier = 1.0
    @slow_timer       = nil
  end
  
  #uppdaterar paddelns y-värde bereonde på vilken riktning
  #Input: direction: förväntar sig :up,:down eller nil, och i vissa fall även eventuell slow_timer då powerupen är aktiv
  #Output: ändrar värdet på @y-koordinat
  def move
    #Återställer hastigheten till sitt ursprung då slow_timer är noll
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
  
  #ritar ut paddeln på skärmen
  #Input: inget
  #Output: skapar en Rectangle i variabeln @shape
  def draw
    @shape = Rectangle.new(
      x: @x,
      y: @y,
      width: 25,
      height: HEIGHT,
      color: 'black'
    )
  end

  #kollar om paddeln träffar bollen
  #Input: bollobjektet
  #Output: returnerar true om någon av bollens hörn ligger inom paddeln
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

#hanterar bollens rörelse, hur den ska studsa och serven
class Ball
  SIZE = 25
  attr_reader :x, :shape, :last_hit_side
  
  #skapar en boll för serve
  #input: hastighet, vilken sida bollen servas på (:left/:right), samt vilket starthöjd 
  #Output: ställer in initial position och sätter hastigheten till 0
  def initialize(speed, serve_side, spawn_y)
    @speed         = speed
    @serve_side    = serve_side
    @x             = serve_side == :left ? 60 : Window.width - 60 - SIZE
    @y             = spawn_y
    @x_velocity    = 0
    @y_velocity    = 0
    @last_hit_side = nil
  end
  
  #påbörjar serven genom att ge bollen en x-velocity(hastighet)
  #Input: inget
  #Output: ställer in värden på variablerna x_velocity och y_velocity vilket gör att bollen börjar röra på sig
  def serve!
    @x_velocity = @serve_side == :left ? @speed : -@speed
    @y_velocity = 0
  end
  
  #uppdaterar bollens position och hanterar studsar på väggen
  #Input: inget
  #Output: ändrar värdet på variablerna x och y då bollen studsar mot en vägg, spelar även upp PONG_SOUND
  def move
    if @y <= 0 || @y + SIZE >= Window.height
      @y_velocity = -@y_velocity
      PONG_SOUND.play
    end
    @x += @x_velocity
    @y += @y_velocity
  end
  
  #ritar upp bollen som en fyrkant
  #Input: inget
  #Output: skapar en kvadrat som lagras i variabeln shape
  def draw
    @shape = Square.new(
      x: @x,
      y: @y,
      size: SIZE,
      color: 'orange'
    )
  end
  
  #ändrar riktigningen på bollen då den träffar en paddel
  #Input: paddelobjektet
  #Output: beräknar den nya x_velocity och y_velocity bereonde på vart bollen träffar och använder trigonometriskasamband för detta.
  def bounce_off(paddle)
    return if @last_hit_side == paddle.side
    #Beräknar vinkeln utifrån var på paddeln boller träffar så att if satsen efter kan använde den för att beräkna den nya riktigtningen
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
  
  #kontrollerar om bollen gått utanför spelplanen på vänster eller höger sida
  #Input: inget
  #Output: true om x <= 0 eller x+Size >= fönsterbredd (då x = 0 är längst till vänster och ökar desto mer åt höger man går och kan som mest vara lika med bredden på spelfönstret)
  def out_of_bounds?
    @x <= 0 || @x + SIZE >= Window.width
  end
end

#hanterar powerup objektet
class SuperPower
  SIZE = 25
  attr_accessor :active
  attr_reader :shape
  
  #placerar powerupen mitt i spelpanen och på en slumpad y position mellan 0 och höjden på fönstret med hjälp av verktyget rand som generar ett värde inom detta intervall
  #Input: x och y
  #Output:sätter variabeln active till true eftersom ett nytt objekt spawnar vid varje ny runda och ritar ut den med hjälp av funktionen draw
  def initialize(x = Window.width / 2 - SIZE/2, y = rand(0..Window.height - SIZE))
    @x = x
    @y = y
    @active = true
  end
  
  #ritar ut powerup objektet om variabeln active = true
  #Input: inget
  #Output: om active = true så läggs rektangelobjektet in i variabeln shape
  def draw
    return unless @active
    @shape = Square.new(
      x: @x,
      y: @y,
      size: SIZE,
      color: 'blue'
    )
  end
  
  #kollar om bollen träffar powerupen
  #Input: bollobjektet
  #Output: returnerar true ifall någon av bollens hörn ligger inom powerupen
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

#Huvud program som skapar alla objekt utifrån funktionerna samt loopen som uppdaterar spelet och får det att köras
player1        = Paddle.new(:left, 10) #spelare 1 befinner sig till vänster och har en velocity på 10 (hastighet)
player2        = Paddle.new(:right, 10) #spelare 2
serving_player = :left #Spelare till vänster börjar alltid serva
scoreboard     = Scoreboard.new #skapar scoreboarden
spawn_y        = player1.y + Paddle::HEIGHT/2 - Ball::SIZE/2 #bestämmer vilket värde bollen ska spawna på
ball           = Ball.new(10, serving_player, spawn_y) #skapar boll objetet och har en hastighet på 10, och tar vilken spelare som servar och vilket y-värde den ska spawna på
@power_up      = SuperPower.new #skapar ett powerup objekt

update do #själva spelloopen
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
    
    #Hanterar powerup kollisionen
    if @power_up.active && ball.shape && @power_up.hit_by?(ball)
      PING_SOUND.play
      #spelaren som ska få bollen säts till en så kallad target, vilket innebär att om bollen träffar powerupen så kommer spelaren som är satt till target att minska sin hastighet till hälften tills target.slow_timer blir 0
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
    
    #uppdaterar alltid och ritar ut båda paddlarna under speletsgång
    [player1, player2].each do |p|
      p.move
      p.draw
    end
    scoreboard.draw

    #kollar vilken sida som ska serva
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
    
    #Ser till så att bollen byter riktning villd kollision
    [player1, player2].each do |p|
      if p.hit_ball?(ball)
        ball.bounce_off(p)
        PING_SOUND.play
      end
    end

    #eftersom dessa ligger i update loopen så flyttar de och ritar alltid ut bollen
    ball.move
    ball.draw

    #Kollar om bollen har gått untaför spelplanen och därmed updaterar värdet på scoreboard, ändrar värdet på variabeln serving_player och ritar ut en ny boll med en vald y position
    if ball.out_of_bounds?
      OUT_SOUND.play
      scoreboard.update(ball)
      serving_player = ball.x <= 0 ? :right : :left
      spawn_y = (serving_player == :left ? player1.y : player2.y) +
                Paddle::HEIGHT/2 - Ball::SIZE/2
      ball = Ball.new(10, serving_player, spawn_y)
      @power_up = SuperPower.new
      @game_paused = true
      @countdown   = 3.0
      @last_time   = Time.now
    end
  end
end

#Denna sektionen hanterar alla tangenttryckningar för rörelse av spelobjekt samt menyer

#Hanterar så att jag med hjälp av w och s kan strya spelare 1 uppåt eller neråt, och att jag kan styra spelare 2 med hjälp av piluppåt eller pilnedåt
on :key_held do |e|
  next unless @game_state == :playing
  player1.direction = :up   if e.key == 'w'
  player1.direction = :down if e.key == 's'
  player2.direction = :up   if e.key == 'up'
  player2.direction = :down if e.key == 'down'
end

#ser till så att knapparna stannar då man släpper knappen
on :key_up do |_e|
  next unless @game_state == :playing
  player1.direction = nil
  player2.direction = nil
end

#använder knappen esc för att kunna antigen pausa eller återuppta spelet
on :key_down do |e|
  if @game_state == :playing && e.key == 'escape'
    @game_state = :paused
  elsif @game_state == :paused && e.key == 'escape'
    @game_state = :playing
  end
  #då the current game_state är playing och nedräkningen för serven är 0 kan man trycka space för att serva igång bollen
  if @game_state == :playing && e.key == 'space' && @game_paused && @countdown <= 0
    ball.serve!
    @game_paused = false
  end
end

#modifierar alla knappar och vad som ska hända när man trycker på vardera knapp med vänstermusklick
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

#startar och visar innehållet i koden
show