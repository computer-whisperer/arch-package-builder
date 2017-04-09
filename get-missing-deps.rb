#!/usr/bin/ruby
# frozen_string_literal: true

##
# Written by bastelfreak
##
# enable your local multilib repo
##

require 'json'
require 'net/http'

@path = 'aur-packages'
@aur_packages = []
@aur_url = 'https://aur.archlinux.org/rpc/?v=5&type=info&arg[]='
@http = ''
@matches = []
# read files
def get_all_packages(path)
  @aur_packages = []
  f = IO.readlines path
  f.each do |line|
    line.delete!("\n")
    @aur_packages << line
  end
end

def aur_api_connect
  uri = URI.parse(@aur_url)
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  @http = http
end

def get_deps_for_package(package)
  uri = URI.parse("#{@aur_url}#{package}")
  res = @http.request(Net::HTTP::Get.new(uri.request_uri))
  ary = JSON.load(res.body)['results']
  # ary[0].key?("Depends") ? ary[0]["Depends"] : ''
  !ary.empty? ? ary[0]['Depends'] : ''
end

def no_official_package?(package)
  !system("pacman -Ssq #{package}", :out => File::NULL)
end

def add_deps(deps)
  #  unless deps.nil?
  deps.each do |dep|
    add_dep dep
  end
  #  end
end

def add_dep(dep)
  dep = dep.slice(%r{^[a-zA-Z0-9@.+_-]+})
  puts "\t processing dep #{dep}"
  if no_official_package?(dep) && (!@aur_packages.include? dep)
    puts "found dep #{dep}"
    # @aur_packages << dep
    @matches << dep
  end
end

def all_deps_for_every_package
  counter = 0
  @aur_packages.each do |package|
    counter += 1
    puts "processing package #{package} (#{counter}/#{@aur_packages.count})"
    deps = get_deps_for_package package
    add_deps deps if deps.is_a? Array
  end
end

def cycle_until_all_deps_are_found
  all_deps_for_every_package
  unless @matches.empty?
    puts 'we found one or more deps, adding them to the file and rescan'
    @matches = @matches.uniq
    @aur_packages = @matches
    File.open(@path, 'a') do |f|
      f.puts(@matches)
    end
    @matches = []
    cycle_until_all_deps_are_found
  end
end

# let the magic happen
aur_api_connect
get_all_packages @path
cycle_until_all_deps_are_found
