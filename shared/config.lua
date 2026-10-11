Config = {}

-- blip settings
Config.Blip = {
    blipSprite = 'blip_honor_bad',
    blipScale = 0.2
}

-- settings
Config.Keybind = 'J'
Config.StorageMaxWeight = 4000000
Config.StorageMaxSlots = 50
Config.InteractDistance = 5.0   -- server-side max distance from a gang location to use stash / money
Config.HireDistance = 10.0      -- max distance between boss and recruit
Config.MaxTransaction = 1000000 -- max single deposit / withdraw

-- id must match the gang name in rsg-core/shared/gangs.lua
Config.GangLocations = {
    {
        id = 'gang1',
        name = 'Gang Menu',
        blipname = 'Gang Name',
        coords = vector3(0, 0, 0),
        showblip = false,
        blipforall = false -- true = everyone sees the blip, false = only gang members
    },
}
