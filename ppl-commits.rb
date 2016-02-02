#!/usr/bin/env ruby

require 'git'
require 'date'
require 'logger'

log = Logger.new(STDERR)
log = nil

EMPTY = '__EMPTY__'

class Day
  attr_reader :date
  def initialize(datetime)
    @date = datetime.to_date
    @commiters = {}
  end
  def register_commit(commit)
    date = commit.author.date
    raise "Invalid commmit: #{commit}" if other_day?(date)
    author = commit.author.email
    if @commiters[author].nil?
      @commiters[author] = {
        :author => author,
        :stats => { :insertions => 0, :deletions => 0, :modifications => 0, :drift => 0 },
      }
    end
    unless commit.parent.nil?
      diff = commit.diff_parent
    else
      diff = commit.diff(EMPTY)
    end
    stats = diff.stats
    total = stats[:total]
    # since diffing from behind deletions and insertions are reversed
    @commiters[author][:stats][:insertions] += total[:deletions]
    @commiters[author][:stats][:deletions]  += total[:insertions]
    @commiters[author][:stats][:modifications] += total[:lines]
    @commiters[author][:stats][:drift] += (total[:deletions] - total[:insertions])
  end
  def commiters
    @commiters.values
  end
  def other_day?(date)
    @date != date.to_date
  end
end
def logDay(git, day)
  day.commiters.each do |commiter|
    a = commiter[:author]
    s = commiter[:stats]
    puts "#{day.date};#{a};#{s[:insertions]};#{s[:deletions]};#{s[:modifications]};#{s[:drift]}"
  end
end
begin
  day = nil
  current = `git rev-parse --abbrev-ref HEAD`.strip
  `git checkout --orphan #{EMPTY} -q`
  `git read-tree --empty`
  `git clean -fdx -q`
  `git commit --allow-empty -m 'Empty' -q`
  `git checkout -q #{current}`
  git = Git.open(Dir.pwd, :log => log)
  puts 'Date;Author;Insertions;Deletions;Modifications;Drift'
  git.log(100000).each do |commit|
    date = commit.author.date
    if day.nil? or day.other_day?(date)
      logDay(git, day) unless day.nil?
      day = Day.new(date)
    end
    day.register_commit(commit)
  end
  logDay(git, day) unless day.nil?
ensure
  `git branch -D #{EMPTY} -q`
end
