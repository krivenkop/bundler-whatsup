require 'fileutils'
require 'open-uri'
require 'gems'
require 'octokit'

module Bundler
  module Whatsup
    # Fetches changelog file for given gem name
    #
    # @example
    #   changelog_content = ChangelogFetcher.load('sinatra').content
    #   has_changelog     = ChangelogFetcher.load('rais').changelog?
    class ChangelogFetcher

      attr_reader :content

      CHANGELOG_NAME_REGEXP = /(?<ch_name>changelog|changes).?(md|txt)?/i
      GEM_REPO_REGEXP = %r{(https|http)://github.com/(?<gem_repo_name>[\S]+/[\S]+)}

      def initialize(gem_info)
        @source_code_uri = gem_info['source_code_uri']
        @homepage_uri = gem_info['homepage_uri']
      end

      class << self

        # Creates and setups Changelog::Fetcher object for given gem name
        #
        # @param gem_name [String] Name of the gem
        # @return [ChangelogFetcher]
        # @example
        #   Changelog::Fetcher.load('nokogiri')
        def load(gem_name)
          gem_info = Gems.info(gem_name.downcase)
          raise ArgumentError, "Gem #{gem_name} not found" if gem_info.empty?
          new(gem_info).load_changelog
        end

      end

      # Checks if gem has changelog file or not
      #
      # @return [Boolean]
      def changelog?
        !@content.nil?
      end

      # Resolves changelog filename
      #
      # @return [String|nil]
      def filename
        # return @changelog_file_name unless @changelog_file_name.nil?
        contents_response = Octokit.contents(repo_name, path: '/')
        files = []
        contents_response.each do |node|
          files.push(node[:name]) if node[:type] == 'file'
        end
        @changelog_file_name = files.grep(CHANGELOG_NAME_REGEXP).first
      end

      # Calculates gem repository name and its owner name at Github based
      # on urls presented in gem metadata
      #
      # @return [String]
      def repo_name

        if @source_code_uri && @source_code_uri.match(GEM_REPO_REGEXP)
          gem_repo_name = @source_code_uri.match(GEM_REPO_REGEXP)[:gem_repo_name]
        elsif @homepage_uri && @homepage_uri.match(GEM_REPO_REGEXP)
          gem_repo_name = @homepage_uri.match(GEM_REPO_REGEXP)[:gem_repo_name]
        else
          raise NameError, "No valid source or homepage url specified for gem #{@gem_name}"
        end

        @gem_repo_name = gem_repo_name.chomp '.git'
      end

      # Loads changelog file and sets its content to @changelog if one is presented
      #
      # @return [ChangelogFetcher]
      def load_changelog
        return self unless filename
        @content = Base64.decode64(Octokit.contents(repo_name, path: filename).content)
        self
      end
    end
  end
end
