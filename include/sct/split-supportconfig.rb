#!/usr/bin/ruby
#
# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
#   DO NOT USE THIS DIRECTLY!  Instead use unpack-supportconfig which
#   wraps around it.  However it's recommended to install from rpms -
#   see https://github.com/aspiers/SUSE-dist for details.
# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
#
# Splits out (de-multiplexes) file contents from a supportconfig file
# into the original tree structure, relative to a new 'rootfs'
# sub-directory.
#
# Example usage:
#   tar jxf nts_d00-1e-67-29-c7-e8_130802_0915.tbz
#   cd nts_d00-1e-67-29-c7-e8_130802_0915
#   split-supportconfig *.txt
# ***************************************************************************
#
# Author: Adam Spiers <aspiers@suse.com>
#


require "yast"
require "fileutils"


module Yast
  module SctSplitSupportconfigInclude 

    def split_supportconfig(text_file)
      
      basedir   = File.dirname(text_file)
      @FILE_HEADER    = /^#==\[ (Configuration File|Log File) \]===+#/
      @ANY_HEADER     = /^#==\[ (.+) \]===+#/
      @OUT_DIR        = File.join(basedir, 'rootfs')

      need = :file_header
      file = nil
      input_file = nil
      rootfs = false
    
      f = File.open(text_file, "rb")
      f.binmode
      
      f.each do |line|
        if f.path != input_file
          input_file = f.path
          #puts input_file
        end
      
        case need
      
        when :file_header
          case line
          when @FILE_HEADER
            need = :file_path
          when @ANY_HEADER
            # case $1
            # when 'Section Header', 'Validating RPM'
            # else
            #   puts line
            # end
          else
            next
          end
      
        when :file_path
          case line
          when %r{^\# (.+?) - (File not found|not found by plugin)\s*$}
            need = :file_header
          when %r{^# ((/bin/)?grep .+?)( - Last \d+ Lines)?$}
            need = :file_header
          when %r{^\# /+(.+?)( - Last \d+ Lines)?$}, /^# (.+\.(log|xml))/
            filepath = @OUT_DIR + "/#$1"
            ::FileUtils.mkdir_p(File.dirname(filepath))
            file = File.open(filepath, 'w')
            need = :lines
            rootfs = true
          else
            #raise "Was expecting filepath immediately after header but got:\n#{line}"
            next
          end
      
        when :lines
          case line
          when @ANY_HEADER
            file.close
            need = :file_header
            redo
          else
            file.write(line)
          end
        end
      end
      f.close()

      if rootfs
        if ! File.directory? @OUT_DIR
          raise "WARNING: #{@OUT_DIR} was not created"
        end
        
        Dir.chdir @OUT_DIR
        #puts "\nSplit files are in #{Dir.pwd}"
      end
    end
  end
end

