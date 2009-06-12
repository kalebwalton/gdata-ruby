require File.dirname(__FILE__) + '/spec_helper'
require File.dirname(__FILE__) + '/../lib/gdata'
require File.dirname(__FILE__) + '/../lib/gdata/client'
require File.dirname(__FILE__) + '/../lib/gdata/webmaster_tools'

context GData::WebmasterTools do
  describe 'sites' do
    before(:each) do
      xml = File.read(File.dirname(__FILE__) + '/fixtures/webmaster_tools/sites.xml')
      
      @wt = GData::WebmasterTools.new
      @wt.should_receive(:http_get).with('/webmasters/tools/feeds/sites/').and_return([nil, xml])
      @wt.should_receive(:authenticated?).and_return(true)
    end
    
    it 'should parse all fields from feed for all sites' do
      data = @wt.sites
      data.length.should eql(2)
      
      site1 = data[0]
      site2 = data[1]
      
      site1[:title].should eql('http://www.mysite.com/')
      site1[:id].should eql('http://www.google.com/webmasters/tools/feeds/sites/http%3A%2F%2Fwww.mysite.com%2F')
      site1[:verification_methods][:metatag].should eql('<meta name="verify-v1" content="nVryYYKT4lSCwaZ/avK1utx6/gtm78x9latRJPCdCuk=" >')
      site1[:verification_methods][:htmlpage].should eql('google937559d39027a39d.html')
      site1[:verified].should be_true
      
      site2[:title].should eql('http://www.myothersite.com/')
      site2[:id].should eql('http://www.google.com/webmasters/tools/feeds/sites/http%3A%2F%2Fwww.myothersite.com%2F')
      site2[:verified].should be_false
    end
  end
  
  describe 'site' do
    before(:each) do
      xml = File.read(File.dirname(__FILE__) + '/fixtures/webmaster_tools/site.xml')
      
      @wt = GData::WebmasterTools.new
      @wt.should_receive(:http_get).and_return([nil, xml])
      @wt.should_receive(:authenticated?).and_return(true)
    end
    
    it 'should parse all fields from feed for given site' do
      data = @wt.site('http://www.mysite.com')
      
      data[:title].should eql('http://www.mysite.com/')
      data[:id].should eql('http://www.google.com/webmasters/tools/feeds/sites/http%3A%2F%2Fwww.mysite.com%2F')
      data[:verification_methods][:metatag].should eql('<meta name="verify-v1" content="nVryYYKT4lSCwaZ/avK1utx6/gtm78x9latRJPCdCuk=" >')
      data[:verification_methods][:htmlpage].should eql('google937559d39027a39d.html')
      data[:verified].should be_false
    end
  end
  
  describe 'add_site' do
    before(:each) do
      xml = File.read(File.dirname(__FILE__) + '/fixtures/webmaster_tools/add_site.xml')
      
      @wt = GData::WebmasterTools.new
      @wt.should_receive(:http_post).and_return([Net::HTTPCreated.new(nil, nil, nil), xml])
      @wt.should_receive(:authenticated?).and_return(true)
    end
    
    it 'should return site data hash for freshly created site' do
      data = @wt.add_site('http://mynewsite.com')
      data[:title].should eql('http://www.mynewsite.com/')
      data[:verification_methods][:metatag].should eql('<meta name="verify-v1" content="nVryYYKT4lSCwaZ/avK1utx6/gtm78x9latRJPCdCuk=" >')
      data[:verification_methods][:htmlpage].should eql('google937559d39027a39d.html')
      data[:verified].should be_false
      data[:indexed].should be_false
    end
  end
  
  describe 'verify_site' do
    before(:each) do
      @xml = File.read(File.dirname(__FILE__) + '/fixtures/webmaster_tools/verify_site.xml')
      
      @wt = GData::WebmasterTools.new
    end
    
    it 'should return true if verification succeeds' do
      @wt.should_receive(:http_put).and_return([Net::HTTPOK.new(nil, nil, nil), @xml])
      @wt.should_receive(:authenticated?).and_return(true)
      @wt.verify_site('http://www.mysite.com/', 'metatag').should be_true
    end
    
    it 'should raise an error if invalid method is supplied' do
      lambda {
        @wt.verify_site('http://www.mysite.com/', 'meta-tag')
      }.should raise_error(GData::WebmasterToolsError)
    end
    
    it 'should raise site not found error if account does not have this site' do
      @wt.should_receive(:http_put).and_return([Net::HTTPNotFound.new(nil, nil, nil), ''])
      @wt.should_receive(:authenticated?).and_return(true)
      lambda {
        @wt.verify_site('http://www.unknownsite.com', 'metatag')
      }.should raise_error(GData::WebmasterToolsError)
    end
  end
  
  describe 'delete_site' do
    it 'should raise WebmasterToolsError when site is not found or is missing'
  end
end
