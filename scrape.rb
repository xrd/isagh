#!/usr/bin/env ruby

require 'mechanize'
require 'vcr'
require 'geocoder'

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

  def get_home_lat_lng( home )
    if home =~ /\w/
      home.gsub!( /\W+/, ' ' )
      home.downcase!
      puts "Converted: #{home}"
      VCR.use_cassette( home ) do 
        results = Geocoder.search( home )[0]
        if results and results.data
          location = results.data['geometry']['location']
          @lat = location['lat']
          @lng = location['lng']
          puts "Home #{home} -> #{@lat}/#{@lng}"
        end
      end
    end
  end
  
  def run
    root = 'https://github.com/blog/category/hire'
    begin
      # Seems like we maxed out after 13 pages...
      15.times do |i|
        VCR.use_cassette("isgh_#{i}") do
          puts "i: #{i}"
          url = ( i == 0 ? root : "#{root}?page=#{i+2}" )
          @mechanize.get( url ) do |page|
            begin
              follows = ( page / ".blog-post .blog-post-body p:nth-last-child(1)" )
              if follows
                follows.each do |f|
                  # puts f
                  links = f / "a[href*=github]"
                  if links
                    links.each do |l|
                      ghpl = l['href'] unless l['href'] =~ /assets/
                      username = $1 if ghpl =~ /github\.com\/(.*)$/
                      if username
                        if username =~ /web\//
                          puts "WTF: #{username}"
                        else
                          VCR.use_cassette("ghp_#{username}") do
                            user = @mechanize.get( ghpl ) do |ghpm|
                              home = ghpm / "dd[itemprop=homeLocation]"
                              puts "Username: #{username} lives in #{home.text()}"
                              get_home_lat_lng( home.text() )
                              VCR.use_cassette("ghp_#{username}_repositories") do
                                @mechanize.get( "http://github.com/#{username}?tab=repositories" ) do |repos|
                                  begin
                                    repo1 = repos / ".repolist .source:nth-child(1)"
                                    if repo1 and repo1.length > 0
                                      puts "First repo is #{( repo1 / '.repolist-name a:nth-child(1)' ).text()}"
                                    else
                                      puts "No repos for #{username}"
                                    end
                                  rescue Exception => e
                                    puts "Hmm, some error #{e.inspect}"
                                  end
                                end
                              end
                            end
                          end
                        end
                      else
                        puts "No username found #{ghpl}"
                      end
                    end
                  end
                end
              end
            end
          end
        end
      end
    rescue Exception => e
      puts "Got an exception: #{e}"
    end
  end
end

isagh = IsaGitHubber.new()
isagh.run()


