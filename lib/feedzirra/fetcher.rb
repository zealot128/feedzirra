module Feedzirra
  class Fetcher
    USER_AGENT = "feedzirra http://github.com/pauldix/feedzirra/tree/master"
    def initialize(options)
      @options = options
    end

    def fetch_and_parse(urls)
      hydra = Typhoeus::Hydra.new
      responses = {}

      # I broke these down so I would only try to do 30 simultaneously because
      # I was getting weird errors when doing a lot. As one finishes it pops another off the queue.
      [*urls].each do |url|
        add_url_to_multi(hydra, url, responses)
      end

      hydra.run
      return urls.is_a?(String) ? responses.values.first : responses
    end

    # Setup curl from options.
    # Possible parameters:
    # * :user_agent          - overrides the default user agent.
    # * :compress            - any value to enable compression
    # * :enable_cookies      - boolean
    # * :cookiefile          - file to read cookies
    # * :cookies             - contents of cookies header
    # * :http_authentication - array containing username, then password
    # * :proxy_url           - proxy url
    # * :proxy_port          - proxy port
    # * :max_redirects       - max number of redirections
    # * :timeout             - timeout
    # * :ssl_verify_host     - boolean
    # * :ssl_verify_peer     - boolean
    # * :ssl_version         - the ssl version to use, see OpenSSL::SSL::SSLContext::METHODS for options
    def http_options
      headers = {}
      headers["If-Modified-Since"] = @options[:if_modified_since].httpdate if @options.has_key?(:if_modified_since)

      headers["If-None-Match"]     = @options[:if_none_match] if @options.has_key?(:if_none_match)
      headers["Accept-encoding"]   = 'gzip, deflate' if @options.has_key?(:compress)
      headers["User-Agent"]        = (@options[:user_agent] || USER_AGENT)
      options = { headers: headers }
      # curl.enable_cookies               = options[:enable_cookies] if options.has_key?(:enable_cookies)
      # curl.cookiefile                   = options[:cookiefile] if options.has_key?(:cookiefile)
      # curl.cookies                      = options[:cookies] if options.has_key?(:cookies)

      # curl.userpwd = options[:http_authentication].join(':') if options.has_key?(:http_authentication)
      # curl.proxy_url = options[:proxy_url] if options.has_key?(:proxy_url)
      # curl.proxy_port = options[:proxy_port] if options.has_key?(:proxy_port)
      # curl.max_redirects = options[:max_redirects] if options[:max_redirects]
      # curl.timeout = options[:timeout] if options[:timeout]
      # curl.ssl_version = options[:ssl_version] if options.has_key?(:ssl_version)
      options[:ssl_verifyhost] =  @options[:ssl_verify_host] if @options.has_key?(:ssl_verify_host)
      options[:followlocation] = true
      options[:ssl_verify_peer] = @options[:ssl_verify_peer] if @options.has_key?(:ssl_verify_peer)
      options
    end


    # An abstraction for adding a feed by URL to the passed Curb::multi stack.
    #
    # === Parameters
    # [multi<Curl::Multi>] The Curl::Multi object that the request should be added too.
    # [url<String>] The URL of the feed that you would like to be fetched.
    # [url_queue<Array>] An array of URLs that are queued for request.
    # [responses<Hash>] Existing responses that you want the response from the request added to.
    # [feeds<String> or <Array>] A single feed object, or an array of feed objects.
    # [options<Hash>] Valid keys for this argument as as followed:
    #                 * :on_success - Block that gets executed after a successful request.
    #                 * :on_failure - Block that gets executed after a failed request.
    #                 * all parameters defined in setup_easy
    # === Returns
    # The updated Curl::Multi object with the request details added to it's stack.
    def add_url_to_multi(hydra, url, responses)
      easy = Typhoeus::Request.new(url, http_options)
      easy.on_complete do |response|
        if response.success?
          xml = decode_content(response)
          feed = nil
          begin
            feed = Feed.parse(xml, &on_parser_failure(url))
            feed.etag = etag_from_header(response.headers.to_s)
            feed.last_modified = last_modified_from_header(response.headers.to_s)
            feed.feed_url = response.effective_url
            responses[url] = feed
            @options[:on_success].call(url, feed) if @options.has_key?(:on_success)
          rescue Exception => e
            binding.pry
            call_on_failure(response, e, @options[:on_failure])
          end
        end

        if response.timed_out? or response.code == 0 or response.code > 400
          responses[url] = c.response_code unless responses.has_key?(url)
          call_on_failure(response, err, @options[:on_failure])
        end
      end
      hydra.queue easy
    end

    def etag_from_header(header)
      header =~ /.*ETag:\s(.*)\r/
      $1
    end

    def last_modified_from_header(header)
      header =~ /.*Last-Modified:\s(.*)\r/
      Time.parse_safely($1) if $1
    end

    private


    def on_parser_failure(url)
      Proc.new { |message| raise "Error while parsing [#{url}] #{message}" }
    end

    def call_on_failure(c, error, on_failure)
      if on_failure
        if on_failure.arity == 4
          warn 'on_failure proc with deprecated arity 4 should include a fifth parameter containing the error'
          on_failure.call(c.url, c.response_code, c.header_str, c.body_str)
        elsif on_failure.arity == 2
          on_failure.call(c, error)
        else
          warn "on_failure proc with invalid parameters number #{on_failure.arity} instead of 2, ignoring it"
        end
      end
    end

    # Decodes the XML document if it was compressed.
    #
    # === Parameters
    # [curl_request<Curl::Easy>] The Curl::Easy response object from the request.
    # === Returns
    # A decoded string of XML.
    def decode_content(c)
      if c.headers.to_s.match(/Content-Encoding: gzip/i)
        begin
          gz =  Zlib::GzipReader.new(StringIO.new(c.body))
          xml = gz.read
          gz.close
        rescue Zlib::GzipFile::Error
          # Maybe this is not gzipped?
          xml = c.body
        end
      elsif c.headers.to_s.match(/Content-Encoding: deflate/i)
        binding.pry
        xml = Zlib::Inflate.inflate(c.body)
      else
        xml = c.body
      end

      xml
    end
  end
end
