#!/usr/bin/env ruby

require 'time'
require 'delegate'

module Utils
  def lines_to_mapping(lines)
    pairs = lines.each_with_index.
      map { |line, company_id| [company_id, line.to_i] }
    Hash[pairs]
  end

  def read_company_map(file_name)
    lines = File.read(file_name).split("\n")
    CompanyMap.new(lines_to_mapping(lines.drop(1)))
  end

  def read_coffee_history(file_name)
    lines = File.read(file_name).split("\n").drop(1)
    items = lines.each_slice(COMPANY_MAP.size + 1).map do |history_item|
      time = Time.parse(history_item.first)
      CoffeeHistoryItem.new(time, lines_to_mapping(history_item.drop(1)))
    end
    CoffeeHistory.new(items)
  end
end
include Utils

class CompanyMap < Struct.new(:distances)
  def size
    distances.size
  end

  def distance(company_id)
    distances[company_id] or raise
  end
end

COMPANY_MAP = read_company_map("map.data")

class Predictor < Struct.new(:pipe)
  def set_current_state(coffee_history_item)
    pipe.puts(coffee_history_item.time.strftime("%Y-%m-%d %H:%M"))
    coffee_history_item.each do |company_id, usage|
      pipe.puts(usage)
    end
    pipe.flush
  end

  def get_dispositions
    COMPANY_MAP.size.times { pipe.readline }
  end
end

class CoffeeHistoryItem < Struct.new(:time, :usages)
  def each
    (0...COMPANY_MAP.size).each do |company_id|
      yield(company_id, usage(company_id))
    end
  end

  def usage(company_id)
    usages[company_id] or raise
  end
end

class CoffeeHistory < Struct.new(:coffee_history_items)
  def each
    coffee_history_items.each do |item|
      yield item
    end
  end
end

coffee_history = read_coffee_history("test.data")
predictor = Predictor.new(IO.popen(ARGV[0], "r+"))

coffee_history.each do |coffee_history_item|
  predictor.set_current_state(coffee_history_item)
  predictor.get_dispositions
end

