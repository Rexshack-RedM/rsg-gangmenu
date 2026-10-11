local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

local PlayerGang = {}
local isFromCommand = false
local gangBlips = {}

local function formatMoney(amount)
    local formatted = tostring(math.floor(tonumber(amount) or 0))
    local k
    repeat
        formatted, k = formatted:gsub('^(-?%d+)(%d%d%d)', '%1,%2')
    until k == 0
    return formatted
end

local function isBoss()
    return PlayerGang and PlayerGang.name and PlayerGang.name ~= 'none' and PlayerGang.isboss
end

local function rootMenu()
    return isFromCommand and 'gang_commandmenu' or 'gang_mainmenu'
end

-------------------------------------------------------------------------------------------
-- blips
-------------------------------------------------------------------------------------------
local function ClearGangBlips()
    for i = 1, #gangBlips do
        if DoesBlipExist(gangBlips[i]) then RemoveBlip(gangBlips[i]) end
    end
    gangBlips = {}
end

local function CreateGangBlips()
    ClearGangBlips()
    local gangName = PlayerGang and PlayerGang.name
    for _, v in ipairs(Config.GangLocations) do
        if v.showblip and (v.blipforall or gangName == v.id) then
            local blip = BlipAddForCoords(1664425300, v.coords)
            SetBlipSprite(blip, joaat(Config.Blip.blipSprite), true)
            SetBlipScale(blip, Config.Blip.blipScale)
            SetBlipName(blip, v.blipname)
            gangBlips[#gangBlips + 1] = blip
        end
    end
end

local function RefreshGang()
    PlayerGang = RSGCore.Functions.GetPlayerData().gang or {}
    CreateGangBlips()
end

AddEventHandler('onResourceStart', function(resource)
    if resource == GetCurrentResourceName() and LocalPlayer.state.isLoggedIn then RefreshGang() end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then ClearGangBlips() end
end)

RegisterNetEvent('RSGCore:Client:OnPlayerLoaded', RefreshGang)

RegisterNetEvent('RSGCore:Client:OnPlayerUnload', function()
    PlayerGang = {}
    ClearGangBlips()
end)

RegisterNetEvent('RSGCore:Client:OnGangUpdate', function(gangInfo)
    PlayerGang = gangInfo or {}
    CreateGangBlips()
end)

CreateThread(function()
    for _, v in ipairs(Config.GangLocations) do
        exports['rsg-core']:createPrompt(v.id, v.coords, RSGCore.Shared.Keybinds[Config.Keybind], locale('cl_open', v.name), {
            type = 'client',
            event = 'rsg-gangmenu:client:mainmenu',
            args = {},
        })
    end
end)

-------------------------------------------------------------------------------------------
-- menus
-------------------------------------------------------------------------------------------
local function notBoss()
    lib.notify({ title = locale('cl_1'), description = locale('cl_cmd_error'), type = 'error', duration = 5000 })
end

local function OpenMenu(fromCommand)
    if not isBoss() then return notBoss() end
    isFromCommand = fromCommand
    local options = {
        { title = locale('cl_2'), description = locale('cl_3'), icon = 'fa-solid fa-list', event = 'rsg-gangmenu:client:employeelist', arrow = true },
        { title = locale('cl_4'), description = locale('cl_5'), icon = 'fa-solid fa-hand-holding', event = 'rsg-gangmenu:client:HireMenu', arrow = true },
    }
    if not fromCommand then
        options[#options + 1] = { title = locale('cl_6'), description = locale('cl_7'), icon = 'fa-solid fa-box-open', serverEvent = 'rsg-gangmenu:server:openinventory' }
        options[#options + 1] = { title = locale('cl_8'), description = locale('cl_9'), icon = 'fa-solid fa-sack-dollar', event = 'rsg-gangmenu:client:SocietyMenu', arrow = true }
    end
    local id = rootMenu()
    lib.registerContext({ id = id, title = PlayerGang.label or locale('cl_1'), options = options })
    lib.showContext(id)
end

RegisterNetEvent('rsg-gangmenu:client:mainmenu', function() OpenMenu(false) end)
RegisterCommand('gangmenu', function() OpenMenu(true) end, false)

RegisterNetEvent('rsg-gangmenu:client:employeelist', function()
    local result = lib.callback.await('rsg-gangmenu:server:GetEmployees', false)
    if not result then return end
    local options = {}
    for _, v in ipairs(result) do
        options[#options + 1] = {
            title = (v.online and '🟢 ' or '❌ ') .. v.name,
            description = ('%s (%s)'):format(v.gradeName, v.gradeLevel),
            icon = 'fa-solid fa-circle-user',
            event = 'rsg-gangmenu:client:ManageEmployee',
            args = v,
            disabled = v.isSelf,
            arrow = not v.isSelf,
        }
    end
    if #options == 0 then options[1] = { title = locale('cl_no_members'), disabled = true } end
    lib.registerContext({ id = 'employeelist_menu', title = locale('cl_10'), menu = rootMenu(), position = 'top-right', options = options })
    lib.showContext('employeelist_menu')
end)

RegisterNetEvent('rsg-gangmenu:client:ManageEmployee', function(emp)
    local gang = RSGCore.Shared.Gangs[PlayerGang.name]
    if not gang then return end
    local myLevel = PlayerGang.grade and PlayerGang.grade.level or 0
    local levels = {}
    for k in pairs(gang.grades) do levels[#levels + 1] = tonumber(k) end
    table.sort(levels)

    local options = {}
    for _, lvl in ipairs(levels) do
        local g = gang.grades[tostring(lvl)] or gang.grades[lvl]
        local current = lvl == emp.gradeLevel
        options[#options + 1] = {
            title = locale('cl_11', g.name),
            description = locale('cl_12') .. ': ' .. lvl .. (current and (' — ' .. locale('cl_current')) or ''),
            icon = 'fa-solid fa-file-pen',
            disabled = current or lvl > myLevel,
            serverEvent = 'rsg-gangmenu:server:GradeUpdate',
            args = { cid = emp.citizenid, grade = lvl },
        }
    end
    options[#options + 1] = {
        title = locale('cl_13'),
        icon = 'fa-solid fa-user-large-slash',
        iconColor = 'red',
        onSelect = function()
            local ok = lib.alertDialog({ header = locale('cl_13'), content = locale('cl_fire_confirm', emp.name), centered = true, cancel = true })
            if ok == 'confirm' then TriggerServerEvent('rsg-gangmenu:server:FireMember', emp.citizenid) end
        end,
    }
    lib.registerContext({ id = 'managemembers_menu', title = emp.name, menu = 'employeelist_menu', position = 'top-right', options = options })
    lib.showContext('managemembers_menu')
end)

RegisterNetEvent('rsg-gangmenu:client:HireMenu', function()
    local players = lib.callback.await('rsg-gangmenu:server:GetNearbyPlayers', false) or {}
    local options = {}
    for _, v in ipairs(players) do
        options[#options + 1] = {
            title = v.name,
            description = locale('cl_15') .. ': ' .. v.citizenid .. ' - ' .. locale('cl_16') .. ': ' .. v.source,
            icon = 'fa-solid fa-user-check',
            serverEvent = 'rsg-gangmenu:server:HireMember',
            args = v.source,
        }
    end
    if #options == 0 then options[1] = { title = locale('cl_no_nearby'), disabled = true } end
    lib.registerContext({ id = 'hiremembers_menu', title = locale('cl_4'), menu = rootMenu(), position = 'top-right', options = options })
    lib.showContext('hiremembers_menu')
end)

-- recruit must accept the invite
lib.callback.register('rsg-gangmenu:client:ConfirmInvite', function(gangLabel)
    return lib.alertDialog({ header = locale('cl_1'), content = locale('cl_invite', gangLabel), centered = true, cancel = true }) == 'confirm'
end)

-------------------------------------------------------------------------------------------
-- money
-------------------------------------------------------------------------------------------
local function moneyDialog(header, balance, serverEvent)
    local input = lib.inputDialog(header, {
        { label = locale('cl_23'), description = locale('cl_22') .. ': $' .. formatMoney(balance), type = 'number', required = true, min = 1, max = math.floor(math.min(balance, Config.MaxTransaction)), icon = 'fa-solid fa-dollar-sign' },
    })
    local amount = input and tonumber(input[1])
    if amount and amount >= 1 then TriggerServerEvent(serverEvent, math.floor(amount)) end
end

RegisterNetEvent('rsg-gangmenu:client:SocietyMenu', function()
    local balance = lib.callback.await('rsg-gangmenu:server:GetAccount', false)
    if not balance then return end
    local cash = RSGCore.Functions.GetPlayerData().money.cash or 0
    lib.registerContext({
        id = 'gangsociety_menu',
        menu = 'gang_mainmenu',
        title = locale('cl_17') .. ': $' .. formatMoney(balance),
        options = {
            { title = locale('cl_18'), description = locale('cl_19'), icon = 'fa-solid fa-money-bill-transfer', iconColor = 'green', disabled = cash < 1,
              onSelect = function() moneyDialog(locale('cl_18'), cash, 'rsg-gangmenu:server:depositMoney') end },
            { title = locale('cl_20'), description = locale('cl_21'), icon = 'fa-solid fa-money-bill-transfer', iconColor = 'red', disabled = balance < 1,
              onSelect = function() moneyDialog(locale('cl_20'), balance, 'rsg-gangmenu:server:withdrawMoney') end },
        }
    })
    lib.showContext('gangsociety_menu')
end)
