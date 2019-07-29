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
# you may find selected contact information at www.novell.com
#
# ***************************************************************************
require "yast"
module Yast
  class SCTClass < Module

    @@supportconfig_basedir  = ""
    @@supportconfig_filelist = ""
    @@ntsdirs                = Array.new
    @@supportconfigs         = Hash.new 
    @browse_aborted          = false

    def main
      textdomain "sct"
      Yast.import "Popup"
      Yast.include self, "sct/supportconfig.rb"

      @@supportconfig_basedir  = Dir.pwd
      @@supportconfig_filelist = get_supportconfigs()

      if @@supportconfig_filelist.length < 1
        browse()
        @@supportconfig_filelist = get_supportconfigs()
      end

    end

    def supportconfig_basedir 
      @@supportconfig_basedir
    end
    def supportconfig_filelist
      @@supportconfig_filelist
    end

    def browse_aborted
      @browse_aborted
    end
 
    def unpack_supportconfig(selected)
      Yast::Wizard.CreateDialog
      help  = _("<p>Unpacking tarball and rootfs.</p>")
      label = _("Unpacking supportconfig")

      stage_titles = [
        "Unpacking " + selected + " [" + "%.2f" % @@supportconfigs[selected].size.to_s + " MB]",
        "Splitting root file system..."
      ]

      Yast::Progress.New(label, label, 4, stage_titles, stage_titles, help)
      Yast::Progress::SubprogressType(:progress, 100);
      Yast::Progress.NextStage
      Yast::Progress.NextStep

      # unpack tarball
      @@supportconfigs[selected].untarball() if !@@supportconfigs[selected].is_untarred? and !@@supportconfigs[selected].isdir
      Yast::Progress.NextStage

      # split rootfs
      filelist = @@supportconfigs[selected].get_files()
      Yast::Progress::SubprogressType(:progress, filelist.length);
      subprogress_value = 0;
      filelist.each do |txtfile|
        Yast::Progress::SubprogressTitle("Splitting file " + txtfile);
        Yast::Progress::SubprogressValue(subprogress_value += 1);
        @@supportconfigs[selected].split(txtfile)
        if subprogress_value > filelist.length * 1/2 
          Yast::Progress.Step(3)
        end
      end

      Yast::Progress.NextStage
      Yast::Wizard.CloseDialog
    end

    def get_supportconfigs()
      _tar_extensions = "{tar.gz,.tgz,.tbz,tar.bz2,tar}"
      _tars = Dir[@@supportconfig_basedir + "/*" +  _tar_extensions]
      _dirs = Dir.entries(Dir.pwd).map { |entry|  File.join(Dir.pwd, entry) if
                File.directory?(entry) and entry.include?("nts") }
      # remove nil elements
      _dirs = _dirs.compact
      
      # return union of _tars and _dirs
      _tars + _dirs
    end

    def tabs()
      Yast::Wizard.CreateDialog
      help  = _("<p>Creating summary page for each supportconfig.</p>")
      label = _("Reading supportconfigs")
      Yast::Progress.Simple(label, label, @@supportconfig_filelist.length, help)

      tab_items = Hash.new

      @@supportconfig_filelist.each do |sc|
        Yast::Progress.NextStage()
        Yast::Progress.Title("Reading file " + sc)
        # initialize supportconfigs
        suppconf = @@supportconfigs[sc] = SC.new(sc)

        # skip if supportconfig already loaded - i.e. skip ntsdir if tgz loaded
        if @@ntsdirs.include?(suppconf.ntsdir)
          @@supportconfig_filelist = @@supportconfig_filelist - [sc]
          next
        end
        
        # add to the list of ntsdirs
        @@ntsdirs.push(suppconf.ntsdir)
    
        # buttons
        button_extract = PushButton(
                    Id("extract"),
                    Opt(:key_F3),
                    _("Unpack\/split")
                  )
        button_syscfg = PushButton(
                    Id("page_sysconfig"),
                    Opt(:key_F4),
                    _("Sysconfig")
                  )

        button_syslog = PushButton(
                    Id("page_syslog"),
                    Opt(:key_F6),
                    _("System log")
                  )
                  
        button_hosts = PushButton(
                    Id("page_hosts"),
                    Opt(:key_F5),
                    _("Host")
                  )

        button_crowbar = PushButton(
                    Id("page_crowbar"),
                    Opt(:key_F7),
                    _("Crowbar"))

        button_reset = PushButton(
                    Id("reset"),
                    Opt(:key_F3),
                    _("Reset")
                  )

        # Create list of available actions
        if suppconf.supported
          button_list_left = HBox(button_extract, button_reset)
          button_list_right = suppconf.is_cloud_crowbar_admin? ?
            HBox(button_crowbar, button_syscfg, button_hosts, button_syslog) :
            HBox(button_syscfg, button_hosts, button_syslog) 
        else
          button_list_left = HBox(button_reset)
          button_list_right = HBox()
        end

        # create tab
        tab_item = {
          "contents" => 
            VBox(
              HBox(RichText(suppconf.get_summary().to_s)),
              HBox(Left(button_list_left), Right(button_list_right))
            ),
          "caption" => 
            Ops.add(
              Ops.add("SupportConfig", ": "), _(suppconf.basedir)
            ),
          "tree_item_label" => _(suppconf.basename),
          "widget_names"    => [suppconf.full_path]
        }
        # push to tab hash
        tab_items[sc] = tab_item
      end
        Yast::Progress.NextStage()
        Yast::Wizard.CloseDialog
      return tab_items
    end

    def WidgetHandling()
      whandling_items = Hash.new
      @@supportconfig_filelist.each do |sc|
        whandling_item =
          {
            "widget"        => :custom,
            "custom_widget" => VBox(),
            "init"          => nil,
            "handle"        => fun_ref(method(:HandleSpecs), "symbol (string, map)" ),
            "help"          => _(
              "<p><b><big>Supportconfig Tool</big></b><br>\<br>\n" +
              "\tA tool to perform essential operations on a supportconfig tgz file,\n" +
              "\tspanning from unpacking and splitting the archive, to running any \n" +
              "\tcurrently ported YaST module against its root file system. \n" +
              "\tHBReports are currently not supported. \n" +
              "\t</p>\n" +
              "\t"
            )
          }
        whandling_items[sc] = whandling_item
      end
      return whandling_items
    end

    def HandleSpecs(key, event)
      event = deep_copy(event)
      ret = Ops.get(event, "ID")

      # selected supportconfig
      _selected = key.to_s
      
      if ret == "extract"
        unpack_supportconfig(_selected)
        UI.SetFocus(Id(:wizardTree)) 

      # reset and remove rootfs
      elsif ret == "reset"
        _reset = Popup.YesNo(_("Supportconfig " + @@supportconfigs[_selected].basename +
                       ":\nremove rootfs and reset info (requires restart)?"))

        # todo progress bar for deleting rootfs
        if _reset

          # cleanup 
          _delete_files    = [@@supportconfigs[_selected].summary_file]
          _delete_files.push(File.join(@@supportconfigs[_selected].ntsdir, "filenames"))
          _delete_files.push(File.join(@@supportconfigs[_selected].ntsdir, "file_errors_fails"))

          _delete_files.each do |_dfile|
            File.delete(_dfile) if File.exists?(_dfile)
          end

          # delete rootfs
          if @@supportconfigs[_selected].supported
            require 'fileutils'
            _rootfsdir = File.join(@@supportconfigs[_selected].ntsdir, "rootfs")
            ::FileUtils.rm_rf(_rootfsdir) if File.directory?(_rootfsdir)
          end
        end
        UI.SetFocus(Id(:wizardTree))
        :next if _reset

      # bring up YaST module sysconfig
      elsif ret == "page_sysconfig"
        if @@supportconfigs[_selected].is_unpacked?

          Yast.import "Sysconfig"
  
          # change file locations to unpacked rootfs
          _rootfs_folder = File.join(@@supportconfigs[_selected].ntsdir, "rootfs")
          Sysconfig.configfiles = [
            _rootfs_folder + "/etc/sysconfig/*",
            _rootfs_folder + "/etc/sysconfig/network/ifcfg-*",
            _rootfs_folder + "/etc/sysconfig/network/dhcp",
            _rootfs_folder + "/etc/sysconfig/network/config",
            Ops.add(Directory.ydatadir, "/descriptions"),
            _rootfs_folder + "/etc/sysconfig/powersave/*",
            _rootfs_folder + "/etc/sysconfig/uml/*"
          ]

          Yast.include self, "sysconfig/wizards.rb"
          Yast.include self, "sysconfig/complex.rb"
          SysconfigSequence()
        else
          Popup.Error(_("Supportconfig not unpacked"))
        end
        UI.SetFocus(Id(:wizardTree)) 

      # bring up system log 
      elsif ret == "page_syslog"
        if @@supportconfigs[_selected].is_unpacked?
          Yast.include self, "sct/messages.rb"
          messages_viewer_sequence(@@supportconfigs[_selected].ntsdir)
        else
          Popup.Error(_("Supportconfig not unpacked"))
        end
        UI.SetFocus(Id(:wizardTree)) 

      # bring up hosts 
      elsif ret == "page_hosts"
        if @@supportconfigs[_selected].is_unpacked?
          Yast.import "SCTHost"
          Yast.include self, "sct/host.rb"
          SCTHost.hosts_file = File.join(@@supportconfigs[_selected].ntsdir,
                                          "rootfs/etc/hosts")

          Wizard.CreateDialog
          Wizard.SetDesktopTitleAndIcon("host")
          Wizard.SetNextButton(:next, Label.FinishButton)
          HostsMainDialog(true)
          UI.CloseDialog
          SCTHost.clear
        else
          Popup.Error(_("Supportconfig not unpacked"))
        end
        UI.SetFocus(Id(:wizardTree)) 

      # bring up YaST module crowbar
      elsif ret == "page_crowbar"
        if @@supportconfigs[_selected].is_unpacked?
          Yast.import "SCTCrowbar"
          Yast.include self, "sctcrowbar/wizards.rb"
          Yast.include self, "sctcrowbar/complex.rb"
          
          # crowbar files from unpacked rootfs 
          _crowbar_network_file  = File.join(@@supportconfigs[_selected].ntsdir, 
                                            "rootfs/etc/crowbar/network.json")
          _crowbar_crowbar_file  = File.join(@@supportconfigs[_selected].ntsdir, 
                                            "rootfs/etc/crowbar/crowbar.json")

          # reference to a nonexisting file as it is not included in supportconfig
          _crowbar_installed_file = File.join(@@supportconfigs[_selected].ntsdir, 
                                            "crowbar_installed_ok")
          # set the values 
          SCTCrowbar.network_file   = _crowbar_network_file
          SCTCrowbar.crowbar_file   = _crowbar_crowbar_file
          SCTCrowbar.installed_file = _crowbar_installed_file 
          SCTCrowbar.repos_file     = _crowbar_installed_file
          SCTCrowbar.etc_repos_file = _crowbar_installed_file

          # run crowbar sequence
          CrowbarSequence()
        else
          Popup.Error(_("Supportconfig not unpacked"))
        end

        # prevents abort after crowbar module 
        UI.SetFocus(Id(:wizardTree)) 

      end
    end

    def browse()
      UI.OpenDialog(
        Opt(:decorated),
        HBox(
          HSpacing(1),
          HCenter(
            HSquash(
              VBox(
                HCenter(
                  HSquash(
                    VBox(
                      Left(VSpacing(0.2)),
                      VSpacing(0.2),
                      Left(TextEntry(Id(:location), _("Supportconfig directory:"))),
                    )
                  )
                ),
                HSquash(
                  HBox(
                    PushButton(Id(:OK),  Opt(:default, :key_F10, :okButton), Label.OKButton),
                    PushButton(Id(:cancel), Opt(:key_F9), Label.CancelButton)
                  )
                ),
                VSpacing(0.2)
              )
            )
          ),
          HSpacing(1)
        )
      )
        # set value to current dir
        UI.ChangeWidget(:location, :Value, Dir.pwd)
      ret = nil
      while true
        ret = Wizard.UserInput
        Builtins.y2debug("ret=%1", ret)
        if ret == :OK
          @@supportconfig_basedir = Convert.to_string(UI.QueryWidget(Id(:location), :Value))
          break
        elsif ret == :back
          @browse_aborted = true
          break
        end
      end
      UI.CloseDialog
      Convert.to_symbol(ret)
    end
  end

  SCT = SCTClass.new
  SCT.main
end
