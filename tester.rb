#!/usr/bin/env ruby

require 'time'
require 'delegate'
require 'timeout'
require 'csv'

SECONDS_IN_HOUR = 3600
TIME_FORMAT = "%Y-%m-%d %H:%M"
THIRSTY_PROGRAMMER_PENALTY = 50
COLD_COFFEE_PENALTY = 1
DECISION_TIME = 2

class CoffeeTimeoutError < StandardError; end

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

  def coffee_timeout
    Timeout::timeout(DECISION_TIME, CoffeeTimeoutError) do
      yield
    end
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
    pipe.puts(coffee_history_item.time.strftime(TIME_FORMAT))
    coffee_history_item.each do |company_id, usage|
      pipe.puts(usage)
    end
    pipe.flush
  end

  def send_initial_info(timestamps)
    pipe.puts(timestamps)
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

  def size
    coffee_history_items.length
  end
end

class Referee < Struct.new(:coffee_history, :coffee_arrivals)
  def score
    results_history = []
    result = 0

    coffee_history.drop(1).each do |coffee_history_item|
      coffee_history_item.each do |company_id, usage|
        cups_arriving = coffee_arrivals.arrival(coffee_history_item.time, company_id)
        single_result = single_score(usage, cups_arriving)
        result += single_result

        results_history << {time: coffee_history_item.time, company_id: company_id,
                            expected: usage, cups: cups_arriving,
                            turn: single_result, result: result}
      end
    end

    [results_history, result]
  end


  def write_results_history_to_file(filename , results_history)
    CSV.open(filename, 'w') do |results_file|
      results_file << ['time', 'company_id', 'actual_consumption', 'cups_delivered', 'turn_result', 'total_score']
      results_history.each do |result|
        results_file << [result[:time].strftime(TIME_FORMAT), result[:company_id], result[:expected], result[:cups], result[:turn], result[:result]]
      end
    end
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

predictor = nil
coffee_timeout do
  predictor = Predictor.new(IO.popen(ARGV[0], "r+"))
  predictor.send_initial_info(coffee_history.size)
end
raise "Could not boot up predictor" unless predictor

arrivals = CoffeeArrivals.new
coffee_history.each do |coffee_history_item|
  begin
    coffee_timeout do
      predictor.set_current_state(coffee_history_item)
      arrivals.add_disposition(coffee_history_item.time, predictor.get_dispositions)
    end
  rescue CoffeeTimeoutError
    break
  end
end

referee = Referee.new(coffee_history, arrivals)
results_history, result = referee.score
referee.write_results_history_to_file('results.csv', results_history)

p result

