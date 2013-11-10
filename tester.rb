#!/usr/bin/env ruby

require 'time'
require 'delegate'

SECONDS_IN_HOUR = 3600
THIRSTY_PROGRAMMER_PENALTY = 50
COLD_COFFEE_PENALTY = 1

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
  include Utils

  def set_current_state(coffee_history_item)
    pipe.puts(coffee_history_item.time.strftime("%Y-%m-%d %H:%M"))
    coffee_history_item.each do |company_id, usage|
      pipe.puts(usage)
    end
    pipe.flush
  end

  def get_dispositions
    lines = COMPANY_MAP.size.times.map { pipe.readline }
    Disposition.new(lines_to_mapping(lines))
  end
end

class Disposition < Struct.new(:sent_cups)
  def each
    (0...COMPANY_MAP.size).each do |company_id|
      yield(company_id, sent_cups[company_id])
    end
  end
end

class CoffeeArrivals
  def add_disposition(time, disposition)
    disposition.each do |company_id, cups|
      arrival_time = time + COMPANY_MAP.distance(company_id) * SECONDS_IN_HOUR
      arrivals[[arrival_time, company_id]] = cups
    end
  end

  def arrival(time, company_id)
    arrivals[[time, company_id]]
  end

  private
  def arrivals
    @arrivals ||= Hash.new(0)
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
  include Enumerable

  def each
    coffee_history_items.each do |item|
      yield item
    end
  end
end

class Referee < Struct.new(:coffee_history, :coffee_arrivals)
  def score
    result = 0

    coffee_history.drop(1).each do |coffee_history_item|
      coffee_history_item.each do |company_id, usage|
        cups_arriving = coffee_arrivals.arrival(coffee_history_item.time, company_id)
        result += single_score(usage, cups_arriving)
      end
    end

    result
  end

  private
  def single_score(expected, actual)
    if expected > actual
      THIRSTY_PROGRAMMER_PENALTY * (expected - actual)
    else
      COLD_COFFEE_PENALTY * (actual - expected)
    end
  end
end

coffee_history = read_coffee_history("test.data")
predictor = Predictor.new(IO.popen(ARGV[0], "r+"))
arrivals = CoffeeArrivals.new

coffee_history.each do |coffee_history_item|
  predictor.set_current_state(coffee_history_item)
  arrivals.add_disposition(coffee_history_item.time, predictor.get_dispositions)
end

p Referee.new(coffee_history, arrivals).score

