#!/usr/bin/env ruby
require 'csv'
require 'open-uri'
require 'nokogiri'
require 'pp'

SLEEP_DURATION = 5
CACHE_DIR = "cache"

if !ARGV[0]
  puts
  puts "Download all citations of the given papers"
  puts
  puts "Usage: ./scholarscraper.rb papers.csv"
  puts
  puts "Your csv must have following headers: Year, Title, Authors"
  puts "Any column can be left blank for convenience"
  exit 1
end

papers = CSV.table(ARGV[0]).map(&:to_h)

def paper_cache_name(paper)
  y = paper[:year]
  a = paper[:authors].scan(/\w\w\w+/).first
  t = paper[:title].scan(/.*?\w\w\w+.*?\w\w\w+/).first.gsub(/\W/, '_')

  "#{CACHE_DIR}/#{y}_#{a}_#{t}.html"
end

def citation_url_cache_name(citation_url, offset)
  id = citation_url.scan(/\d\d\d\d+/).first
  '%s/cites_%d_%03d.html'%[CACHE_DIR, id, offset]
end

def query_scholar_for_paper(paper)
  url = "https://scholar.google.com/scholar?hl=en&q='#{paper[:title]}' #{paper[:year]} #{paper[:authors]}&btnG=&as_sdt=1%2C33&as_sdtp="
  URI.open(url).read
end

def query_scholar_by_rel_link(link, offset)
  url = "https://scholar.google.com/#{link}&start=#{offset}"
  URI.open(url).read
end

scholar_queries = papers.map do |paper|
 cn = paper_cache_name(paper)
 if File.exist?(cn)
   open(cn).read
 else
   if !File.exist?(CACHE_DIR)
     Dir.mkdir(CACHE_DIR)
   end
   result = query_scholar_for_paper(paper)
   File.write(paper_cache_name(paper), result)
   sleep SLEEP_DURATION
   result
 end
end

citation_links = scholar_queries.map do |html|
  doc = Nokogiri::HTML(html)
  matches = doc.xpath('//a[starts-with(text(), "Cited by")]/@href')
  matches.first.to_s
end.compact.reject(&:empty?)


citation_htmls = citation_links.map do |link|
 offset = 0
 results = []
 more_results = true

 while more_results
   cn = citation_url_cache_name(link, offset)
   html =
     if File.exist?(cn)
       URI.open(cn).read
     else
       result = query_scholar_by_rel_link(link, offset)
       File.write(citation_url_cache_name(link, offset), result)
       sleep SLEEP_DURATION
       result
     end
  results << html
  doc = Nokogiri::HTML(html)
  matches = doc.xpath('//b[text()="Next" and not(contains(@style,"hidden"))]')
  more_results = !!matches.first
  offset += 10
 end

 results
end

citing_papers = citation_htmls.flatten.map do |html|
  doc = Nokogiri::HTML(html)
  cited_title = doc.xpath('//div[@class="gs_r"]/h2/a/text()').text

  divs = doc.xpath('//div[@class="gs_ri"]')
  citers = divs.map do |div|
    title = div.xpath('./h3[@class="gs_rt"]/a/text()').text
    if title.empty?
      title = div.xpath('./h3[@class="gs_rt"]/text()').text
    end
    authors = div.xpath('./div[@class="gs_a"]//text()').map(&:text).join
    summary = div.xpath('./div[@class="gs_rs"]/text()')
    pdf_url = div.parent.xpath('.//div[@class="gs_or_ggsm"]/a/@href').first&.text
    n_citations = div.xpath('./div/a[starts-with(text(), "Cited by")]').text
    {title: title, authors: authors, summary: summary, pdf_url: pdf_url, n_citations: n_citations, cited_title: cited_title}
  end
end.flatten(1)

#pp citing_papers.take(3)

counted_citers = citing_papers.group_by{|c| c[:title]}.map do |title, list|
  citing_paper = list.first

  authors = citing_paper[:authors].encode('UTF-8', :invalid=>:replace).split(/- |\d{4}/).first
  year = citing_paper[:authors].encode('UTF-8', :invalid=>:replace).scan(/\d{4}/).first

  {
    title: title,
    authors: authors,
    year: year,
    n_cited_by: citing_paper[:n_citations],
    summary: citing_paper[:summary],
    n_cited: list.size,
    pdf_url: citing_paper[:pdf_url],
    cited_papers: list.map{|c| c[:cited_title].split(" ").take(2).join(" ")}.join(" | "),
  }
end.sort_by{|x| [-x[:n_cited], -x[:n_cited_by].split(" ").last.to_i]}

input_prefix = ARGV[0].split('.').first

CSV.open(input_prefix+"_citation_counts.csv", "w") do |csv|
  csv << counted_citers.first.keys

  counted_citers.each do |citer|
    csv << citer.map do |k, v|
      v.to_s.encode('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: '')
    end
  end
end

