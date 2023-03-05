#!/usr/bin/env ruby
require 'csv'

SLEEP_DURATION = 5
DOWNLOAD_DIR = "pdfs"

if !ARGV[0]
  puts
  puts "Download all pdfs from the output csv of the paperscraper"
  puts
  puts "Usage: ./download_pdfs.rb paperscraper.csv"
  puts
  puts "Your csv must have following header: citing_paper_pdf_url"
  exit 1
end

paper_filename = ARGV[0] || 'atoms-papers-gopstein_citation_counts.csv'

papers = CSV.table(paper_filename).map(&:to_h)

def paper_save_name(paper)
  y = paper[:citing_paper_authors].scan(/\d\d\d\d/).last
  a = paper[:citing_paper_authors].scan(/\w\w\w+/).first
  t = paper[:citing_paper_title].scan(/.*?\w\w\w+.*?\w\w\w+/).first&.gsub(/\W/, '_')

  [a, t, y].compact.join("_") + ".pdf"
end

`mkdir -p #{DOWNLOAD_DIR}`

papers.filter{|paper| !paper[:citing_paper_pdf_url].strip.empty?}.map do |paper|
  out_filename = DOWNLOAD_DIR + '/' + paper_save_name(paper)

  if File.exist?(out_filename)
    puts "#{out_filename} exists, not downloading"
  else
    cmd = "wget --user-agent=\"Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.9.0.3) Gecko/2008092416 Firefox/3.0.3\" #{paper[:citing_paper_pdf_url]} -O #{out_filename}"
    puts cmd
    `#{cmd}`
    sleep(SLEEP_DURATION)
  end
end
