#!/usr/bin/env ruby

def debug(string)
  $stderr.puts("CLIENT: #{string}")
end

def read_initial_info
  decisions = readline.to_i
end

def iteration
  debug(readline)
  3.times { a = readline; debug(a); puts a.to_i }
  $stdout.flush
end

decisions = read_initial_info
decisions.times do
  iteration
end
