#!/usr/bin/env ruby

require 'chunky_png'
require 'color'

colors = ['ffffff', 'e4e4e4', '888888', '222222', 'ffa7d1', 'e50000', 'e59500', 'a06a42', 'e5d900', '94e044', '02be01', '00d3dd', '0083c7', '0000ea', 'cf6ee4', '820080']
colors = colors.map { |color| "##{color}".match(/#(..)(..)(..)/) }.map { |a| Color::RGB.new(a[1].hex, a[2].hex, a[3].hex )}
p colors

image = ChunkyPNG::Image.from_file('doge.png')

(0...image.height).each do |y|
  (0...image.width).each do |x|
    arr = [ChunkyPNG::Color.r(image[x,y]), ChunkyPNG::Color.g(image[x,y]), ChunkyPNG::Color.b(image[x,y]), ChunkyPNG::Color.a(image[x,y])]
    tc = Color::RGB.new(arr[0], arr[1], arr[2])
    closest = tc.closest_match(colors)
    image[x,y] = ChunkyPNG::Color.from_hex(closest.hex)
  end
end


# image.save('output_cheat.png')

w = 20
h = 20
image.resize(w, h).save('output_tmp.png')
