require "mechanize"
require "json"
require "pry"
require "csv"
require "active_support/core_ext/enumerable" # compact_blank
require "active_support/core_ext/string/filters" # squish
require "active_support/core_ext/object/blank" # blank

ANSFIELD_URL = "https://www.anisfield-wolf.org/winners/".freeze
ANSFIELD_FILE_NAME = "categories/ansfield_wolf_results.csv".freeze


agent = Mechanize.new
page = agent.get ANSFIELD_URL

books = page.
        links.
        select { |link| link.text.to_s =~ /^\s+\d{4}\s+[^(?!Lifetime Achievement)]+/ }.
        map { |x| x.text.to_s.split("\n").map(&:squish).compact_blank }.
        uniq

File.open(ANSFIELD_FILE_NAME,"wb") do |f|
  f.write(CSV.generate_line(%i[year type title author]))

  f.write(books.inject([]) do |csv,row|
    csv << CSV.generate_line(row[0..3])
  end.join(""))
end