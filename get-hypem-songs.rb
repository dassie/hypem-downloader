#!/usr/bin/ruby

require 'rubygems'
require 'mechanize'
require 'uri'
require 'net/http'

$all_songs = Array.new
$agent = Mechanize.new
$save_dir = ""
$err_stream = File.open('hypem_downloader_log', 'w')
Track = Struct.new(:title, :artist, :id, :key)

def download_song(url, dest)
  name = dest.gsub(/#{$save_dir}|\.mp3/, "") 
  begin
    puts "Downloading " + name + "..."
    song = $agent.get(url).content
  
    File.open(dest.to_s, 'wb+') do |ofstream|
      ofstream.print(song)
    end
  rescue
    log_error("Unable to download " + name + " try again later.\nLocated at: " + url, $err_stream, STDOUT)
  end
end

def log_error(msg, *ostream)
  time = %x[date].chomp
  
  ostream.each do |output|
    output.puts "[" + time + "] " + msg
  end
end

def parse_details(src, page = 1)
  r_track_hash = /trackList\[document\.location\.href\]\.push\(\{(.+?)\}\);/m
  r_track_details = /id:\s?'(.+?)'.*key:\s?'(.+?)'.*artist:\s?'(.+?)'.*song:\s?'(.+?)',/m
  
  track_hash = Array.new
  song_list = Array.new
  
  src.scan(r_track_hash).each do |match|
    track_hash.push match[0].to_s
  end
  
  track_hash.each do |hash_group|
    m = r_track_details.match(hash_group)
    song_list.push(Track.new(m[4].gsub(/\//, ""), m[3], m[1], m[2]))
  end
  
  i = 0
  puts "Page: " << page.to_s
  printf(STDOUT, "Song%48s", "Artist\n")
  puts "============================================================"
  song_list.each do |song|
    i += 1;
    printf(STDOUT, "[%02d] %s", i, song[:title])
    len = 40 - song[:title].length
    1.upto(len) { STDOUT.write(" ") }
    STDOUT.write(song[:artist] << "\n")
  end
  STDOUT.write("\n\n")
  
  return song_list
end

def display_user(user)
  unix_time = %x[date +%s]
  
  begin
    dpage = $agent.get("http://hypem.com/" << user << "?ax=1&ts=" << unix_time.chomp).content.to_s
  rescue Mechanize::ResponseCodeError => ex
    if ex.response_code.to_s == "404"
      log_error("User " + user + " not found", $err_stream, STDOUT)
      exit
    end
  #ensure 
  #  log_error("HTTP client returned with error code: " + ex.response_code.to_s + ". User " + user + " not found.", $err_stream, STDOUT)
  #  exit
  end
  
  $all_songs.push(parse_details(dpage))
  num_pages = dpage.scan(/\/\d\/">(\d)<\/a>/).count
  if num_pages != 0
    1.upto(num_pages) do |i|
      dpage = ""
      unix_time = %x[date +%s]
      dpage = $agent.get("http://hypem.com/" << user << "/" << (i+1).to_s << "?ax=1&ts=" << unix_time.chomp).content.to_s
      $all_songs.push(parse_details(dpage, i+1))
    end
  end
end


#visit the main page to get the AUTH cookie
$agent.get("http://hypem.com/")

args = ARGV.join(" ")
username = /^-u\s(.+?)\s-d\s(.+?)$/.match(args)[1]
$save_dir = /^-u\s(.+?)\s-d\s(.+?)$/.match(args)[2]

if File.directory?($save_dir.to_s) == false
  log_error("Directory " + $save_dir + " does not exist", $err_stream, STDOUT)
  exit
end

display_user(username)
 
STDOUT.write "To download songs you can indicate a page range with an input like:\n\n \
\"p1-p3\" which would download pages 1 to 3 \n\n \
or you can indicate song range on specific page:\n\n \
\"p2s3-s6\" which would download songs 3 to 6 on the 2nd page.\n\n \
p1 is implied if only 1 page exists or a page isn't indicated. Enter \"e\" to quit.\n\nWhat would you like to do:\n"
dl_options = STDIN.gets.chomp

exit if dl_options == "e"

r_page_range = /p(\d{1,2})-p(\d{1,2})/i
r_song_range = /p?(\d{1,2})?s(\d{1,2})-s(\d{1,2})/i

if dl_options.downcase.index("s") && dl_options.downcase.index("p")
  #a page and a song range has been given"
  m = dl_options.match(r_song_range)
  page = m[1].to_i
  s1 = m[2].to_i
  s2 = m[3].to_i

  (s1..s2).each do |index|
    url = "http://hypem.com/serve/play/" << $all_songs[page-1][index-1][:id] << "/" << $all_songs[page-1][index-1][:key] << ".mp3"
    file_name = ($all_songs[page-1][index-1][:title] << " - " << $all_songs[page-1][index-1][:artist] << ".mp3").gsub(/\n/, "")
    download_song(url, $save_dir + file_name)
  end
elsif dl_options.downcase.index("s") == nil && dl_options.downcase.index("p")
  #a page range is indicated"
  m = dl_options.match(r_page_range)
  p1 = m[1].to_i
  p2 = m[2].to_i
  
  (p1..p2).each do |index|
    $all_songs[index-1].each do |track|
      url = "http://hypem.com/serve/play/" << track[:id] << "/" << track[:key] << ".mp3"
      file_name = (track[:title] << " - " << track[:artist] << ".mp3").gsub(/\n/, "")
      download_song(url, $save_dir + file_name)
    end
  end
elsif dl_options.downcase.index("p") == nil && dl_options.downcase.index("s")
  #"a song range was indicated and it will be downloaded from page 1"
  m = dl_options.match(r_song_range)
  s1 = m[2].to_i
  s2 = m[3].to_i
  
  (s1..s2).each do |index|
    url = "http://hypem.com/serve/play/" << $all_songs[0][index-1][:id] << "/" << $all_songs[0][index-1][:key] << ".mp3"
    file_name = ($all_songs[0][index-1][:title] << " - " << $all_songs[0][index-1][:artist] << ".mp3").gsub(/\n/, "")
    download_song(url, $save_dir + file_name)
  end
else
  puts "Invalid option: " << dl_options
end                                               

$err_stream.close



