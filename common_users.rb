#!/usr/bin/env ruby

require "octokit"
require "set"


AUTH_TOKEN = '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'

PER_PAGE = 100 # maximize the page

TRIES = 3 # retry to counter network/rate issues


@options  = {}
usernames = []
@client = Octokit::Client.new(:access_token => AUTH_TOKEN)


# easy way is to switch on autopaging and retireve followers in one shot
# but I will try to optimize a little

#check that users exist
def user_check(usernames)
  usernames.each do |name|
    begin
      @client.user name
        # normally I'm fine with program to spit the exception in the face,
        # yet exception handling was requested
    rescue Octokit::NotFound => e
      STDERR.puts "ERROR, USER #{name} DOES NOT EXIST \n\n Details #{e.message}"
      exit 1
    rescue Octokit::Unauthorized => e
      STDERR.puts "ERROR, UPDATE THE CREDENTIALS \n\n Details #{e.message}"
      exit 1
    rescue => e
      STDERR.puts "TERMINAL ERROR \n\n Details #{e.message}"
      exit 1
    end
  end
end

#pulls one page of followers
def get_page(user, page, tries)
  begin
    @client.followers(user, page: page, per_page: PER_PAGE).map(&:login)
  rescue => e
    if tries > 1
      STDERR.puts "ERROR, WILL TRY AGAIN AFTER A DELAY \n\n #{e.message}"
      sleep(1)
      get_page(user, page, tries - 1)
    else
      STDERR.puts "ERROR, TERMINATING \n\n #{e.message}"
      exit 1
    end
  end
end

#finds all followers
def get_followers(user)
  page   = 1
  result = [].to_set
  until (d = get_page(user, page, TRIES)).empty? do
    if @options[:progress]
      puts "step #{page} retrieved next #{PER_PAGE} follower of user #{user}"
      puts d[-1]
    end
    page += 1
    result.merge(d.to_set)
  end
  result
end

# finds common followers
def common_followers(user1, user2)
  if @options[:multithreaded]
    t           = Thread.new { @followers2 = get_followers(user2) }
    @followers1 = get_followers(user1)
    t.join()
    @followers1.intersection @followers2
  else
    get_followers(user1).intersection get_followers(user2)
  end
end

if __FILE__ == $0

  # CLI parsing
  ARGV.each do |option|
    case option
    when "-h"
      puts "The command line utility finds common followers for two github users."
      puts "Syntax is"
      puts "  common_followers.rb username1 username2 [-p] [-m]"
      puts "-p : show the progress"
      puts "-m : multithreaded mode"
      exit
    when "-p"
      @options[:progress] = true
    when "-m"
      @options[:multithreaded] = true
    else
      usernames.push(option)
    end
  end
  if usernames.length != 2
    puts "Error. The command line utility finds common followers for two github users."
    puts "Syntax is"
    puts "  common_followers.rb username1 username2 [-p] [-m]"
    exit 1
  end
  user_check(usernames)
  result = common_followers(usernames[0], usernames[1])
  puts 'COMMON FOLLOWERS'
  puts result.to_a.join("\n")

end


# well followed users
# user1 = 'egoist'
# user2 = 'andrew'
