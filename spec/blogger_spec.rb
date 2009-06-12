require File.dirname(__FILE__) + '/spec_helper'
require File.dirname(__FILE__) + '/../lib/gdata'
require File.dirname(__FILE__) + '/../lib/gdata/client'
require File.dirname(__FILE__) + '/../lib/gdata/blogger'

context GData::Blogger do
  describe 'blogs' do
    before(:each) do
      xml = File.read(File.dirname(__FILE__) + '/fixtures/blogger/blogs.xml')
      
      @bl = GData::Blogger.new
      @bl.should_receive(:get).with('/feeds/default/blogs/').and_return([nil, xml])
      @bl.should_receive(:authenticated?).and_return(true)
    end
    
    it 'should parse all fields from feed for all sites' do
      data = @bl.blogs
      data.length.should eql(2)
      
      blog1 = data[0]
      blog2 = data[1]

      blog1[:id].should eql('123412341234123412')
      blog1[:title].should eql('Test Blog One')

      blog2[:id].should eql('123412341234123412')
      blog2[:title].should eql('Test Blog Two')
    end
  end
end
