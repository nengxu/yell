# encoding: utf-8

module Yell #:nodoc:
  module Adapters #:nodoc:

    # The +Datefile+ adapter is similar to the +File+ adapter. However, it
    # rotates the file at midnight (by default).
    class Datefile < Yell::Adapters::File

      # The default date pattern, e.g. "19820114" (14 Jan 1982)
      DefaultDatePattern = "%Y%m%d"

      # Metadata
      Header = lambda { |date, pattern| "# -*- #{date.iso8601} (#{date.to_f}) [#{pattern}] -*-" }
      HeaderRegexp = /^# -\*- (.+) \((\d+\.\d+)\) \[(.+)\] -\*-$/


      setup do |options|
        @date, @date_strftime = nil, nil # default; do not override --R

        # check whether to write the log header (default true)
        self.header = options.fetch(:header, true)

        # check the date pattern on the filename (default "%Y%m%d")
        self.date_pattern = options.fetch(:date_pattern, DefaultDatePattern)

        # check whether to cleanup old files of the same pattern (default false)
        self.keep = options.fetch(:keep, false)

        # check whether to symlink the otiginal filename (default true)
        self.symlink = options.fetch(:symlink, true)

        @original_filename  = ::File.expand_path options.fetch(:filename, default_filename)
        options[:filename]  = @original_filename
      end

      write do |event|
        # do nothing when not closing
        return unless close?
        close

        # exit when file ready present
        return if ::File.exist?( @filename )

        # write the header if applicable
        stream.puts( Header.call(@date, date_pattern) ) if header?

        symlink! if symlink?
        cleanup! if cleanup?
      end

      close do
        @filename = filename_for( @date )
      end


      # The pattern to be used for the files
      #
      # @example
      #   date_pattern = "%Y%m%d"       # default
      #   date_pattern = "%Y-week-%V"
      attr_accessor :date_pattern

      # Tell the adapter to create a symlink onto the currently
      # active (timestamped) file. Upon rollover, the symlink is
      # set to the newly created file, and so on.
      #
      # @example
      #   symlink = true
      attr_accessor :symlink

      # Set the amount of logfiles to keep when rolling over.
      # By default, no files will be cleaned up.
      #
      # @example Keep the last 5 logfiles
      #   keep = 5
      #   keep = '10'
      #
      # @example Do not clean up any files
      #   keep = 0
      attr_accessor :keep

      # You can suppress the first line of the logfile that contains
      # the metadata. This is important upon rollover, because on *nix
      # systems, it is not possible to determine the creation time of a file,
      # on the last access time. The header compensates this.
      #
      # @example
      #   header = false
      attr_accessor :header


      private

      # Determine whether to close the file handle or not.
      #
      # It is based on the `:date_pattern` (can be passed as option upon initialize).
      # If the current time hits the pattern, it closes the file stream.
      #
      # @return [Boolean] true or false
      def close?
        _date           = Time.now
        _date_strftime  = _date.strftime(date_pattern)

        if @stream.nil? or _date_strftime != @date_strftime
          @date, @date_strftime = _date, _date_strftime

          return true
        end

        false
      end

      # Removes old logfiles of the same date pattern.
      #
      # By reading the header of the files that match the date pattern, the
      # adapter determines whether to remove them or not. If no header is present,
      # it makes the best guess by checking the last access time (which may result
      # in false cleanups).
      def cleanup!
        files = Dir[ @original_filename.sub( /(\.\w+)?$/, ".*\\1" ) ].sort.select do |file|
          created, pattern = header_from(file)

          # Select if the date pattern is nil (no header info available within the file) or
          # when the pattern matches.
          pattern.nil? || pattern == self.date_pattern
        end

        ::File.unlink( *files[0..-keep-1] )
      end

      # Cleanup old logfiles?
      #
      # @return [Boolean] true or false
      def cleanup?
        !!keep && keep.to_i > 0
      end

      # Symlink the current filename to the original one.
      def symlink!
        # do nothing, because symlink is already correct
        return if ::File.symlink?(@original_filename) && ::File.readlink(@original_filename) == @filename

        ::File.unlink( @original_filename ) if ::File.exist?( @original_filename )
        ::File.symlink( @filename, @original_filename )
      end

      # Symlink the original filename?
      #
      # @return [Boolean] true or false
      def symlink?; !!symlink; end

      # Write header into the file?
      #
      # @return [Boolean] true or false
      def header?; !!header; end

      # Sets the filename with the `:date_pattern` appended to it.
      def filename_for( date )
        @original_filename.sub( /(\.\w+)?$/, ".#{date.strftime(date_pattern)}\\1" )
      end

      # Fetch the header form the file
      def header_from( file )
        if m = ::File.open( file, &:readline ).match( HeaderRegexp )
          # in case there is a Header present, we can just read from it
          [ Time.at( m[2].to_f ), m[3] ]
        else
          # In case there is no header: we need to take a good guess
          #
          # Since the pattern can not be determined, we will just return the Posix ctime.
          # That is NOT the creatint time, so the value will potentially be wrong!
          [ ::File.ctime(file), nil ]
        end
      end

      # @override
      def inspectables
        super.concat [:date_pattern, :header, :keep, :symlink ]
      end

    end

    register( :datefile, Yell::Adapters::Datefile )

  end
end

