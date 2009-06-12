# Extension class into Ruby GData library for use Google Webmaster Tools.
#
# == Overview
#
# This class enables to perform all actions on Google Webmaster Tools account: getting information about sites
# associated with an authenticated account and submitting new sites to this account.
#
# See more at http://code.google.com/apis/webmastertools/
#

require 'cgi'
require 'date'
require 'rexml/document'

module GData #:nodoc:
  
  class WebmasterToolsError < StandardError; end #:nodoc:
  
  class WebmasterTools < GData::Client
    
    FEED_URL = '/webmasters/tools/feeds/sites/'
    
    def initialize
      super('sitemaps', 'gdata-ruby', 'www.google.com')
    end
    
    # Get feed for all sites associated with authenticated user and parse all data into hash.
    #
    # == Example
    #
    #   wt = GData::WebmasterTools.new
    #   wt.authenticate('username@gmail.com', 'password')
    #   wt.sites
    #   => [{:id => ..., :title => ..., ...}, {:id => ..., :title => ..., ...}]
    #
    # Each element in returned array contains hash with site data. See more at parse_site_entry.
    def sites
      if authenticated?
        response, data = http_get(FEED_URL)

        site_data = Array.new
        REXML::Document.new(data).root.elements.each('entry') do |e|
          site_data << parse_site_entry(e)
        end
        site_data
      else
        raise NotAuthenticatedError
      end
    end
    
    # Get feed for selected site under account.
    #
    # == Example
    #
    #   wt = GData::WebmasterTools.new
    #   wt.authenticate('username@gmail.com', 'password')
    #   wt.site('http://www.mysite.com')
    #   => {:id => ..., :title => ..., ...}
    #
    # Returned hash contains site data parsed with parse_site_entry method.
    def site(site_id)
      if authenticated?
        response, data = http_get site_feed(site_id)
        entry = REXML::Document.new(data).root.elements['entry']
        parse_site_entry(entry)
      else
        raise NotAuthenticatedError
      end
    end
    
    # Add new site to account. Returns hash for created site.
    #
    # == Example
    #
    #   wt = GData::WebmasterTools.new
    #   wt.authenticate('username@gmail.com', 'password')
    #   wt.add_site('http://www.mynewsite.com')
    #   => {:id => ..., :title => ..., ...}
    #
    # Returned hash contains site data parsed with parse_site_entry method.
    def add_site(url)
      if authenticated?
        content = '<entry xmlns="http://www.w3.org/2005/Atom"><content src="' + url +'" /></entry>'
        response, data = http_post(FEED_URL, content)
        
        case response
        when Net::HTTPCreated
          entry = REXML::Document.new(data).root
          return parse_site_entry(entry)
        when Net::HTTPForbidden
          raise WebmasterToolsError.new(data)
        else
          raise WebmasterToolsError
        end
      else
        raise NotAuthenticatedError
      end
    end
    
    # Remove site from account.
    def delete_site(site_id)
      if authenticated?
        response, data = http_delete site_feed(site_id)
        
        case response
        when Net::HTTPOK
          return true
        else
          raise WebmasterToolsError.new(data)
        end
      else
        raise NotAuthenticatedError
      end
    end
    
    # Initiates site ownership verification process in Webmaster Tools account.
    #
    # == Usage
    #
    # Method can be only 'htmlpage' or 'metatag', otherwise this method will raise WebmasterToolsError.
    def verify_site(site_id, method)
      raise WebmasterToolsError unless ['htmlpage', 'metatag'].include?(method)
      
      if authenticated?
        content = '<entry xmlns="http://www.w3.org/2005/Atom" xmlns:wt="http://schemas.google.com/webmasters/tools/2007">'
        content << '<id>' + site_id + '</id><category scheme="http://schemas.google.com/g/2005#kind" term="http://schemas.google.com/webmasters/tools/2007#site-info"/>'
        content << '<wt:verification-method type="' + method + '" in-use="true"/>'
        content << '</entry>'
        response, data = http_put(site_feed(site_id), content)
        
        case response
        when Net::HTTPOK
          entry = REXML::Document.new(data).root
          data = parse_site_entry(entry)
          
          if data[:verified] and data[:title] == site_id
            return true
          else
            return false
          end
        when Net::HTTPNotFound
          raise WebmasterToolsError.new(data)
        else
          raise WebmasterToolsError
        end
      else
        raise NotAuthenticatedError
      end
    end
    
    private
    
      # Private helper method to compose site feed based on site id.
      def site_feed(site_id)
        FEED_URL + CGI::escape(site_id || '')
      end
      
      # Parses site entry into hash from feed partial.
      #
      # == Site data hash format
      #
      #   {
      #     :id => 'http://www.google.com/webmasters/tools/feeds/sites/http%3A%2F%2Fwww.mysite.com%2F',
      #     :title => 'http://www.mysite.com', :updated => DateTime..., :indexed => true, :verified => true,
      #     :crawled => DateTime...,
      #     :verification_methods => {:metatag => '<meta ...>', :htmlpage => 'google....html'}
      #   }
      #
      def parse_site_entry(elem)
        vm = Hash.new
        elem.elements.each('wt:verification-method') do |m|
          vm[m.attributes['type'].to_sym] = CGI::unescapeHTML(m.get_text.to_s.gsub("\\", ""))
        end
        
        crawled = DateTime.parse(elem.elements['wt:crawled'].get_text.to_s) unless elem.elements['wt:crawled'].nil?
        
        {
          :id => elem.elements['id'].get_text.to_s,
          :title => elem.elements['title'].get_text.to_s,
          :updated => DateTime.parse(elem.elements['updated'].get_text.to_s),
          :indexed => elem.elements['wt:indexed'].get_text.to_s == 'true',
          :crawled => crawled,
          :verified => elem.elements['wt:verified'].get_text.to_s == 'true',
          :verification_methods => vm
        }
      end
  end
end
