require 'zlib'
require 'typhoeus'
require 'sax-machine'
require 'loofah'

require 'feedzirra/core_ext'
require 'feedzirra/version'

module Feedzirra
  autoload :FeedEntryUtilities, 'feedzirra/feed_entry_utilities'
  autoload :FeedUtilities,      'feedzirra/feed_utilities'
  autoload :Feed,               'feedzirra/feed'
  autoload :Fetcher,            'feedzirra/fetcher'
  autoload :Parser,             'feedzirra/parser'

  class NoParserAvailable < StandardError; end
end
