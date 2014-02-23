module Feedzirra
  class Feed

    # Passes raw XML and callbacks to a parser.
    # === Parameters
    # [parser<Object>] The parser to pass arguments to - must respond to
    # `parse` and should return a Feed object.
    # [xml<String>] The XML that you would like parsed.
    # === Returns
    # An instance of the parser feed type.
    def self.parse_with(parser, xml, &block)
      parser.parse xml, &block
    end

    # Takes a raw XML feed and attempts to parse it. If no parser is available a Feedzirra::NoParserAvailable exception is raised.
    # You can pass a block to be called when there's an error during the parsing.
    # === Parameters
    # [xml<String>] The XML that you would like parsed.
    # === Returns
    # An instance of the determined feed type. By default, one of these:
    # * Feedzirra::Parser::RSSFeedBurner
    # * Feedzirra::Parser::GoogleDocsAtom
    # * Feedzirra::Parser::AtomFeedBurner
    # * Feedzirra::Parser::Atom
    # * Feedzirra::Parser::ITunesRSS
    # * Feedzirra::Parser::RSS
    # === Raises
    # Feedzirra::NoParserAvailable : If no valid parser classes could be found for the feed.
    def self.parse(xml, &block)
      if parser = determine_feed_parser_for_xml(xml)
        parse_with parser, xml, &block
      else
        raise NoParserAvailable.new("No valid parser for XML.")
      end
    end

    # Determines the correct parser class to use for parsing the feed.
    #
    # === Parameters
    # [xml<String>] The XML that you would like determine the parser for.
    # === Returns
    # The class name of the parser that can handle the XML.
    def self.determine_feed_parser_for_xml(xml)
      start_of_doc = xml.slice(0, 2000)
      feed_classes.detect {|klass| klass.able_to_parse?(start_of_doc)}
    end

    def self.parse(body, &function)
      klass = determine_feed_parser_for_xml(body)
      if klass
        parse_with klass, body, &function
      else
        raise 'Cant determine parser'
      end
    end

    # Adds a new feed parsing class that will be used for parsing.
    #
    # === Parameters
    # [klass<Constant>] The class/constant that you want to register.
    # === Returns
    # A updated array of feed parser class names.
    def self.add_feed_class(klass)
      feed_classes.unshift klass
    end

    # Provides a list of registered feed parsing classes.
    #
    # === Returns
    # A array of class names.
    def self.feed_classes
      @feed_classes ||= [
        Feedzirra::Parser::RSSFeedBurner,
        Feedzirra::Parser::GoogleDocsAtom,
        Feedzirra::Parser::AtomFeedBurner,
        Feedzirra::Parser::Atom,
        Feedzirra::Parser::ITunesRSS,
        Feedzirra::Parser::RSS
      ]
    end

    # Makes all registered feeds types look for the passed in element to parse.
    # This is actually just a call to element (a SAXMachine call) in the class.
    #
    # === Parameters
    # [element_tag<String>] The element tag
    # [options<Hash>] Valid keys are same as with SAXMachine
    def self.add_common_feed_element(element_tag, options = {})
      feed_classes.each do |k|
        k.element element_tag, options
      end
    end

    # Makes all registered feeds types look for the passed in elements to parse.
    # This is actually just a call to elements (a SAXMachine call) in the class.
    #
    # === Parameters
    # [element_tag<String>] The element tag
    # [options<Hash>] Valid keys are same as with SAXMachine
    def self.add_common_feed_elements(element_tag, options = {})
      feed_classes.each do |k|
        k.elements element_tag, options
      end
    end

    # Makes all registered entry types look for the passed in element to parse.
    # This is actually just a call to element (a SAXMachine call) in the class.
    #
    # === Parameters
    # [element_tag<String>]
    # [options<Hash>] Valid keys are same as with SAXMachine
    def self.add_common_feed_entry_element(element_tag, options = {})
      call_on_each_feed_entry :element, element_tag, options
    end

    # Makes all registered entry types look for the passed in elements to parse.
    # This is actually just a call to element (a SAXMachine call) in the class.
    #
    # === Parameters
    # [element_tag<String>]
    # [options<Hash>] Valid keys are same as with SAXMachine
    def self.add_common_feed_entry_elements(element_tag, options = {})
      call_on_each_feed_entry :elements, element_tag, options
    end

    # Call a method on all feed entries classes.
    #
    # === Parameters
    # [method<Symbol>] The method name
    # [parameters<Array>] The method parameters
    def self.call_on_each_feed_entry(method, *parameters)
      feed_classes.each do |k|
        # iterate on the collections defined in the sax collection
        k.sax_config.collection_elements.each_value do |vl|
          # vl is a list of CollectionConfig mapped to an attribute name
          # we'll look for the one set as 'entries' and add the new element
          vl.find_all{|v| (v.accessor == 'entries') && (v.data_class.class == Class)}.each do |v|
              v.data_class.send(method, *parameters)
          end
        end
      end
    end

    # Fetches and returns the parsed XML for each URL provided.
    #
    # === Parameters
    # [urls<String> or <Array>] A single feed URL, or an array of feed URLs.
    # [options<Hash>] Valid keys for this argument as as followed:
    # * :user_agent - String that overrides the default user agent.
    # * :if_modified_since - Time object representing when the feed was last updated.
    # * :if_none_match - String, an etag for the request that was stored previously.
    # * :on_success - Block that gets executed after a successful request.
    # * :on_failure - Block that gets executed after a failed request.
    # === Returns
    # A Feed object if a single URL is passed.
    #
    # A Hash if multiple URL's are passed. The key will be the URL, and the value the Feed object.
    def self.fetch_and_parse(urls, options = {})
      return Fetcher.new(options).fetch_and_parse(urls)
    end
  end
end
