fx_version "cerulean"
game 'gta5'
author 'UnKnownJohn'
description 'UD Keypad Stashes'

lua54 'yes'

ui_page 'web/build/index.html'

client_script "client/**/*"
server_script "server/**/*"
shared_script 'config.lua'

files {
	'web/build/index.html',
	'web/build/**/*',
}