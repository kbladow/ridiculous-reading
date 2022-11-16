require "mechanize"
require "pry"
require "csv"
require "active_support/core_ext/enumerable" # compact_blank
require "active_support/core_ext/object/blank" # blank
require "active_support/core_ext/string/inflections" # titleize


WOMENS_PRIZE_URL = "https://womensprizeforfiction.co.uk/reading-women".freeze
WOMENS_PRIZE_NAME = "categories/womens_prize_results.csv".freeze

agent = Mechanize.new
page = agent.get WOMENS_PRIZE_URL

winner_links = page.
               links_with(
                 href: /features.book/,
                 text: /^(?!Explore this title)/
               ).
               map { |x| x.uri.to_s }.
               uniq

book_links = winner_links.inject([]) do |a,e|
  page = agent.get e

  year = page.
         body.
         match(/(?:(\d{4}) (?:long|short)list|(?:(?:long|short)list (\d{4})))/i).
         captures.
         compact_blank.
         first

  links = page.
          links_with(href: /features.book/).
          map { |x| x.uri.to_s }.
          group_by(&:itself).
          transform_values(&:count)

  links.delete_if { |url,num| num != 3 && winner_links.include?(url) }

  a << [year,links]

  a
end

books = book_links.inject([]) do |a,(year,links)|
  links.each do |(url,num)|
    page = agent.get url

    author = page.at_css(".book__author > a:nth-child(1)").text
    title = page.at_css(".book__title").text.titleize

    author = nil if title.downcase == author.downcase
  
    if title =~ / . \d+{4,}/
      title = title.match(/(.+) . \d+{4,}.+/).captures.first
    end

    award = case num
            when 1
              "Longlist"
            when 2
              "Shortlist"
            when 3
              "Winner"
            end


    a << [year,award,title,author]

    a
  end

  a
end

File.open(WOMENS_PRIZE_NAME,"wb") do |f|
  f.write(CSV.generate_line(%i[year award title author]))

  f.write(books.inject([]) do |csv,row|
    csv << CSV.generate_line(row[0..3])
  end.join(""))
end