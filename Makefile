.PHONY: put putall get

put:
	cp -f ./ZZShopper.lua  /Volumes/Elder\ Scrolls\ Online/live/AddOns/ZZShopper/

putall:
	cp -f ./ZZShopper.lua  /Volumes/Elder\ Scrolls\ Online/live/AddOns/ZZShopper/
	cp -f ./ZZShopper.txt  /Volumes/Elder\ Scrolls\ Online/live/AddOns/ZZShopper/

get:
	cp -f /Volumes/Elder\ Scrolls\ Online/live/SavedVariables/ZZShopper.lua data/

