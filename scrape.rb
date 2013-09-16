#!/usr/bin/env ruby

require 'mechanize'
require 'vcr'

# https://github.com/blog/category/hire

VCR.configure do |c|
  c.cassette_library_dir = 'cached'
  c.hook_into :webmock
  # c.ignore_hosts 'maps.googleapis.com'
end

class IsaGitHubber

  attr_accessor :mechanize
  attr_accessor :author, :title, :creation_date, :body, :location, :lat, :lng, :ignores, :username
  
  def process_title( title )
    @title = title
    if @title
      @title.gsub!( /Title:/, "" )
      @title.strip!
    end
  end

  def initialize
    @mechanize = Mechanize.new { |agent|
      agent.user_agent_alias = 'Mac Safari'
    }
    # @ignores = YAML.load_file( "./scraper_ignore.yml" )
  end

  def run
    root = 'https://github.com/blog/category/hire'
    VCR.use_cassette("isgh") do
      @mechanize.get( root ) do |page|
        begin
          follows = ( page / ".blog-post .blog-post-body p:nth-last-child(1)" )
          if follows
            follows.each do |f|
              puts f
            end
          end
        end
      end
    end
  end
  
end

isagh = IsaGitHubber.new()
isagh.run()

