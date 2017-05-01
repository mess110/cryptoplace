#!/usr/bin/env ruby

require 'pp'
require 'net/http'
require 'uri'
require 'json'
require 'fileutils'

require 'chunky_png'

class BitcoinRPC
  def initialize(service_url)
    @uri = URI.parse(service_url)
  end

  def method_missing(name, *args)
    post_body = { 'method' => name, 'params' => args, 'id' => 'jsonrpc' }.to_json
    resp = JSON.parse( http_post_request(post_body) )
    raise JSONRPCError, resp['error'] if resp['error']
    resp['result']
  end

  def http_post_request(post_body)
    http    = Net::HTTP.new(@uri.host, @uri.port)
    request = Net::HTTP::Post.new(@uri.request_uri)
    request.basic_auth @uri.user, @uri.password
    request.content_type = 'application/json'
    request.body = post_body
    http.request(request).body
  end

  class JSONRPCError < RuntimeError; end
end

class Bitcoin

  attr_accessor :prefix, :separator, :width, :height, :colors, :rpc

  # bitcoin = Bitcoin.new('http://user:password@127.0.0.1:8332')
  # puts bitcoin.getbalance
  def initialize(service_url, size)
    puts "Connecting to #{service_url}"

    @ts = Time.now.to_i
    @width = size
    @height = size
    @prefix = 'p'
    @separator = ','
    @colors = ['ffffff', 'e4e4e4', '888888', '222222', 'ffa7d1', 'e50000', 'e59500', 'a06a42', 'e5d900', '94e044', '02be01', '00d3dd', '0083c7', '0000ea', 'cf6ee4', '820080'];

    @rpc = BitcoinRPC.new(service_url)
    # https://en.bitcoin.it/wiki/Original_Bitcoin_client/API_calls_list
    @allowed_methods = [
      :getbalance,
      :getinfo,
      :listaddressgroupings,
      :getnewaddress, # name
      :listaccounts,
      :getaddressbyaccount,
      :listreceivedbyaddress,
      :getreceivedbyaddress,
      :gettransaction,
      :getpeerinfo,
      :getreceivedbyaccount,

      :getaccountaddress,
      :listtransactions
    ]
  end

  def method_missing(name, *args)
    raise RuntimeError, "invalid method '#{name}'. allowed methods are: #{@allowed_methods.join(', ')}" if !@allowed_methods.include?(name)
    @rpc.send(name, *args)
  end

  def account(color, x, y)
    validate_color(color)
    [@prefix, color, x, y].join(@separator)
  end

  def point_info(x, y, default_value)
    result = {
      addresses: []
    }

    max_amount = 0.0
    dominant_index = @colors.index(default_value) || 0
    @colors.each_with_index do |clr, i|
      acc = account(clr, x, y)
      new_amount = balance(acc)
      result[:addresses].push({
        color: clr,
        account: acc,
        address: address(acc),
        amount: new_amount
      })
      if new_amount != 0
        p new_amount
        p acc
      end
      if new_amount > max_amount
        max_amount = new_amount
        dominant_index = i
      end
    end

    result[:dominant_index] = dominant_index
    result[:x] = x
    result[:y] = y

    result
  end

  def received(account)
    @rpc.getreceivedbyaccount account
  end

  def balance(account)
    @rpc.getbalance account
  end

  def address(account)
    @rpc.getaccountaddress account
  end

  def transactions(account)
    @rpc.listtransactions account
  end

  def to_hash(default_image=nil)
    map = {}

    (0...@width).each do |x|
      (0...@height).each do |y|
        key = "#{x}#{@separator}#{y}"
        map[key] = point_info(x, y, default_image.pixel_color(x, y))
        # puts key
      end
    end

    {
      ts: @ts,
      prefix: @prefix,
      separator: @separator,
      colors: @colors,
      width: @width,
      height: @height,
      map: map
    }
  end

  private

  def validate_color(color)
    raise 'invalid color' unless @colors.include?(color)
  end
end

def write_data bitcoin
  base_dir = File.join(File.dirname(__FILE__), '../public/api/')
  FileUtils.mkdir_p base_dir

  default_image = ChunkyPNG::Image.from_file(File.join(base_dir, '..', 'blank.png'))

  start = Time.now
  hash = bitcoin.to_hash(default_image)
  finish = Time.now
  puts "Took #{(finish - start).round(2)} seconds"

  path = File.join(base_dir, 'place.json')
  File.open(path,'w') { |f| f.write(hash.to_json) }

  png = ChunkyPNG::Image.new(bitcoin.width, bitcoin.height, ChunkyPNG::Color::TRANSPARENT)
  hash[:map].keys.each do |key|
    x = key.split(',')[0].to_i
    y = key.split(',')[1].to_i

    point_info = hash[:map][key]
    hex = point_info[:addresses][point_info[:dominant_index]][:color]
    png[x,y] = ChunkyPNG::Color.from_hex(hex)
  end
  png.save(File.join(base_dir, 'place.png'), :interlace => false)
end

class ChunkyPNG::Image
  def pixel_color(x, y)
    arr = [ChunkyPNG::Color.r(self[x,y]), ChunkyPNG::Color.g(self[x,y]), ChunkyPNG::Color.b(self[x,y])]
    arr.map {|z| z.to_s(16).rjust(2, '0')}.join
  end
end

uri = ENV['PLACED_URI'] || 'http://user:password@127.0.0.1:8332'

bitcoin = Bitcoin.new(uri, 100)
write_data(bitcoin)
# puts "Balance: #{bitcoin.getbalance}"

# pp bitcoin.point_info 45, 46
# puts "#{bitcoin.gettransaction("bc925e7a03786e4a101de8f0220560c2066cfee9b32973d086034148deb53311")}"
# puts bitcoin.getpeerinfo
