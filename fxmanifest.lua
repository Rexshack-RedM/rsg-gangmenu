fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'

description 'rsg-gangmenu'
version '1.0.3'

shared_scripts {
    '@ox_lib/init.lua',
    '@rsg-core/shared/locale.lua',
    'locales/en.lua', -- preferred language
    'config.lua',
}

client_scripts {
    'client/client.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/server.lua'
}

server_exports {
    'AddGangMoney',
    'RemoveGangMoney',
    'GetGangAccount',
}

dependencies {
    'rsg-core',
    'ox_lib',
}

lua54 'yes'
