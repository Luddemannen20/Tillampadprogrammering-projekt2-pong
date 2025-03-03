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
    Rectangle.new(x: @x, y: @y, width: 25, height: HEIGHT, color: 'black')
  end

  private

  def max_y
    Window.height - HEIGHT
  end
end

player = Paddle.new(:left, 5)
player2 = Paddle.new(:right, 5)


update do
  clear 

  player.move
  player.draw

  player2.draw
end

on :key_down do |event|
  if event.key == 'up'
    player.direction = :up
  elsif event.key == 'down'
    player.direction = :down
  end
end

on :key_up do |event|
player.direction = nil
end


show