# encoding: utf-8

module Yell #:nodoc:

  # The +Level+ class handles the severities for you in order to determine 
  # if an adapter should log or not.
  #
  # In order to setup your level, you have certain modifiers available:
  #   at :warn    # will be set to :warn level only
  #   gt :warn    # Will set from :error level onwards
  #   gte :warn   # Will set from :warn level onwards
  #   lt :warn    # Will set from :info level an below
  #   lte :warn   # Will set from :warn level and below
  #
  # You are able to combine those modifiers to your convenience.
  #
  # @example Set from :info to :error (including)
  #   Yell::Level.new(:info).lte(:error)
  #
  # @example Set from :info to :error (excluding)
  #   Yell::Level.new(:info).lt(:error)
  #
  # @example Set at :info only
  #   Yell::Level.new.at(:info)
  class Level
    module Helpers
      # Accessor to the log level
      attr_reader :level

      # Set the minimum log level.
      #
      # @example Set the level to :warn
      #   level = :warn
      #
      # @param [String, Symbol, Integer] severity The minimum log level
      def level=( severity )
        @level = case severity
          when Yell::Level then severity
          else Yell::Level.new( severity )
        end
      end
    end

    InterpretRegexp = /(at|gt|gte|lt|lte)?\.?(#{Yell::Severities.join('|')})/i

    attr_reader :severities

    # Create a new level instance.
    #
    # @example Enable all severities
    #   Yell::Level.new
    #
    # @example Pass the minimum possible severity
    #   Yell::Level.new :warn
    #
    # @example Pass an array to exactly set the level at the given severities
    #   Yell::Level.new [:info, :error]
    #
    # @example Pass a range to set the level within the severities
    #   Yell::Level.new (:info..:error)
    #
    # @param [Integer,String,Symbol,Array,Range,nil] severity The severity for the level.
    def initialize( severity = nil )
      reset!( severity )
    end

    # Returns whether the level is allowed at the given severity
    #
    # @example
    #   at? :warn
    #   at? 0       # debug
    #
    # @return [Boolean] tru or false
    def at?( severity )
      index = index_from( severity )

      index.nil? ? false : @severities[index]
    end

    # Set the level at specific severities.
    #
    # @example Set at :debug and :error only
    #   at :debug, :error
    #
    # @return [Yell::Level] the instance
    def at( *severities )
      severities.each { |severity| calculate! :==, severity }
      self
    end

    # Set the level to greater than the given severity
    #
    # @example Set to :error and above
    #   gt :warn
    #
    # @return [Yell::Level] the instance
    def gt( severity )
      calculate! :>, severity
      self
    end

    # Set the level greater or equal to the given severity
    #
    # @example Set to :warn and above
    #   gte :warn
    #
    # @return [Yell::Level] the instance
    def gte( severity )
      calculate! :>=, severity
      self
    end

    # Set the level lower than given severity
    #
    # @example Set to lower than :warn
    #   lt :warn
    #
    # @return [Yell::Level] the instance
    def lt( severity )
      calculate! :<, severity
      self
    end

    # Set the level lower or equal than given severity
    #
    # @example Set to lower or equal than :warn
    #   lte :warn
    #
    # @return [Yell::Level] the instance
    def lte( severity )
      calculate! :<=, severity
      self
    end

    # to_i implements backwards compatibility
    def to_i
      @severities.each_with_index { |s,i| return i if s == true }
    end
    alias :to_int :to_i

    # Get a pretty string representation of the level, including the
    # severities.
    #
    # @example Inspect the level.
    #   level.inspect
    #
    # @return [String] The inspection string.
    def inspect
      severities = Yell::Severities.each.with_index.inject( [] ) do |r, (l, i)|
        r << l if @severities[i]
        r
      end

      "#<#{self.class.name} severities: #{severities * ', '}>"
    end


    private

    def reset!( severity )
      @severities = Yell::Severities.map { true }

      case severity
        when Array then at( *severity )
        when Range then gte( severity.first ).lte( severity.last )
        when Integer, Symbol then gte( severity )
        when String then interpret!( severity )
      end
    end

    def interpret!( severities )
      severities.split( ' ' ).each do |severity|
        if m = InterpretRegexp.match(severity)
          m[1].nil? ? __send__( :gte, m[2] ) : __send__( m[1], m[2] )
        end
      end
    end

    def calculate!( modifier, severity )
      index = index_from( severity )
      return if index.nil?

      case modifier
        when :>   then ascending!( index+1 )
        when :>=  then ascending!( index )
        when :<   then descending!( index-1 )
        when :<=  then descending!( index )
        else set!( index ) # :==
      end

      taint unless tainted?
    end

    def index_from( severity )
      case severity
        when Integer        then severity
        when String, Symbol then Yell::Severities.index( severity.to_s.upcase )
        else nil
      end
    end

    def ascending!( index )
      each { |s, i| @severities[i] = i < index ? false : true }
    end

    def descending!( index )
      each { |s, i| @severities[i] = index < i ? false : true }
    end

    def each
      @severities.each_with_index do |s, i|
        next if s == false # skip

        yield(s, i)
      end
    end

    def set!( index, val = true )
      @severities.map! { false } unless tainted?

      @severities[index] = val
    end

  end
end
