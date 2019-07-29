# encoding: utf-8
#
# ------------------------------------------------------------------------------
# Copyright (c) 2006 Novell, Inc. All Rights Reserved.
#
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of version 2 of the GNU General Public License as published by the
# Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with
# this program; if not, contact Novell, Inc.
#
# To contact Novell about this file by physical or electronic mail, you may find
# current contact information at www.novell.com.
# ------------------------------------------------------------------------------
# supportconfig class 
#
# Author: Sasha Andonov <sandonov@suse.com>
#

require "yast"

module Yast
  module SctSupportconfigInclude
    class SC
      @full_path
      @supported  
      @size
      @summary_file
      @ntsdir
      @basename
      @@basedir
      @split_blacklist
      @isdir
  
      def initialize(filename)
        @full_path       = filename
        @size            = File.size(@full_path).to_f / 2**20
        @basename        = File.basename(@full_path)
        @@basedir        = File.dirname(@full_path)
        @supported       = true
        @summary_file    = File.join(@@basedir, "." + @basename + ".summary")
        @split_blacklist = ["proc.txt"] 
        @isdir           = File.directory?(@full_path)
  
        # try and get ntsdir name
        @ntsdir = get_ntsdir()

        # create .summary file
        if !summary_file_exists?
          # untar "rpm.txt" and "summary.xml" only, if already not present
          unpack_info() if !(@ntsdir and is_untarred?(["rpm.txt", "summary.xml"]))
          
          # generate summary page
          generate_summary()   

          # fix permissions
          _chmod_list = [@summary_file] 
          _chmod_list += @supported ? [@ntsdir] + Dir[@ntsdir +  "/*"] : []
          fix_permissions(_chmod_list.join(" ")) 
        end

        # if .summary file already exists, read ntsdir
        if !@ntsdir
          @ntsdir = get_ntsdir()
        end
      end

      def is_cloud_crowbar_admin?
        if @supported 
          _rpmfile = File.join(@ntsdir, "rpm.txt")
          File.open(_rpmfile).grep(/crowbar\-core/).length > 0 
        end
      end

      def summary_file_exists?
        File.exist?(@summary_file)
      end

      def is_unpacked?
        FileUtils.Exists(File.join(@ntsdir, "rootfs"))
      end
      
      def is_untarred?(_files_needed = nil)
        if !_files_needed
          _files_needed = [
            "etc.txt", 
            "systemd.txt", 
            "messages.txt", 
            "rpm.txt", 
            "summary.xml"
          ]
        end

        # prepare regexp var to grep against an array of files in next step
        _regex = Regexp.new(_files_needed.join("|"), true)
        
        # check if all _files_needed are extracted
        Dir[@ntsdir + "/*{txt,xml}"].grep(_regex).length == _files_needed.length
      end

      def unpack_info()
        _tmpfile = ".stdout.tmp"
        
        # untar */summary.xml and write its relative path to summary_file
        _files_to_untar = ["summary.xml", "rpm.txt"]

        # if we already know ntsdir do not use --wildarcds on untar
        wildcards = true
        if @ntsdir
          _files_to_untar.map! { |file| File.join(File.basename(@ntsdir), file) }
          wildcards = false
        end

        # untar files redirecting stdout to _tmpfile
        unpacked = untar(_files_to_untar.join(" "), _tmpfile, wildcards) 
        @supported = unpacked == 0 ? true : false

        # initialize @ntsdir
        if @supported
          summary_xml_path = File.open(_tmpfile, &:readline)
          @ntsdir          = File.join(@@basedir, File.dirname(summary_xml_path))
        end 
        File.delete(_tmpfile) if File.exists?(_tmpfile)
      end

      def generate_summary()
        if @supported 
          # read relative path to summary.xml 
          summary_xml_path = File.join(@ntsdir, "summary.xml")
      
          # parse summary.xml and write to summary_file
          nts_string = "<b>" + File.basename(@ntsdir) + "</b>\n</p>\n"
          summary = parse_summary_xml(summary_xml_path)
        else
          nts_string = "Not supported.\n"
        end

        file_write(@summary_file, nts_string + summary.to_s)
      end
        
      def get_summary()
        return file_read(@summary_file)
      end
  
      def get_ntsdir()
        # summary already generated
        if summary_file_exists?
          line = File.open(@summary_file, &:readline)
          _nts_dir = line.scan(/>([^#]*)</).first
          _nts_dir = _nts_dir.last if _nts_dir 
        else
          # provided supportconfig is an extracted directory
          if File.directory?(@full_path)
           _nts_dir = @basename
          # supportconfig is a file
          else
           _untar_param = is_gzip? ? "-ztvf" : "-tvf"
           _nts_dir = `/bin/tar #{_untar_param} #{@full_path} | head -1 | rev | cut -f2 -d\/ | cut -f1 -d' ' | rev`
           _nts_dir = _nts_dir.include?("nts") ? _nts_dir.sub!("\n", "") : nil
          end
        end

        if !_nts_dir
          @supported = false
          return nil
        else
          return File.join(@@basedir, _nts_dir)
        end
      end
  
  
      def file_read(file)
        f = File.open(file)
        data = f.read
        f.close()
        return data
      end
  
      def file_write(file, data)
        f = File.open(file, "w")
        f.write(data)
        f.close()
      end
  
      def split(text_file)
        Yast.include self, "sct/split-supportconfig.rb"
        split_supportconfig(text_file)
      end
  
      def get_files()
        # add absolute path to blacklisted files
        _blacklist = @split_blacklist.map { |file| File.join(@ntsdir, file) }

        # return file list
        Dir[@ntsdir + "/*txt"] - _blacklist
      end
  
      def is_gzip?
        tar_extensions_gz = "tar\.gz|\.tgz"
        File.basename(@full_path).match(tar_extensions_gz) 
      end

      def untar(files_to_extract = "", redirection = "/dev/null", _wildcard = true)
        untar_param       = _wildcard ? "--wildcards " : " "
        wildcard_asterisk = _wildcard ? "*/" : ""
        untar_param      += is_gzip? ? "-zxvf" : "-xvf"
  
        cmd2 = Builtins.sformat(
                 "/bin/tar %1 %2 %3 %4 > %5",
                 untar_param,
                 @full_path,
                 "-C " + @@basedir,
                 #"\"*/" + files_to_extract + "\"",
                 files_to_extract.split(" ").map{ |file| "\"" + wildcard_asterisk + file + "\"" }.join(" "),
                 redirection
              )
        SCR.Execute(Yast::Path.new(".target.bash"), cmd2)
      end

      def untarball()
        untar("", "/dev/null", false)

       # file permissions
        _chmod_list = Dir[@ntsdir +  "/*"] 
        fix_permissions(@ntsdir + " " + _chmod_list.join(" "))
      end
  
      def fix_permissions(list)
        list.split(" ").each do |file|
          File.chmod(0775, file)
        end
      end

      def parse_summary_xml(summary_file)
        xml_str = file_read(summary_file)
  
        # from description string
        desc_string = "" 
        xml_str.each_line.grep(/\/hostname/). each do |hostname|
          desc_string += "<p><b>Hostname:</b>\t" + hostname + "</p>\n"
        end
        xml_str.each_line.grep(/\/shortsummary/).each do |product|
          desc_string += "<p><b>Products:</b>\t" + product + "</p>\n"
        end
        xml_str.each_line.grep(/\/kernel/).each do |kernel|
          desc_string += "<p><b>Kernel  :</b>\t" + kernel + "</p>\n"
        end

        return desc_string
      end

      # published vars
      def basename
        @basename
      end
      def ntsdir
        @ntsdir
      end
      def basedir 
        @@basedir
      end
      def summary_file
        @summary_file
      end
      def full_path
        @full_path
      end
      def size
        @size
      end
      def supported
        @supported
      end
      def isdir
        @isdir
      end

    end
  end
end

