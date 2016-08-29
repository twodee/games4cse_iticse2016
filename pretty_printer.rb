#!/usr/bin/env ruby

require 'nokogiri'

doc = File.open(ARGV[0]) { |f| Nokogiri::HTML(f) }

class Visitor
  def initialize
    @is_printing = false
  end

  def visit node, level = 0
    print "#{'  ' * level}<#{node.name}"
    if node.element?
      node.attributes.each { |key, value| print " #{key}=\"#{value}\"" }
    end
    puts '>'
    if node.text?
      puts "#{'  ' * level}#{node.text}"
    end
    node.children.each do |child|
      visit child, level + 1
    end
    puts "#{'  ' * level}</#{node.name}>" 
  end
end

visitor = Visitor.new
visitor.visit(doc)
