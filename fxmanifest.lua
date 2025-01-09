fx_version "cerulean"
game 'gta5'
author 'UnKnownJohn'
description 'UD Keypad Stashes'

lua54 'yes'

shared_scripts {
	'@ox_lib/init.lua'
}

client_script "client/**/*"
server_script "server/**/*"

ui_page 'web/build/index.html'

files {
	'web/build/index.html',
	'web/build/**/*',
}

dependencies {
	'ox_lib',
	'ox_target'
}