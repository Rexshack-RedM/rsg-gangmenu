local RSGCore = exports['rsg-core']:GetCoreObject()
local PlayerGang = RSGCore.Functions.GetPlayerData().gang
lib.locale()

AddEventHandler('onResourceStart', function(resource)
    if resource == GetCurrentResourceName() then
        PlayerGang = RSGCore.Functions.GetPlayerData().gang
    end
end)

RegisterNetEvent('RSGCore:Client:OnPlayerLoaded', function()
    PlayerGang = RSGCore.Functions.GetPlayerData().gang
end)

RegisterNetEvent('RSGCore:Client:OnJobUpdate', function(JobInfo)
    PlayerGang = InfoGang
end)

local function comma_valueGang(amount)
    local formatted = amount
    while true do
        local k
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
        if (k == 0) then
            break
        end
    end
    return formatted
end

-------------------------------------------------------------------------------------------
-- prompts and blips if needed
-------------------------------------------------------------------------------------------
CreateThread(function()
    for _, v in pairs(Config.GangLocations) do
        exports['rsg-core']:createPrompt(v.id, v.coords, RSGCore.Shared.Keybinds[Config.Keybind], locale('cl_open').. ' ' ..v.name, {
            type = 'client',
            event = 'rsg-gangmenu:client:mainmenu',
            args = {},
        })
        if v.showblip == true then
            local GangMenuBlip = BlipAddForCoords(1664425300, v.coords)
            SetBlipSprite(GangMenuBlip,  joaat(Config.Blip.blipSprite), true)
            SetBlipScale(GangMenuBlip, Config.Blip.blipScale)
            SetBlipName(GangMenuBlip, Config.Blip.blipName)
        end
    end
end)

-------------------------------------------------------------------------------------------
-- main menu
-------------------------------------------------------------------------------------------
RegisterNetEvent('rsg-gangmenu:client:mainmenu', function()
    if not PlayerGang.name or not PlayerGang.isboss then return end
    lib.registerContext({
        id = 'gang_mainmenu',
        title = locale('cl_1'),
        options = {
            {
                title = locale('cl_2'),
                description = locale('cl_3'),
                icon = 'fa-solid fa-list',
                event = 'rsg-gangmenu:client:employeelist',
                arrow = true
            },
            {
                title = locale('cl_4'),
                description = locale('cl_5'),
                icon = 'fa-solid fa-hand-holding',
                event = 'rsg-gangmenu:client:HireMenu',
                arrow = true
            },
            {
                title = locale('cl_6'),
                description = locale('cl_7'),
                icon = "fa-solid fa-box-open",
                event = 'rsg-gangmenu:client:Stash',
                arrow = true
            },
            {
                title = locale('cl_8'),
                description = locale('cl_9'),
                icon = "fa-solid fa-sack-dollar",
                event = 'rsg-gangmenu:client:SocietyMenu',
                arrow = true
            },
        }
    })
    lib.showContext("gang_mainmenu")
end)

-------------------------------------------------------------------------------------------
-- employee menu
-------------------------------------------------------------------------------------------
RegisterNetEvent('rsg-gangmenu:client:employeelist', function()
    RSGCore.Functions.TriggerCallback('rsg-gangmenu:server:GetEmployees', function(result)
        local options = {}
        for _, v in pairs(result) do
            options[#options + 1] = {
                title = v.name,
                description = v.grade.name,
                icon = 'fa-solid fa-circle-user',
                event = 'rsg-gangmenu:client:ManageEmployee',
                args = { player = v, work = PlayerGang },
                arrow = true,
            }
        end
        lib.registerContext({
            id = 'employeelist_menu',
            title = locale('cl_10'),
            menu = 'gang_mainmenu',
            onBack = function() end,
            position = 'top-right',
            options = options
        })
        lib.showContext('employeelist_menu')
    end, PlayerGang.name)
end)

-------------------------------------------------------------------------------------------
-- manage employees
-------------------------------------------------------------------------------------------
RegisterNetEvent('rsg-gangmenu:client:ManageEmployee', function(data)
    local options = {}
    for k, v in pairs(RSGCore.Shared.Gangs[data.work.name].grades) do
        options[#options + 1] = {
            title = locale('cl_11').. ' ' ..v.name,
            description = locale('cl_12').. ': ' .. k,
            icon = 'fa-solid fa-file-pen',
            serverEvent = 'rsg-gangmenu:server:GradeUpdate',
            args = { cid = data.player.empSource, grade = tonumber(k), gradename = v.name }
        }
    end
    options[#options + 1] = {
        title = locale('cl_13'),
        icon = "fa-solid fa-user-large-slash",
        serverEvent = 'rsg-gangmenu:server:FireMember',
        args = data.player.empSource,
        iconColor = 'red'
    }
    lib.registerContext({
        id = 'managemembers_menu',
        title = locale('cl_14'),
        menu = 'employeelist_menu',
        onBack = function() end,
        position = 'top-right',
        options = options
    })
    lib.showContext('managemembers_menu')
end)

-------------------------------------------------------------------------------------------
-- hire employees
-------------------------------------------------------------------------------------------
RegisterNetEvent('rsg-gangmenu:client:HireMenu', function()
    RSGCore.Functions.TriggerCallback('rsg-gangmenu:getplayers', function(players)
        local options = {}
        for _, v in pairs(players) do
            if v and v ~= PlayerId() then
                options[#options + 1] = {
                    title = v.name,
                    description = locale('cl_15').. ': ' .. v.citizenid .. ' - '.. locale('cl_16') .. ': '.. v.sourceplayer,
                    icon = 'fa-solid fa-user-check',
                    serverEvent = 'rsg-gangmenu:server:HireMember',
                    args = v.sourceplayer,
                    arrow = true
                }
            end
        end
        lib.registerContext({
            id = 'hiremembers_menu',
            title = locale('cl_4'),
            menu = 'gang_mainmenu',
            onBack = function() end,
            position = 'top-right',
            options = options
        })
        lib.showContext('hiremembers_menu')
    end)
end)

-------------------------------------------------------------------------------------------
-- boss stash
-------------------------------------------------------------------------------------------
RegisterNetEvent('rsg-gangmenu:client:Stash', function()
    local stashname = 'gang_' .. PlayerGang.name
    TriggerServerEvent('rsg-gangmenu:server:openinventory', stashname)
end)

-------------------------------------------------------------------------------------------
-- society menu
-------------------------------------------------------------------------------------------
RegisterNetEvent('rsg-gangmenu:client:SocietyMenu', function()
    local currentmoney = RSGCore.Functions.GetPlayerData().money['cash']
    RSGCore.Functions.TriggerCallback('rsg-gangmenu:server:GetAccount', function(cb)
        lib.registerContext({
            id = 'gangsociety_menu',
            title = locale('cl_17').. ': $ ' .. comma_valueGang(cb),
            options = {
                {
                    title = locale('cl_18'),
                    description = locale('cl_19'),
                    icon = 'fa-solid fa-money-bill-transfer',
                    event = 'rsg-gangmenu:client:SocetyDeposit',
                    args = currentmoney,
                    iconColor = 'green',
                    arrow = true
                },
                {
                    title = locale('cl_20'),
                    description = locale('cl_21'),
                    icon = 'fa-solid fa-money-bill-transfer',
                    event = 'rsg-gangmenu:client:SocetyWithDraw',
                    args = comma_valueGang(cb),
                    iconColor = 'red',
                    arrow = true
                },
            }
        })
        lib.showContext("gangsociety_menu")
    end, PlayerGang.name)
end)

-------------------------------------------------------------------------------------------
-- society deposit
-------------------------------------------------------------------------------------------
RegisterNetEvent('rsg-gangmenu:client:SocetyDeposit', function(money)
    local input = lib.inputDialog(locale('cl_22').. ': $ ' .. money, {
        { 
            label = locale('cl_23'),
            type = 'number',
            required = true,
            icon = 'fa-solid fa-dollar-sign'
        },
    })
    if not input then return end
    TriggerServerEvent("rsg-gangmenu:server:depositMoney", tonumber(input[1]))
end)

-------------------------------------------------------------------------------------------
-- society withdraw
-------------------------------------------------------------------------------------------
RegisterNetEvent('rsg-gangmenu:client:SocetyWithDraw', function(money)
    local input = lib.inputDialog(locale('cl_22').. ': $ ' .. money, {
        { 
            label = locale('cl_23'),
            type = 'number',
            required = true,
            icon = 'fa-solid fa-dollar-sign'
        },
    })
    if not input then return end
    TriggerServerEvent("rsg-gangmenu:server:withdrawMoney", tonumber(input[1]))
end)