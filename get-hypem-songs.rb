#!/usr/bin/ruby

require 'rubygems'
require 'mechanize'
require 'uri'
require 'net/http'

class Hypem
	Track = Struct.new(:title, :artist, :id, :key, :ts, :page, :song_number, :url_internal)
	
	R_TRACK_HASH = /<script type="text\/javascript">\s*trackList\[document\.location\.href\](.+?)<\/script>/m
	R_TRACK_DETAILS = /\sid:\s?'(.+?)',.*ts:\s?'(\d+?)',.*key:\s?'(.+?)',.*artist:\s?'(.+?)',\s*song:\s*'(.+?)',/m
	
	def initialize
		@agent = Mechanize.new
		@song_list = Array.new
		@dpage = String.new
		@agent.get "http://hypem.com/"
	end
	
	def unix_time
		%x[date +%s].chomp
	end
	
	def display_user(username)
		page = 1
		
		while true do
			begin
				@dpage = @agent.get("http://hypem.com/#{username}/#{page}?ax=1&ts=#{unix_time}").content.to_s
			rescue Mechanize::ResponseCodeError => ex
				break if ex.response_code.to_s == "404"
			end
			
			s = 1
			@dpage.scan(R_TRACK_HASH).each do |m0|
				t_hash = m0[0].to_s
				t_hash.scan(R_TRACK_DETAILS) do |m1|
					t = Track.new
					t[:title] = m1[4].gsub('\\', '')
					t[:artist] = m1[3]
					t[:id] = m1[0]
					t[:key] = m1[2]
					t[:ts] = m1[1]
					t[:url_internal] = "http://hypem.com/serve/source/#{t.id}/#{t.key}?_=#{t.ts}"
					t[:page] = page
					t[:song_number] = s
					@song_list.push t
				end
				s = s + 1
			end
			page = page + 1
		end
		
		puts "#"*60 + "\n" + "| P |" + " "*11 + "Artist" + " "*11 + "|" + " "*11 + "Song" + " "*10 + "|\n" + "#"*60
		@song_list.each do |t|
			puts " #{t.page}     #{t.artist}" + " "*(28 - (t.artist.length)).abs + t.title
		end
	end
	
	def get_songs(pi, pf, si, sf)
		@song_list.each do |t|
			if t.page >= pi and t.page <= pf and t.song_number >= si and t.song_number <= sf then
				download_song(t.url_internal, t.title + "_" + t.artist)
			end
		end
	end
	
	def download_song(url, file_name)
		begin
			@dpage = @agent.get(url).content.to_s
		rescue Mechanize::ResponseCodeError => ex
			puts "Unable to retrieve location of song \"#{file_name}\" from #{url}\n\n"
			return
		end
		
		json = @dpage.gsub('\\', '')
		source = json.match(/"url":"(.+?)"/)[1]
		begin
			puts "Downloading \"#{file_name}\" from #{source}"
			
			source = source.gsub("/ /", "%20")
			begin
				song = @agent.get(source).content
			rescue Mechanize::ResponseCodeError => ex
				if ex.response_code.to_s == "404" then
					puts "404: Unable to download " + file_name + " located at: " + source + "\n\n"
				end
			end
		
			File.open(Dir.pwd + "/" + file_name, 'wb+') do |ofstream|
				ofstream.print(song)
			end
			
			puts "Done\n\n"
		rescue
			puts "Unable to download " + file_name + " located at: " + source + "\n\n"
		end
	end
	
	def debug
		fout = File.open("debug-#{%x[date +%s]}.txt", 'w')
		@dpage.each_line do |line|
			fout.print line
		end
		fout.close
	end
end

if not ARGV[0] then
	puts "Need username as first argument"
	exit
end

agent = Hypem.new
agent.display_user(ARGV[0])

options = STDIN.gets.chomp.match(/p(\d+)-p(\d+)s(\d+)-s(\d+)/)
while not options do
	puts "Invalid input\nTry again:"
	options = STDIN.gets.chomp.match(/p(\d+)-p(\d+)s(\d+)-s(\d+)/)
end
agent.get_songs(options[1].to_i, options[2].to_i, options[3].to_i, options[4].to_i)












































