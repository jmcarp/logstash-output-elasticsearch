require "logstash/devutils/rspec/spec_helper"
require "logstash/outputs/elasticsearch/http_client"

describe LogStash::Outputs::ElasticSearch::HttpClient::ManticoreAdapter do
  let(:logger) { Cabin::Channel.get }
  let(:options) { {} }

  subject { described_class.new(logger, options) }

  it "should raise an exception if requests are issued after close" do
    subject.close
    expect { subject.perform_request(::LogStash::Util::SafeURI.new("http://localhost:9200"), :get, '/') }.to raise_error(::Manticore::ClientStoppedException)
  end

  it "should implement host unreachable exceptions" do
    expect(subject.host_unreachable_exceptions).to be_a(Array)
  end
  
  describe "auth" do
    let(:user) { "myuser" }
    let(:password) { "mypassword" }
    let(:noauth_uri) { clone = uri.clone; clone.user=nil; clone.password=nil; clone }
    let(:uri) { ::LogStash::Util::SafeURI.new("http://#{user}:#{password}@localhost:9200") }
    
    it "should convert the auth to params" do
      resp = double("response")
      allow(resp).to receive(:call)
      allow(resp).to receive(:code).and_return(200)
      
      expected_uri = noauth_uri.clone
      expected_uri.path = "/"
      
      expect(subject.manticore).to receive(:get).
        with(expected_uri.to_s, {
          :headers => {"Content-Type" => "application/json"},
          :auth => {
            :user => user,
            :password => password,
            :eager => true
          }
        }).and_return resp
      
      subject.perform_request(uri, :get, "/")
    end
  end

  describe "format_url" do
    let(:url) { ::LogStash::Util::SafeURI.new("http://localhost:9200/path/") }
    let(:path) { "_bulk" }
    subject { described_class.new(double("logger"), {}) }

    it "should add the path argument to the uri's path" do
      expect(java.net.URI.new(subject.format_url(url, path)).path).to eq("/path/_bulk")
    end

    context "when uri contains query parameters" do
      let(:query_params) { "query=value&key=value2" }
      let(:url) { ::LogStash::Util::SafeURI.new("http://localhost:9200/path/?#{query_params}") }
      let(:formatted) { java.net.URI.new(subject.format_url(url, path))}

      it "should retain query_params after format" do
        expect(formatted.query).to eq(query_params)
      end
      
      context "and the path contains query parameters" do
        let(:path) { "/special_path?specialParam=123" }
        
        it "should join the query correctly" do
          expect(formatted.query).to eq(query_params + "&specialParam=123")
        end
      end
    end
    
    context "when the path contains query parameters" do
      let(:path) { "/special_bulk?pathParam=1"}
      let(:formatted) { java.net.URI.new(subject.format_url(url, path)) }
      
      it "should add the path correctly" do
        expect(formatted.path).to eq("#{url.path}special_bulk")
      end 
      
      it "should add the query parameters correctly" do
        expect(formatted.query).to eq("pathParam=1")
      end
    end

    context "when uri contains credentials" do
      let(:url) { ::LogStash::Util::SafeURI.new("http://myuser:mypass@localhost:9200") }
      let(:formatted) { java.net.URI.new(subject.format_url(url, path)) }

      it "should remove credentials after format" do
        expect(formatted.user_info).to be_nil
      end
    end
  end

  describe "integration specs", :integration => true do
    it "should perform correct tests without error" do
      resp = subject.perform_request(::LogStash::Util::SafeURI.new("http://localhost:9200"), :get, "/")
      expect(resp.code).to eql(200)
    end
  end
end
