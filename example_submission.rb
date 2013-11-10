#!/usr/bin/env ruby

def debug(string)
  $stderr.puts("CLIENT: #{string}")
end

3.times do
  debug(readline)
  3.times { a = readline; debug(a); puts a }
  $stdout.flush
end

