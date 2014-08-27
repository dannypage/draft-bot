#!/bin/ruby

require 'rubygems'
require 'daemons'

puts 'require success'

Daemons.run('draft.rb')

puts 'run success'