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
require 'date'
require 'action_view'
require 'active_support/all'
include ActionView::Helpers::DateHelper

heading = "\n| repo | description | license | ⭐️ | updated |\n"
heading += "| :--- | :--- | :---: | :---: | ---: |\n"

tempfile=File.open("README.tmp", 'w')
tempfile << <<-PREAMBLE
<p align="center">
  <br>
    <img src="images/juce awesome.png" width="200"/>
  <br>
</p>

# Awesome JUCE

An [awesome list](https://github.com/topics/awesome-list) of open source [JUCE](http://github.com/juce-framework/JUCE/) libraries, plugins and utilities. Organized by category. Stats update nightly. 

🟢 = updated recently  
🟠 = no commit in last year  
🔴 = no commit in the last 3 years  

Something missing? [Open a PR to sites.md with the url and a short description](https://github.com/sudara/awesome-juce/edit/main/sites.md).

I make more juce-y content over at https://melatonin.dev/blog
PREAMBLE

client = Octokit::Client.new(access_token: ENV["GITHUB_ACCESS_TOKEN"])

File.open('sites.md') do |file|
  total = 0
  while !(h2 = file.gets).nil? && h2.start_with?('##') do
    rows = []
    tempfile << "\n" << h2
    # keep the h2 header
    tempfile << heading 
    print "Processing #{h2.strip}..."
    file.gets
    while (entry = file.gets) && entry.slice!('https://')
      total += 1
      if entry.slice!('github.com/')
        # split into sudara/pamplejuce and description
        name_and_repo, description = entry.split(' ', 2) 
        begin 
          repo = client.repo(name_and_repo)
          license = repo.license.nil? ? "" : repo.license[:name].gsub('NOASSERTION',"other")
          last_committed_at = client.commits(name_and_repo).first[:commit][:committer][:date]
          status = case
            when last_committed_at > 1.year.ago 
              "<sub><sup>󠀠󠀠🟢</sup></sub>"
            when last_committed_at > 3.years.ago
              "<sub><sup>🟠</sup></sub>"
            else
              "<sub><sup>🔴</sup></sub>"
            end
          date = "#{time_ago_in_words(last_committed_at).gsub(/about|almost|over/, "").gsub(" "," ")}"
          table_row = "|[#{repo.name}](#{repo.html_url}) <br/> <sup>by [#{repo.owner[:login]}](#{repo.owner.html_url})</sup> | #{description.strip}| #{license}|#{repo.stargazers_count}|#{date}#{status}|\n"
          rows << [repo.stargazers_count, table_row]
        rescue Octokit::NotFound
          puts "NOT FOUND OR MOVED?: #{name_and_repo}" 
        end
      else
        url, description = entry.split(' ', 2)
        name = url.split('/').last
        table_row = "|[#{name}](https://#{url})| #{description}| | | |\n"
        rows << [0, table_row]
      end
    end
    puts "#{rows.size} entries"
    # ruby is fucking awesome, this sorts by stars
    tempfile << rows.sort_by{|row| row.first }.reverse.collect(&:last).join
  end
  tempfile << "\n\n#{total} entries as of #{Date.today}"
end

FileUtils.mv "README.tmp", "README.md"