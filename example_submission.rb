#!/usr/bin/env ruby

class CoffeeSupplier
  def run
    read_initial_info

    @turns.times do
      turn
    end
  end

  def turn
    debug(readline)

    @companies.times do
      a = readline
      debug(a)
      puts a.to_i
    end

    $stdout.flush
  end

  private

  def read_initial_info
    @companies = readline.to_i
    @delivery_times = (0...@companies).map { readline.to_i }
    @turns = readline.to_i
  end


  def debug(string)
    $stderr.puts("CLIENT: #{string}")
  end
end

CoffeeSupplier.new.run