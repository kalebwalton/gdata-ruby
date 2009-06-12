$:.unshift(File.dirname(__FILE__) + '/../lib')
require 'rubygems'
require 'time'
require File.dirname(__FILE__) + '/../lib/gdata'
require File.dirname(__FILE__) + '/../lib/gdata/client'
require File.dirname(__FILE__) + '/../lib/gdata/blogger'


# This is just crap test code - don't try running it...
b = GData::Blogger.new
b.authenticate(ARGV[0], ARGV[1])
blogs = b.blogs
puts blogs[0][:categories].length
b1 = b.posts({
  :blog_id => blogs[0][:id],
  :published_after => Time.parse("6/11/2009"),
  :published_before => Time.parse("6/13/2009"),
  :categories => ['yes', 'foobar']
})
b2 = b.posts({
  :blog_id => blogs[1][:id]
})

b2.each do |post|
  puts post[:title]
  comments = b.comments({:blog_id => blogs[1][:id], :post_id => post[:id]})
  unless comments.empty?
    comments.each do |comment|
      puts comment[:title]
      puts comment[:author][:name]
      puts comment[:author][:uri]
    end
  end
end