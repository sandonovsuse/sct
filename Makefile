USER := $(shell whoami)

ifeq ($(USER), root)
  DIR := /usr/share/YaST2
else
  DIR := ~/.yast2
endif

install:
	mkdir -p $(DIR)/clients 
	mkdir -p $(DIR)/include/sct 
	mkdir -p $(DIR)/include/sctcrowbar 
	mkdir -p $(DIR)/modules
	cp clients/sct.rb $(DIR)/clients/sct.rb
	cp include/sct/supportconfig.rb $(DIR)/include/sct/supportconfig.rb
	cp include/sct/host.rb $(DIR)/include/sct/host.rb
	cp include/sct/split-supportconfig.rb $(DIR)/include/sct/split-supportconfig.rb
	cp include/sct/messages.rb $(DIR)/include/sct/messages.rb
	cp include/sctcrowbar/complex.rb $(DIR)/include/sctcrowbar/complex.rb
	cp include/sctcrowbar/helps.rb $(DIR)/include/sctcrowbar/helps.rb
	cp include/sctcrowbar/wizards.rb $(DIR)/include/sctcrowbar/wizards.rb
	cp modules/SCT.rb $(DIR)/modules/SCT.rb
	cp modules/SCTCrowbar.rb $(DIR)/modules/SCTCrowbar.rb
	cp modules/SCTHost.rb $(DIR)/modules/SCTHost.rb

clean:
	rm -rf $(DIR)/include/sct
	rm -rf $(DIR)/include/sctcrowbar
	rm -rf $(DIR)/clients/sct.rb
	rm -rf $(DIR)/modules/SCT.rb
	rm -rf $(DIR)/modules/SCTCrowbar.rb
	rm -rf $(DIR)/modules/SCTHost.rb
