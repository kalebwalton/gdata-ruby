require 'gdata/client'
require 'builder'
require 'rexml/document'
require 'cgi'
require 'time'

module GData

  class Blogger < GData::Client
    attr_reader :blog_id
    # Default initialization method.  The blog ID and the entry ID may 
    # or may not be known ahead of time.  Be sure to authenticate if needed.
    def initialize
      super 'blogger', 'gdata-ruby', 'www.blogger.com'
    end
    
    # Pull down a list of the user's blogs.  This allows the use of muliple
    # blogs per user.  The @blogs Array will store the available blogs by
    # internal hash. Requires user to be authenticated.
    # ex. @blogs[0] = {"Blog Name" => "blog_id(a string of numbers)"}
    # returns @blogs - an outer program can use this to set the blog id using
    # the set_blog_id method.
    def blogs
      # retrieve the user's list of blogs from the server.
      if authenticated?
        blog_feed = http_get('/feeds/default/blogs/')
        blogs = Array.new
        REXML::Document.new(blog_feed[1]).root.elements.each('entry') do |entry|
          blogs << parse_blog(entry)
        end
        blogs
      else puts "Not authenticated."
      end
    end

    def parse_blog(entry)
      blog = {}
      blog[:id] = entry.elements['id'].get_text.to_s.split(/blog-/).last
      blog[:title] = entry.elements['title'].get_text.to_s
      blog[:categories] = []
      entry.elements.each('category') do |category|
        blog[:categories] << category.attribute('term')
      end
      blog
    end

    # Sets the active blog so calls to the 'posts' and 'post' method
    # don't need the 'blog_id' parameter set.
    def set_blog(options)
      @blog_id = options
      @blog_id = options[:id] if options.is_a? Hash
    end

    # Retrieves the post feed from the blog contained in @blog_id.  Run through
    # REXML, it returns an array of the different id's of that blog's posts.
    # Accepts the following options
    #   :blog_id - String
    #   :published_after - Time
    #   :published_before - Time
    #   :categories - Array of Strings
    #   :max_results - Integer
    #   :start_index - Integer
    def posts(options = {})
      blog_id = options[:blog_id] || @blog_id
      
      categories = options[:categories]
      params = parse_posts_params(options)
      
      url = "/feeds/#{blog_id}/posts/default"
      url += "/-/#{categories.join('/')}" unless categories.nil? 
      url += "?#{params.join("&")}" unless params.empty?

      post_feed = http_get(url)
      
      posts = []
      REXML::Document.new(post_feed[1]).elements.each('feed/entry') do |entry|
        posts << parse_post(entry)
      end
      posts
    end

    def parse_posts_params(options)
      params = []
      params << "published-min=#{options[:published_after].xmlschema}" unless options[:published_after].nil?
      params << "published-max=#{options[:published_before].xmlschema}" unless options[:published_before].nil?
      params << "max-results=#{options[:max_results]}" unless options[:max_results].nil?
      params << "start-index=#{options[:start_index]}" unless options[:start_index].nil?
      params
    end

    def parse_post(entry)
      post = {}
      post[:id] = entry.elements['id'].get_text.to_s.split(/post-/).last
      post[:title] = entry.elements['title'].get_text.to_s
      post[:content] = CGI.unescapeHTML(entry.elements['content'].get_text.to_s)
      post
    end
    
    def post(options)
      blog_id = options[:blog_id] || @blog_id
      post_id = options[:id]

      raise "An id must be presented in the options for post_entry" if post_id.nil?
      raise "A blog_id must be presented in the options for post_entry or set_blog must be called" if blog_id.nil?
      
      post_entry = {}
      REXML::Document.new(http_get("/feeds/#{blog_id}/posts/default/#{post_id}")[1]).elements.each('entry') do |entry|
        post_entry = parse_post(entry)
      end
      post_entry
    end

    def comments(options)
      blog_id = options[:blog_id] || @blog_id
      post_id = options[:post_id]
      
      categories = options[:categories]
      params = parse_posts_params(options)
      
      comments_feed = http_get("/feeds/#{blog_id}/#{post_id}/comments/default")
      
      comments = []
      REXML::Document.new(comments_feed[1]).elements.each('feed/entry') do |entry|
        comments << parse_comment(entry)
      end
      comments
    end

    def parse_comment(entry)
      comment = {}
      comment[:title] = Time.parse(entry.elements['title'].get_text.to_s)
      comment[:published_on] = Time.parse(entry.elements['published'].get_text.to_s)
      comment[:updated_on] = Time.parse(entry.elements['updated'].get_text.to_s)
      comment[:content] = CGI.unescapeHTML(entry.elements['content'].get_text.to_s)
      comment[:author] = {}
      comment[:author][:name] = entry.elements['author'].elements['name'].get_text.to_s
      comment[:author][:uri] = entry.elements['author'].elements['uri'].get_text.to_s  
      comment[:author][:email] = entry.elements['author'].elements['email'].get_text.to_s
      comment
    end

    def enclosure
      entry.search('//link[@rel="enclosure"]')
    end

    def enclosure?
      enclosure.any?
    end
  
    def add_enclosure(enclosure_url, enclosure_length)
      raise "An enclosure has already been added to this entry" if enclosure?
      # todo(stevejenson): replace with builder
      entry.search('//entry').append(%Q{<link rel="enclosure" type="audio/mpeg" title="MP3" href="#{enclosure_url}" length="#{enclosure_length}" />})
      save_entry
    end

    def remove_enclosure
      if enclosure?
        enclosure.remove
        save_entry
      end
    end

    def save_entry
      path = "/feeds/#{@blog_id}/posts/default/#{@entry_id}"
  
      http_put(path, entry.to_s)
    end

    # Creates a new entry with the given title and body
    def create_entry(title, body)
      x = Builder::XmlMarkup.new :indent => 2
      x.entry 'xmlns' => 'http://www.w3.org/2005/Atom' do
        x.title title, 'type' => 'text'
        x.content 'type' => 'xhtml' do
          x.div body, 'xmlns' => 'http://www.w3.org/1999/xhtml'
        end
      end
      
      @entry ||= x.target!
      path = "/feeds/#{@blog_id}/posts/default"
      post(path, @entry)
    end

  end

end
