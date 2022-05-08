#!/usr/bin/env ruby


# This script takes lines like this as input:
#   ## Templates
#   https://github.com/sudara/pamplejuce  JUCE, CMAKE, Catch2 on GitHub Actions

# and outputs a Github Flavored Markdown table, like so:
#
#   ## Templates
#   | name | author | description | stars | created | last updated |
#   | --- | --- | --- | --- |--- |
#   | [pamplejuce](https://github.com/sudara/pamplejuce) | JUCE, CMAKE, Catch2 on GitHub Actions | ⭐️ | March 2, 2022|

require 'fileutils'
require 'octokit'

heading = "\n| name | author | description | ⭐️ | last updated |\n"
heading += "| --- | --- | --- | --- | --- |\n"

tempfile=File.open("README.tmp", 'w')
client = Octokit::Client.new(access_token: ENV["GITHUB_ACCESS_TOKEN"])

File.open('sites.md') do |file|
  while !(h2 = file.gets).nil? && h2.start_with?('##') do
    rows = []
    tempfile << h2
    # keep the h2 header
    tempfile << heading 
    print "Processing #{h2.strip}..."
    file.gets
    while !(entry = file.gets).nil? && entry.slice!('https://github.com/') do
      
      # split into sudara/pamplejuce and description
      name_and_repo, description = entry.split(' ', 2) 
      begin 
        repo = client.repo(name_and_repo) 
        last_committed_at = client.commits(name_and_repo).first[:commit][:committer][:date].strftime('%b %d %Y')
        table_row = "|[#{repo.name}](#{repo.html_url})|[#{repo.owner[:login]}](#{repo.owner.html_url})| #{description.strip}|#{repo.stargazers_count}|#{last_committed_at}|\n"
        rows << [repo.stargazers_count, table_row]
      rescue Octokit::NotFound
        puts "NOT FOUND OR MOVED?: #{name_and_repo}" 
      end
    end
    puts "#{rows.size} entries"
    # ruby is fucking awesome, this sorts by stars
    tempfile << rows.sort_by{|row| row.first }.reverse.collect(&:last).join
  end
end

FileUtils.mv "README.tmp", "README.md"