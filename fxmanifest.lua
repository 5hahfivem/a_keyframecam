fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'Amphy + Claude🧏🏿‍♂️'
description 'Free-cam + keyframe sequencer for cinematic shots'
version '1.0.0'

shared_script '@ox_lib/init.lua'

client_scripts {
    'client/main.lua',
}

dependency 'ox_lib'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
}
