#!/usr/bin/env ruby

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
  # p bitcoin.getbalance
  def initialize(service_url, size)
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

  def point_info(x, y)
    result = {
      addresses: []
    }

    max_balance = 0.0
    dominant_color = @colors.sample
    @colors.each do |clr|
      acc = account(clr, x, y)
      result[:addresses].push({
        color: clr,
        account: acc,
        address: address(acc),
        balance: balance(acc)
      })
      new_balance = balance(acc)
      if new_balance > max_balance
        max_balance = new_balance
        dominant_color = clr
      end
    end

    result[:color] = dominant_color
    result[:balance] = max_balance

    result
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

  def to_hash
    map = {}

    (0...@width).each do |x|
      (0...@height).each do |y|
        key = "#{x}#{@separator}#{y}"
        map[key] = point_info(x, y)
        p key
      end
    end

    {
      ts: @ts,
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

base_dir = File.join(File.dirname(__FILE__), '../public/api/')
FileUtils.mkdir_p base_dir

uri = ENV['PLACED_URI'] || 'http://user:password@127.0.0.1:8332'
p uri
bitcoin = Bitcoin.new(uri, 100)
hash = bitcoin.to_hash

path = File.join(base_dir, 'place.json')
File.open(path,'w') { |f| f.write(hash.to_json) }

png = ChunkyPNG::Image.new(bitcoin.width, bitcoin.height, ChunkyPNG::Color::TRANSPARENT)
hash[:map].keys.each do |key|
  x = key.split(',')[0].to_i
  y = key.split(',')[1].to_i
  png[x,y] = ChunkyPNG::Color.from_hex("#{hash[:map][key][:color]}")
end
png.save(File.join(base_dir, 'place.png'), :interlace => false)

p "Balance: #{bitcoin.getbalance}"
