require "mechanize"
require "pry"
require "csv"

require "active_support/core_ext/object/try" # try
require "active_support/core_ext/object/blank" # blank
require "active_support/core_ext/enumerable" # compact_blank


require "active_support/core_ext/string/inflections" # titleize
require "active_support/core_ext/string/filters" # squish


HUGO_URL = "http://www.thehugoawards.org/hugo-history/".freeze
HUGO_FILE_NAME = "categories/hugo_results.csv".freeze
HUGO_CATEGORIES = [
  "Best Novel",
  "Best Novella",
  "Best Novelette",
  "Best Short Story",
  "Best Series",
  "Best Related Work",
  "Best Graphic Story or Comic",
  "Best Graphic Story",
  "Best Dramatic Presentation, Long Form",
  "Best Dramatic Presentation, Short Form"
].freeze

def clean_author(author_string)
  return author_string unless author_string.present?

  author_string.
    gsub(/(\u{201C}|\u{201D})/,""). # Remove smart quotes.
    gsub(/^, /,"").
    gsub(/\(.+\) */,"").
    gsub(/\[.+\] */,"").
    gsub(/\([^\)]+/,"").
    gsub(/^ ?(written by |written and directed by |by |screenplay by )/,"").
    strip
end

def clean_title(title_string)
  return title_string unless title_string.present?

  title_string.
    gsub(/(\u{201C}|\u{201D})/,"").
    strip
end

def parse_title_author(book_text)
  split_book = CSV.parse(book_text).flatten

  if split_book.size == 1
    split_book = split_book[0].split(" by ")
  end

  title = clean_title(split_book[0])
  author = clean_author(split_book[1])

  [title,author]
end

mechanize = Mechanize.new
page = mechanize.get HUGO_URL

year_links = page.
             links_with(text: /\d{4,}.+Hugo Awards/).
             map { |x| x.uri.to_s }.
             uniq

results = year_links.inject([]) do |a,url|
  awards_page = mechanize.get url

  year = url.match(/(\d{4,})/).captures.first

  child_nodes = awards_page.at_css(".entry-content").children

  child_nodes.each do |child_node|
    next unless HUGO_CATEGORIES.any? { |category| child_node.text =~ /#{category}/ }

    award = child_node.text.split("\n").first.gsub(/\(.*\d+ nominating ballots.*\)/,"")

    child = child_node.next_sibling.next_sibling

    books = child.children.map do |book|
      next if book.text.chomp.blank? || book.text == "No Award"

      place = book.attribute("class").try(:value).present? ? "Winner" : "Shortlist"

      title,author = parse_title_author(book.text)
      
      [year,award,place,title,author]
    end

    books.compact_blank!

    a << books
  end
  
  a
end

results.flatten!(1)

File.open(HUGO_FILE_NAME,"wb") do |f|
  f.write(CSV.generate_line(%i[year award list title author]))

  f.write(results.inject([]) do |csv,row|
    csv << CSV.generate_line(row)
  end.join(""))
end