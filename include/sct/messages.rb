# encoding: utf-8

# ***************************************************************************
#
# Copyright (c) 2002 - 2012 Novell, Inc.
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.   See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, contact Novell, Inc.
#
# To contact Novell about this file by physical or electronic mail,
# you may find current contact information at www.novell.com
#
# ***************************************************************************
# view_anymsg.ycp
#
# small script for easy /var/log/* and /proc/* viewing
#
# Author: Klaus Kaempf <kkaempf@suse.de>
#
# $Id$

require "yast/core_ext"
require "fileutils"

# Reads a \n separated list of filenames from
# /var/lib/YaST2/filenames
# Lines starting with "#" are ignored (comments)
# A line starting with "*" is taken as the default filename, the "*" is stripped
#
# All files are listed in an editable combo box, where the user can
# easily switch between files and even add a new file
#
# At finish, the list of filenames is written back to
# /var/lib/YaST2/filenames
# adapting the default line (starting with "*") accordingly.
#
# The default is either given as WFM::Args(0) or is the file last viewed.
module Yast
  module SctMessagesInclude
    using Yast::CoreExt::AnsiString
    
    @file_filtered = ""
    @ntsdir

    def messages_viewer_sequence(ntsdir = Directory.vardir)
      Yast.import "UI"
      textdomain "base"

      Yast.import "CommandLine"
      Yast.import "Directory"
      Yast.import "FileUtils"
      Yast.import "Label"

      @ntsdir = ntsdir

      # chdir to supportconfig dir
      Dir.chdir(File.dirname(ntsdir))

      #@file_filtered     = File.join(ntsdir, "file_filtered")
      @file_filtered     = File.join(ntsdir, get_file_filtered_name)
      @file_errors_fails = File.join(ntsdir, "file_errors_fails")
      @is_filtered   = false
      
      # Delete temp files on show dialog 
      filtered_files_delete

      #@vardir = Directory.vardir
      @vardir = ntsdir

      # Check if the filename list is present
      if !FileUtils.Exists(Ops.add(@vardir, "/filenames"))
        SCR.Execute(
          path(".target.bash"),
          Ops.add(
            Ops.add(
              Ops.add(Ops.add("/bin/cp ", Directory.ydatadir), "/filenames "),
              @vardir
            ),
            "/filenames"
          )
        )
      end

      # get filename list
      @filenames = Convert.to_string(
        SCR.Read(path(".target.string"), Ops.add(@vardir, "/filenames"))
      )
      if !@filenames || @filenames.empty?
        @filenames = ""
        logdir = File.join(ntsdir, "rootfs", "/var/log")
        
        # add custom files to the list
        _custom_files = [
          File.join(logdir, "messages"),
          File.join(logdir, "localmessages"),
          File.join(logdir, "warn")
        ]

        _custom_files.each do |custom_file|
          
          #_file_line = custom_file if File.exists?(custom_file)
          #@filenames << "*" + File.join(logdir, "messages") + "\n"
          #@filenames << File.join(logdir, "localmessages") + "\n"
          #@filenames << File.join(logdir, "warn") + "\n"
          @filenames <<  custom_file + "\n" if File.exists?(custom_file)
        end

        # add all available log files to the list   
        Dir["#{logdir}/**/*log"].each do |logfile|
          @filenames << logfile + "\n"
        end

        # set default
        @filenames[0] = "*" + @filenames[0] if @filenames.length > 0
      end

      # convert \n separated string to ycp list.

      @all_files = Builtins.splitstring(@filenames, "\n")

      @set_default = false
      @combo_files = []

      # check if default given as argument

      @filename = ""
      if Ops.greater_than(Builtins.size(WFM.Args), 0) &&
          Ops.is_string?(WFM.Args(0))
        @filename = Convert.to_string(WFM.Args(0))
        if @filename != ""
          @combo_files = [Item(Id(@filename), @filename, true)]
          @set_default = true
        end
      end

      # the command line description map
      @cmdline = { "id" => "view_anymsg" }
      return CommandLine.Run(@cmdline) if @filename == "help"

      # build up ComboBox

      Builtins.foreach(@all_files) do |name|
        # empty lines or lines starting with "#" are ignored
        if name != "" && Builtins.substring(name, 0, 1) != "#"
          # the default is either given via WFM::Args() -> filename != ""
          # or by a filename starting with "*"
          if Builtins.substring(name, 0, 1) == "*"
            name = Builtins.substring(name, 1) # strip leading "*"
            if name != @filename # do not add it twice
              @combo_files = Builtins.add(
                @combo_files,
                Item(Id(name), name, !@set_default)
              )
            end
            if !@set_default
              @filename = name if @filename == ""
              @set_default = true
            end
          elsif name != @filename # do not add it twice
            @combo_files = Builtins.add(@combo_files, Item(Id(name), name))
          end
        end
      end

      if !@set_default && @filename != ""
        @all_files = Builtins.add(@all_files, Ops.add("*", @filename))
        @combo_files = Builtins.add(
          @combo_files,
          Item(Id(@filename), @filename)
        )
      end

      # set up dialogue

      UI.OpenDialog(
        Opt(:decorated, :defaultsize),
        VBox(
          #HSpacing(70), # force width
          HBox(
           # HSpacing(1.0),
           Left(HBox(
             ComboBox(
              Id(:custom_file),
              Opt(:editable, :notify, :hstretch, :key_F3),
              "",
              @combo_files
             ))),
           HSpacing(35.0),
	         Right(
             HBox(
               CheckBox(Id(:search_all), _('Search all files ')),
               CheckBox(Id(:invert_match), _('Invert Grep: ')),
               TextEntry(
                 Id(:filter),
                 Opt(:editable, :key_F4), ""
               ), 
               PushButton(Id(:filter_grep), Opt(:key_F5), "Grep"),
               PushButton(Id(:filter_awk), Opt(:key_F6), "Awk"),
               PushButton(Id(:filter_sort), Opt(:key_F7), "Sort"),
               PushButton(Id(:filter_clear), Opt(:key_F8), "Undo"),
             )
           ),
#            HStretch()
          ),
          VSpacing(0.3),
          VWeight(
            1,
            HBox(
              VSpacing(18), # force height
              HSpacing(0.7),
              LogView(
                Id(:log), 
                "",
                3, # height
                0
              ), # number of lines to show
              HSpacing(0.7)
            )
          ),
          #VSpacing(0.3),
          HBox(
            PushButton(Id(:ok), Label.OKButton),
            PushButton(Id(:errors_fails), Opt(:key_F11), "Errors/Fails"),
          )
          #VSpacing(0.3)
        )
      )

      @go_on = true

      # wait until user clicks "OK"
      # check if ComboBox selected and change view accordingly

      while @go_on

        # read file content
        file_content = SCR.Read(path(".target.string"), @filename)

        if file_content
          # remove ANSI color escape sequences
          file_content.remove_ansi_sequences
          # remove remaining ASCII control characters (ASCII 0-31 and 127 (DEL))
          # except new line (LF = 0xa) and carriage return (CR = 0xd)
          file_content.tr!("\u0000-\u0009\u000b\u000c\u000e-\u001f\u007f", "")
        else
          file_content = _("File not found: " + @filename)
        end

        # Fill the LogView with file content
        UI.ChangeWidget(Id(:log), :Value, file_content)

        heading = Builtins.sformat(_("System Log (%1)"), @filename)
        UI.ChangeWidget(Id(:log), :Label, heading)

        # Enable or disable button_clear
        @is_filtered = @filename == @file_filtered 
        UI.ChangeWidget(Id(:filter_clear), :Enabled, @is_filtered)

        # wait for user input

        @ret = Convert.to_symbol(UI.UserInput)

        # clicked "OK" -> exit

        if @ret == :ok
          # delete temp files
          filtered_files_delete

          # clear filter if currently applied
          @new_file = Convert.to_string(
              UI.QueryWidget(Id(:custom_file), :Value)
          )
          @filename = @new_file if !@new_file.nil?

          # exit loop on next iteration
          @go_on = false

        elsif @ret == :custom_file
          # adapt to combo box settings

          @new_file = Convert.to_string(
            UI.QueryWidget(Id(:custom_file), :Value)
          )
          @filename = @new_file if !@new_file.nil?

        elsif @ret == :filter_grep
          _is_invert_match = Convert.to_boolean(UI.QueryWidget(Id(:invert_match), :Value))
          _is_search_all   = Convert.to_boolean(UI.QueryWidget(Id(:search_all), :Value))

          # get input from textbox
          _filter_str = UI.QueryWidget(Id(:filter), :Value).to_s   
          
          _files = []
          if _is_search_all

            # grep through all log files
            @combo_files.each do |file|
                _files.push(file[1])
            end 
            filter_search_all(@filename, _filter_str, _is_invert_match, _files)
          else

            # only grep current logview
            filter_content(@filename, _filter_str, _is_invert_match)
          end

          @filename = @file_filtered

          UI.ChangeWidget(Id(:invert_match), :Value, false)
          UI.ChangeWidget(Id(:search_all), :Value, false)

        elsif @ret == :filter_awk
          # get input from textbox
          _filter_str = UI.QueryWidget(Id(:filter), :Value).to_s   
          
          if _filter_str.include?("$")
            filter_awk(@filename, _filter_str)
            @filename = @file_filtered

            columnize_text_file(@filename, '#')
          else
            Popup.Error(_("Awk expression must include $ sign."))
          end
          UI.ChangeWidget(Id(:invert_match), :Value, false)
          UI.ChangeWidget(Id(:search_all), :Value, false)

        elsif @ret == :filter_sort
          filter_sort(@filename)
          UI.ChangeWidget(Id(:invert_match), :Value, false)
          UI.ChangeWidget(Id(:search_all), :Value, false)


        elsif @ret == :filter_clear
          File.rename(@file_filtered + '.tmp', @file_filtered + '.temp') if 
            File.exists?(@file_filtered + '.tmp')
          File.rename(@file_filtered, @file_filtered + '.tmp') if 
            File.exists?(@file_filtered)
          File.rename(@file_filtered + '.temp', @file_filtered) if 
            File.exists?(@file_filtered + '.temp')

        elsif @ret == :errors_fails
          if !File.exists?(@file_errors_fails)
            File.open(@file_errors_fails, "w+") {}
            Yast::Wizard.CreateDialog
              help  = _("<p>Creating summary page for errror count.</p>")
              label = _("Scanning files for errors.")
              Yast::Progress.Simple(label, label, @combo_files.length, help)
  
              @combo_files.each do |file|
                file = file[1]
  
                Yast::Progress.NextStage()
                Yast::Progress.Title("Reading file " + file)
                
                count_errors(file)
              end
              Yast::Progress.NextStage()
            Yast::Wizard.CloseDialog
          end
          columnize_text_file(@file_errors_fails, '#')
          @filename = @file_errors_fails

        else
          Builtins.y2milestone("bad UserInput (%1)", @ret)
        end
      end

      # write new list of filenames

      @new_files = []
      @set_default = false

      # re-build list to get new default correct
      Builtins.foreach(@all_files) do |file|
        if Builtins.substring(file, 0, 1) == "*"
          old_default = Builtins.substring(file, 1) # strip leading "*"
          if old_default == @filename # default unchanged
            @new_files = Builtins.add(@new_files, file)
            @set_default = true # new default
          else
            @new_files = Builtins.add(@new_files, old_default)
          end
        elsif file != ""
          if file == @filename # mark new default
            @new_files = Builtins.add(@new_files, Ops.add("*", @filename))
            @set_default = true
          else
            @new_files = Builtins.add(@new_files, file)
          end
        end
      end
      # if we don't have a default by now, it wasn't in the list before
      # so add it here.

      if !@set_default && @filename != ""
        @new_files = Builtins.add(@new_files, Ops.add("*", @filename))
      end

      @new_files = Builtins.toset(@new_files)

      # convert ycp list back to \n separated string

      @filenames = Ops.add(Builtins.mergestring(@new_files, "\n"), "\n")

      SCR.Write(
        path(".target.string"),
        Ops.add(@vardir, "/filenames"),
        @filenames
      )

      UI.CloseDialog

      true
    end

    def filtered_files_delete()
      File.delete(@file_filtered) if File.exist?(@file_filtered)
      File.delete(@file_filtered + ".tmp") if File.exist?(@file_filtered + ".tmp")
      File.delete(@file_filtered + ".temp") if File.exist?(@file_filtered + ".temp")
    end

    def filter_content(file, str, invert)
      # copy curent logview content to @file_filtered.tmp for undo purposes
      # then grep
      invert_match = invert ? " -v " : ""
      cmd2 = Builtins.sformat(
        "/usr/bin/cp \"%1\" \"%2\" \;\n /usr/bin/egrep -i " + 
          invert_match + " \"%3\" \"%2\" > %4 ",
        file,
        @file_filtered + ".tmp",
        str,
        @file_filtered
      )
      SCR.Execute(Yast::Path.new(".target.bash"), cmd2)
    end

    def filter_search_all(file, str, invert, files)
      invert_match = invert ? " -v " : ""


      # copy curent logview content to @file_filtered.tmp for undo purposes
      # then grep
      ::FileUtils.cp(file, @file_filtered + ".tmp")
      File.delete(@file_filtered) if File.exists?(@file_filtered)
      _cut_end = @ntsdir.length + "/rootfs/".length 

      cmd2 = Builtins.sformat(
        "/usr/bin/egrep -i " + invert_match + " \"%1\" %2 \| cut -c" + _cut_end.to_s  + "-  >> %3 ",
        str,
        files.join(" "),
        @file_filtered
      )
      SCR.Execute(Yast::Path.new(".target.bash"), cmd2)
    end

    def filter_awk(file, str)
      _awk_str = str.split(" ")
      _awk_str = _awk_str.map { |arg| arg + " \"#\""  }

      # copy curent logview content to @file_filtered.tmp for undo purposes
      # then grep
      cmd2 = Builtins.sformat(
        "/usr/bin/cp \"%1\" \"%2\" \;\n /usr/bin/awk -F \" \" '/1/ {print " + 
          _awk_str.join(" ") + "}' \"%2\" > %3 ",
        file,
        @file_filtered + ".tmp",
        @file_filtered
      )
      SCR.Execute(Yast::Path.new(".target.bash"), cmd2)
    end

    def filter_sort(file)
      # copy curent logview content to @file_filtered.tmp for undo purposes
      # then grep
      ::FileUtils.cp(file, @file_filtered + ".tmp")
      File.delete(@file_filtered) if File.exists?(@file_filtered)

      cmd2 = Builtins.sformat(
        "/usr/bin/sort -u \"%1\" > %2 ",
        @file_filtered + ".tmp",
        @file_filtered
      )
      SCR.Execute(Yast::Path.new(".target.bash"), cmd2)
    end

    def count_errors(file)
      cmd2 = Builtins.sformat(
        "/usr/bin/echo \"%1\"\# " + 
        "Errors: `/usr/bin/egrep \"error\" -i \"%1\" \| wc -l`\# " + 
        "Fatal: `egrep \"fatal\" -i \"%1\" \| wc -l`\# " +
        "Fails: `egrep \"fail\" -i \"%1\" \| wc -l` " + 
        "\| /usr/bin/egrep -v 'Errors: 0# Fails: 0' >> \"%2\" ",
        file,
        @file_errors_fails
      )
      SCR.Execute(Yast::Path.new(".target.bash"), cmd2)
    end

    def columnize_text_file(file, separator)
      cmd2 = Builtins.sformat(
        "/usr/bin/cp \"%1\" \"%2\" \; /usr/bin/column -t -s%3 \"%2\" > \"%1\" \;  /usr/bin/rm -f \"%2\"",
        file,
        file + '.columnize',
        separator
      )
      SCR.Execute(Yast::Path.new(".target.bash"), cmd2)
    end

    def get_file_filtered_name()
      rnum = rand(1000)
      @file_filtered = "file_filtered_" + rnum.to_s.rjust(4,"0")
    end

  end
end

