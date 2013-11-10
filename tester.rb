#!/usr/bin/env ruby

require 'time'
require 'delegate'

class Predictor
end

def lines_to_mapping(lines)
  pairs = lines.each_with_index.
    map { |line, company_id| [company_id, line.to_i] }
  Hash[pairs]
end

class CompanyMap < Struct.new(:distances)
  def size
    distances.size
  end

  def distance(company_id)
    distances[company_id] or raise
  end
end

def read_company_map(file_name)
  lines = File.read(file_name).split("\n")
  CompanyMap.new(lines_to_mapping(lines.drop(1)))
end

class CoffeeHistoryItem < Struct.new(:time, :usages)
  def usage(company_id)
    usage[company_id] or raise
  end
end

class CoffeeHistory < Struct.new(:coffee_history_items)
end

def read_coffee_history(file_name, no_companies)
  lines = File.read(file_name).split("\n").drop(1)
  items = lines.each_slice(no_companies + 1).map do |history_item|
    time = Time.parse(history_item.first)
    CoffeeHistoryItem.new(time, lines_to_mapping(history_item.drop(1)))
  end
  CoffeeHistory.new(items)
end

companies = read_company_map("map.data")
p companies
p read_coffee_history("test.data", companies.size)

