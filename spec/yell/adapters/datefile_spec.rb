require 'spec_helper'

describe Yell::Adapters::Datefile do
  let( :filename ) { fixture_path + '/test.log' }
  let( :event ) { Yell::Event.new(1, "Hello World") }

  before do
    Timecop.freeze( Time.now )
  end

  after do
    # release time after each test
    Timecop.return
  end

  describe :filename do
    let( :adapter ) { Yell::Adapters::Datefile.new(:filename => filename, :symlink => false) }

    it "should be replaced with date_pattern" do
      adapter.write( event )

      File.exist?(datefile_filename).should be_true
    end

    it "should open file handle only once" do
      mock( File ).open( datefile_filename, anything ) { File.new('/dev/null', 'w') }

      adapter.write( event )
      Timecop.freeze( Time.now + 10 ) { adapter.write( event ) }
    end

    context "rollover" do
      let( :tomorrow ) { Time.now + 86400 }
      let( :tomorrow_datefile_filename ) { fixture_path + "/test.#{tomorrow.strftime(Yell::Adapters::Datefile::DefaultDatePattern)}.log" }

      it "should rotate when date has passed" do
        mock( File ).open( datefile_filename, anything ) { File.new('/dev/null', 'w') }
        adapter.write( event )

        Timecop.freeze( tomorrow )

        mock( File ).open( tomorrow_datefile_filename, anything ) { File.new('/dev/null', 'w') }
        adapter.write( event )
      end
    end
  end

  describe :keep do
    let( :adapter ) { Yell::Adapters::Datefile.new(:keep => 2, :filename => filename, :date_pattern => "%M") }

    it "should keep the specified number or files upon rollover" do
      adapter.write( event )
      Dir[ fixture_path + '/*.*.log' ].size.should == 1

      Timecop.freeze( Time.now + 60 ) do
        adapter.write( event )
        Dir[ fixture_path + '/*.*.log' ].size.should == 2
      end

      Timecop.freeze( Time.now + 120 ) do
        adapter.write( event )
        Dir[ fixture_path + '/*.*.log' ].size.should == 2
      end
    end
  end

  describe :symlink do
    let( :adapter ) { Yell::Adapters::Datefile.new(:symlink => true, :filename => filename, :date_pattern => "%M") }
    let( :time ) { Time.now }

    it "should symlink to the orignal given :filename" do
      Timecop.freeze( time ) do
        adapter.write( event )

        File.symlink?( filename ).should be_true
        File.readlink( filename ).should == datefile_filename( adapter.date_pattern )
      end

      Timecop.freeze( time + 60 ) do
        adapter.write( event )

        File.symlink?( filename ).should be_true
        File.readlink( filename ).should == datefile_filename( adapter.date_pattern )
      end
    end
  end

  describe :header do
    let( :adapter ) { Yell::Adapters::Datefile.new(:filename => filename) }
    let( :header ) { File.open(datefile_filename, &:readline) }

    before do
      adapter.format = "%m" # easier to parse
    end

    it "should be written by default" do
      adapter.write( event )

      header.should match(Yell::Adapters::Datefile::HeaderRegexp)
    end

    it "should not be written when false" do
      adapter.header = false
      adapter.write( event )

      header.should == "Hello World\n"
    end
  end


  private

  def datefile_filename( pattern = Yell::Adapters::Datefile::DefaultDatePattern )
    fixture_path + "/test.#{Time.now.strftime(pattern)}.log"
  end
end
