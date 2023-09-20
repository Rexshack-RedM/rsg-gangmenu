local RSGCore = exports['rsg-core']:GetCoreObject()
local PlayerGang = RSGCore.Functions.GetPlayerData().gang

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

local function comma_value(amount)
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
Citizen.CreateThread(function()
    for _, v in pairs(Config.GangLocations) do
        exports['rsg-core']:createPrompt(v.id, v.coords, RSGCore.Shared.Keybinds[Config.Keybind], 'Open '..v.name, {
            type = 'client',
            event = 'rsg-gangmenu:client:mainmenu',
            args = {},
        })
        if v.showblip == true then
            local GangMenuBlip = Citizen.InvokeNative(0x554D9D53F696D002, 1664425300, v.coords)
            SetBlipSprite(GangMenuBlip,  joaat(Config.Blip.blipSprite), true)
            SetBlipScale(Config.Blip.blipScale, 0.2)
            Citizen.InvokeNative(0x9CB1A1623062F402, GangMenuBlip, Config.Blip.blipName)
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
        title = Lang:t('lang_1'),
        options = {
            {
                title = Lang:t('lang_2'),
                description = Lang:t('lang_3'),
                icon = 'fa-solid fa-list',
                event = 'rsg-gangmenu:client:employeelist',
                arrow = true
            },
            {
                title = Lang:t('lang_4'),
                description = Lang:t('lang_5'),
                icon = 'fa-solid fa-hand-holding',
                event = 'rsg-gangmenu:client:HireMenu',
                arrow = true
            },
            {
                title = Lang:t('lang_6'),
                description = Lang:t('lang_7'),
                icon = "fa-solid fa-box-open",
                event = 'rsg-gangmenu:client:Stash',
                arrow = true
            },
            {
                title = Lang:t('lang_8'),
                description = Lang:t('lang_9'),
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
            title = Lang:t('lang_10'),
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
            title = Lang:t('lang_11')..v.name,
            description = Lang:t('lang_12') .. k,
            icon = 'fa-solid fa-file-pen',
            serverEvent = 'rsg-gangmenu:server:GradeUpdate',
            args = { cid = data.player.empSource, grade = tonumber(k), gradename = v.name }
        }
    end
    options[#options + 1] = {
        title = Lang:t('lang_13'),
        icon = "fa-solid fa-user-large-slash",
        serverEvent = 'rsg-gangmenu:server:FireEmployee',
        args = data.player.empSource,
        iconColor = 'red'
    }
    lib.registerContext({
        id = 'managemembers_menu',
        title = Lang:t('lang_14'),
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
                    description = Lang:t('lang_15') .. v.citizenid .. Lang:t('lang_16') .. v.sourceplayer,
                    icon = 'fa-solid fa-user-check',
                    event = 'rsg-gangmenu:server:HireEmployee',
                    args = v.sourceplayer,
                    arrow = true
                }
            end
        end
        lib.registerContext({
            id = 'hiremembers_menu',
            title = Lang:t('lang_4'),
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
    TriggerServerEvent("inventory:server:OpenInventory", "stash", "gang_" .. PlayerGang.name, {
        maxweight = 4000000,
        slots = 25,
    })
    TriggerEvent("inventory:client:SetCurrentStash", "gang_" .. PlayerGang.name)
end)

-------------------------------------------------------------------------------------------
-- society menu
-------------------------------------------------------------------------------------------
RegisterNetEvent('rsg-gangmenu:client:SocietyMenu', function()
    local currentmoney = RSGCore.Functions.GetPlayerData().money['cash']
    RSGCore.Functions.TriggerCallback('rsg-gangmenu:server:GetAccount', function(cb)
        lib.registerContext({
            id = 'gangsociety_menu',
            title = Lang:t('lang_17') .. comma_valueGang(cb),
            options = {
                {
                    title = Lang:t('lang_18'),
                    description = Lang:t('lang_19'),
                    icon = 'fa-solid fa-money-bill-transfer',
                    event = 'rsg-gangmenu:client:SocetyDeposit',
                    args = currentmoney,
                    iconColor = 'green',
                    arrow = true
                },
                {
                    title = Lang:t('lang_20'),
                    description = Lang:t('lang_21'),
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
    local input = lib.inputDialog(Lang:t('lang_22') .. money, {
        { 
            label = Lang:t('lang_23'),
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
    local input = lib.inputDialog(Lang:t('lang_22') .. money, {
        { 
            label = Lang:t('lang_23'),
            type = 'number',
            required = true,
            icon = 'fa-solid fa-dollar-sign'
        },
    })
    if not input then return end
    TriggerServerEvent("rsg-gangmenu:server:withdrawMoney", tonumber(input[1]))
end)
