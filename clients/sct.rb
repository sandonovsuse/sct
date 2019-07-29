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
# File:        clients/scp.ycp
# Author:      sandonov@suse.com
# Summary:     A tool to perform essential operations on a supportconfig file. 
#

module Yast
  class SCTClient < Client
    def main
      Yast.import "UI"
      textdomain "sct"
      Yast.import "Wizard"
      Yast.import "Label"
      Yast.import "SCT"
      Yast.import "Popup"
      Yast.import "Package"
      Yast.import "DialogTree"
      Yast.import "Progress"
      Yast.import "Message"


      if !SCT.browse_aborted 
        if SCT.supportconfig_filelist.length > 0 
          @tabs = SCT.tabs()
          @tree_dialogs = SCT.supportconfig_filelist
          @widgets_handling = SCT.WidgetHandling() 
    
          @functions = { :abort => nil } 
    
          DialogTree.ShowAndRun(
            {
              "ids_order"      => @tree_dialogs,
              "initial_screen" => @tree_dialogs[0],
              "screens"        => @tabs,
              "widget_descr"   => @widgets_handling,
              "back_button"    => nil, #Label::BackButton(),
              "abort_button"   => nil, #Label.CancelButton,
              "next_button"    => Label.OKButton,
              "functions"      => @functions
            }
          )
        elsif 
          Popup.Error(_("No supportconfigs found in " + SCT.supportconfig_basedir + 
                  "\nAborting." ))
        end
      end
 
    end
  end
end

Yast::SCTClient.new.main
