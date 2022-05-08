#!/usr/bin/env ruby


# This script takes lines like this as input:
#   ## Templates
#   https://github.com/sudara/pamplejuce  JUCE, CMAKE, Catch2 on GitHub Actions

# and outputs a Github Flavored Markdown table, like so:
#
#   ## Templates
#   | name & author | description | stars | created | last updated |
#   | --- | --- | --- |--- |
#   | [pamplejuce](https://github.com/sudara/pamplejuce) | JUCE, CMAKE, Catch2 on GitHub Actions | ⭐️ | March 2, 2022|

require 'fileutils'
require 'octokit'

heading = "\n| repo | description | license | ⭐️ | updated |\n"
heading += "| :--- | :--- | :---: | :---: | ---: |\n"

tempfile=File.open("README.tmp", 'w')
tempfile << <<-PREAMBLE
<p align="center">
  <br>
    <img src="images/juce awesome.png" width="200"/>
  <br>
</p>

# JUCE "Awesome List"

An [awesome list](https://github.com/topics/awesome-list) of open source JUCE repositories, organized by category. Stats update nightly. 

To add your repo: [add the url and short description to sites.md](https://github.com/sudara/awesome-juce/edit/main/sites.md).

For more juce-y content: https://melatonin.dev/blog

PREAMBLE

client = Octokit::Client.new(access_token: ENV["GITHUB_ACCESS_TOKEN"])

File.open('sites.md') do |file|
  while !(h2 = file.gets).nil? && h2.start_with?('##') do
    rows = []
    tempfile << h2
    # keep the h2 header
    tempfile << heading 
    print "Processing #{h2.strip}..."
    file.gets
    while (entry = file.gets) && entry.slice!('https://')
      if entry.slice!('github.com/')
        # split into sudara/pamplejuce and description
        name_and_repo, description = entry.split(' ', 2) 
        begin 
          repo = client.repo(name_and_repo)
          license = repo.license.nil? ? "" : repo.license[:spdx_id].gsub('NOASSERTION',"custom")
          last_committed_at = client.commits(name_and_repo).first[:commit][:committer][:date].strftime('%b %d %Y')
          table_row = "|[#{repo.name}](#{repo.html_url}) <br/> <sup>by [#{repo.owner[:login]}](#{repo.owner.html_url})</sup> | #{description.strip}| #{license}|#{repo.stargazers_count}|#{last_committed_at}|\n"
          rows << [repo.stargazers_count, table_row]
        rescue Octokit::NotFound
          puts "NOT FOUND OR MOVED?: #{name_and_repo}" 
        end
      else
        url, description = entry.split(' ', 2)
        name = url.split('/').last
        table_row = "|[#{name}](#{url})| #{description}| | | |\n"
        rows << [0, table_row]
      end
    end
    puts "#{rows.size} entries"
    # ruby is fucking awesome, this sorts by stars
    tempfile << rows.sort_by{|row| row.first }.reverse.collect(&:last).join
  end
end

FileUtils.mv "README.tmp", "README.md"