#!/bin/env ruby
# encoding: utf-8

require 'scraperwiki'
require 'nokogiri'
require 'colorize'
require 'pry'
require 'open-uri/cached'
OpenURI::Cache.cache_path = '.cache'

class String
  def tidy
    self.gsub(/[[:space:]]+/, ' ').strip
  end
end

def noko_for(url)
  begin
    noko = Nokogiri::HTML(open(url).read) 
  rescue => e
    warn "#{url}: #{e}"
    return 
  end
  return noko
end

def scrape_list(url, house)
  warn url
  noko = noko_for(url)
  noko.css('#itemListPrimary .itemContainer').each do |person|
    data = { 
      # id: td[0].text.tidy,
      id: person.css('h3.catItemTitle a/@href').text.split('/').last.sub(/^hon-/,''),
      name: person.css('h3.catItemTitle').text.tidy.sub(/^Hon\.? /i,''),
      image: person.css('.catItemImage img/@src').text,
      party: person.xpath('.//li/span[.="Affiliation"]/following-sibling::span').text.tidy,
      area:  person.xpath('.//li/span[.="Constituency"]/following-sibling::span').text.tidy,
      house: house,
      source: person.css('h3.catItemTitle a/@href').text,
    }
    data[:image] = URI.join(url, data[:image]).to_s.sub('_XS','_XL') unless data[:image].to_s.empty?
    data[:source] = URI.join(url, data[:source]).to_s unless data[:image].to_s.empty?
    data.merge!(scrape_person(data[:source]))
    ScraperWiki.save_sqlite([:id], data)
  end

  unless (next_page = noko.css('li.pagination-next a/@href')).empty?
    scrape_list(URI.join(url, next_page.text), house)
  end
end

def scrape_person(url)
  noko = noko_for(url) or return {}
  leg = noko.css('#leg')
  full = noko.css('.itemFullText')

  data = { 
    gender: leg.xpath('.//li/span[.="Gender:"]/following-sibling::span').text.tidy.downcase,
    email: leg.xpath('.//li/span[.="Email:"]/following-sibling::span/a/@href').text.sub('mailto:','').gsub(/\s?@\s?/,'@').split(' ').last,
    address: full.xpath('.//strong[contains(.,"Postal")]/following-sibling::span').text.tidy,
    home_address: full.xpath('.//strong[contains(.,"residential")]/following-sibling::span').text.tidy,
    cell: full.xpath('.//strong[contains(.,"Cell")]/following-sibling::span').text.tidy,
    phone: full.xpath('.//strong[contains(.,"Home telephone")]/following-sibling::span').text.tidy,
  }
  return data
end

scrape_list('http://www.parlzim.gov.zw/senators-members/members', 'assembly')
scrape_list('http://www.parlzim.gov.zw/senators-members/senators', 'senate')
