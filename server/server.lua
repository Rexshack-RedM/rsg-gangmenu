local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

local GangAccounts = {}
local PendingInvites = {}
local Cooldowns = {}

-----------------------------------------------------------------------
-- helpers
-----------------------------------------------------------------------
local function notify(src, title, description, nType)
    TriggerClientEvent('ox_lib:notify', src, { title = title, description = description, type = nType or 'inform', duration = 5000 })
end

local function fullName(charinfo)
    return ('%s %s'):format(charinfo.firstname or '', charinfo.lastname or '')
end

local function log(title, colour, message)
    TriggerEvent('rsg-log:server:CreateLog', 'gangmenu', title, colour, message, false)
end

-- returns Player if src is the boss of a real gang
local function GetBoss(src)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    local gang = Player.PlayerData.gang
    if not gang or gang.name == 'none' or not gang.isboss or not RSGCore.Shared.Gangs[gang.name] then return end
    return Player
end

local function IsNearGangLocation(src, gangName)
    local coords = GetEntityCoords(GetPlayerPed(src))
    for _, v in ipairs(Config.GangLocations) do
        if v.id == gangName and #(coords - v.coords) <= Config.InteractDistance then return true end
    end
    return false
end

local function OnCooldown(src)
    local now = GetGameTimer()
    if Cooldowns[src] and now - Cooldowns[src] < 1000 then return true end
    Cooldowns[src] = now
    return false
end

local function SanitizeAmount(amount)
    amount = tonumber(amount)
    if not amount or amount ~= amount then return end
    amount = math.floor(amount)
    if amount < 1 or amount > Config.MaxTransaction then return end
    return amount
end

AddEventHandler('playerDropped', function()
    Cooldowns[source] = nil
    PendingInvites[source] = nil
end)

-----------------------------------------------------------------------
-- account functions / exports
-----------------------------------------------------------------------
function GetGangAccount(account)
    return GangAccounts[account] or 0
end

local function SaveAccount(account)
    MySQL.insert('INSERT INTO management_funds (job_name, amount, type) VALUES (?, ?, "gang") ON DUPLICATE KEY UPDATE amount = VALUES(amount)',
        { account, GangAccounts[account] })
end

function AddGangMoney(account, amount)
    amount = tonumber(amount)
    if not account or not amount or amount <= 0 then return false end
    GangAccounts[account] = (GangAccounts[account] or 0) + amount
    SaveAccount(account)
    return true
end

function RemoveGangMoney(account, amount)
    amount = tonumber(amount)
    if not account or not amount or amount <= 0 then return false end
    local balance = GangAccounts[account] or 0
    if balance < amount then return false end
    GangAccounts[account] = balance - amount
    SaveAccount(account)
    return true
end

MySQL.ready(function()
    local rows = MySQL.query.await('SELECT job_name, amount FROM management_funds WHERE type = "gang"')
    for _, v in ipairs(rows or {}) do
        GangAccounts[v.job_name] = v.amount
    end
end)

-----------------------------------------------------------------------
-- stash (name derived server-side, location-locked)
-----------------------------------------------------------------------
RegisterNetEvent('rsg-gangmenu:server:openinventory', function()
    local src = source
    local Player = GetBoss(src)
    if not Player then return end
    local gang = Player.PlayerData.gang.name
    if not IsNearGangLocation(src, gang) then return end
    exports['rsg-inventory']:OpenInventory(src, 'gang_' .. gang, { label = locale('sv_storage'), maxweight = Config.StorageMaxWeight, slots = Config.StorageMaxSlots })
end)

-----------------------------------------------------------------------
-- money
-----------------------------------------------------------------------
lib.callback.register('rsg-gangmenu:server:GetAccount', function(src)
    local Player = GetBoss(src)
    if not Player then return end
    return GetGangAccount(Player.PlayerData.gang.name)
end)

RegisterNetEvent('rsg-gangmenu:server:withdrawMoney', function(amount)
    local src = source
    local Player = GetBoss(src)
    if not Player or OnCooldown(src) then return end
    amount = SanitizeAmount(amount)
    if not amount then return end
    local gang = Player.PlayerData.gang.name
    if not IsNearGangLocation(src, gang) then return end

    if RemoveGangMoney(gang, amount) then
        Player.Functions.AddMoney('cash', amount, 'gang-menu-withdraw')
        log(locale('sv_25'), 'yellow', ('%s %s $%s (%s)'):format(fullName(Player.PlayerData.charinfo), locale('sv_51'), amount, gang))
        notify(src, locale('cl_1'), locale('sv_27') .. ': $' .. amount, 'success')
    else
        notify(src, locale('cl_1'), locale('sv_28'), 'error')
    end
end)

RegisterNetEvent('rsg-gangmenu:server:depositMoney', function(amount)
    local src = source
    local Player = GetBoss(src)
    if not Player or OnCooldown(src) then return end
    amount = SanitizeAmount(amount)
    if not amount then return end
    local gang = Player.PlayerData.gang.name
    if not IsNearGangLocation(src, gang) then return end

    if Player.PlayerData.money.cash >= amount and Player.Functions.RemoveMoney('cash', amount, 'gang-menu-deposit') then
        AddGangMoney(gang, amount)
        log(locale('sv_29'), 'yellow', ('%s %s $%s (%s)'):format(fullName(Player.PlayerData.charinfo), locale('sv_52'), amount, gang))
        notify(src, locale('cl_1'), locale('sv_31') .. ': $' .. amount, 'success')
    else
        notify(src, locale('cl_1'), locale('sv_32'), 'error')
    end
end)

-----------------------------------------------------------------------
-- members
-----------------------------------------------------------------------
lib.callback.register('rsg-gangmenu:server:GetEmployees', function(src)
    local Player = GetBoss(src)
    if not Player then return end
    local gangName = Player.PlayerData.gang.name
    local employees = {}

    local rows = MySQL.query.await("SELECT citizenid, charinfo, gang FROM players WHERE JSON_UNQUOTE(JSON_EXTRACT(gang, '$.name')) = ?", { gangName }) or {}
    for _, row in ipairs(rows) do
        local online = RSGCore.Functions.GetPlayerByCitizenId(row.citizenid)
        local gang = online and online.PlayerData.gang or json.decode(row.gang) or {}
        local charinfo = online and online.PlayerData.charinfo or json.decode(row.charinfo) or {}
        if gang.name == gangName then
            employees[#employees + 1] = {
                citizenid = row.citizenid,
                name = fullName(charinfo),
                gradeName = gang.grade and gang.grade.name or '?',
                gradeLevel = gang.grade and tonumber(gang.grade.level) or 0,
                online = online ~= nil,
                isSelf = row.citizenid == Player.PlayerData.citizenid,
            }
        end
    end
    table.sort(employees, function(a, b)
        if a.gradeLevel ~= b.gradeLevel then return a.gradeLevel > b.gradeLevel end
        return a.name < b.name
    end)
    return employees
end)

-- returns online Player or decoded offline row (with .gang/.charinfo) for a member of gangName
local function GetMember(citizenid, gangName)
    if type(citizenid) ~= 'string' then return end
    local online = RSGCore.Functions.GetPlayerByCitizenId(citizenid)
    if online then
        if online.PlayerData.gang.name ~= gangName then return end
        return online, online.PlayerData.gang, online.PlayerData.charinfo
    end
    local row = MySQL.single.await('SELECT gang, charinfo FROM players WHERE citizenid = ? LIMIT 1', { citizenid })
    if not row then return end
    local gang, charinfo = json.decode(row.gang) or {}, json.decode(row.charinfo) or {}
    if gang.name ~= gangName then return end
    return nil, gang, charinfo
end

RegisterNetEvent('rsg-gangmenu:server:GradeUpdate', function(data)
    local src = source
    local Player = GetBoss(src)
    if not Player or OnCooldown(src) or type(data) ~= 'table' then return end
    local myGang = Player.PlayerData.gang
    local myLevel = tonumber(myGang.grade.level) or 0
    local grade = tonumber(data.grade)
    local gradeInfo = grade and (RSGCore.Shared.Gangs[myGang.name].grades[tostring(grade)] or RSGCore.Shared.Gangs[myGang.name].grades[grade])

    if not gradeInfo then return notify(src, locale('cl_1'), locale('sv_36'), 'error') end
    if data.cid == Player.PlayerData.citizenid or grade > myLevel then return notify(src, locale('cl_1'), locale('sv_33'), 'error') end

    local Employee, gang = GetMember(data.cid, myGang.name)
    if not gang then return notify(src, locale('cl_1'), locale('sv_37'), 'error') end
    if (tonumber(gang.grade and gang.grade.level) or 0) > myLevel then return notify(src, locale('cl_1'), locale('sv_38'), 'error') end

    if not Employee then
        return notify(src, locale('cl_1'), locale('sv_offline'), 'error')
    end
    if Employee.Functions.SetGang(myGang.name, grade) then
        notify(src, locale('cl_1'), locale('sv_34'), 'success')
        notify(Employee.PlayerData.source, locale('cl_1'), locale('sv_35') .. ': ' .. gradeInfo.name, 'inform')
    else
        notify(src, locale('cl_1'), locale('sv_36'), 'error')
    end
end)

RegisterNetEvent('rsg-gangmenu:server:FireMember', function(citizenid)
    local src = source
    local Player = GetBoss(src)
    if not Player or OnCooldown(src) then return end
    local myGang = Player.PlayerData.gang

    if citizenid == Player.PlayerData.citizenid then return notify(src, locale('cl_1'), locale('sv_44'), 'error') end

    local Employee, gang, charinfo = GetMember(citizenid, myGang.name)
    if not gang then return notify(src, locale('cl_1'), locale('sv_37'), 'error') end
    if (tonumber(gang.grade and gang.grade.level) or 0) > (tonumber(myGang.grade.level) or 0) then
        return notify(src, locale('cl_1'), locale('sv_38'), 'error')
    end

    if Employee then
        if not Employee.Functions.SetGang('none', 0) then return notify(src, locale('cl_1'), locale('sv_43'), 'error') end
        notify(Employee.PlayerData.source, locale('cl_1'), locale('sv_42'), 'error')
    else
        local none = { name = 'none', label = 'No Affiliation', isboss = false, grade = { name = 'none', level = 0 } }
        MySQL.update.await('UPDATE players SET gang = ? WHERE citizenid = ?', { json.encode(none), citizenid })
    end

    notify(src, locale('cl_1'), locale('sv_41'), 'success')
    log(locale('sv_39'), 'orange', ('%s %s %s (%s)'):format(fullName(Player.PlayerData.charinfo), locale('sv_40'), fullName(charinfo), myGang.name))
end)

-----------------------------------------------------------------------
-- recruit
-----------------------------------------------------------------------
lib.callback.register('rsg-gangmenu:server:GetNearbyPlayers', function(src)
    if not GetBoss(src) then return end
    local players = {}
    local pCoords = GetEntityCoords(GetPlayerPed(src))
    for _, id in ipairs(RSGCore.Functions.GetPlayers()) do
        if id ~= src and #(pCoords - GetEntityCoords(GetPlayerPed(id))) < Config.HireDistance then
            local Target = RSGCore.Functions.GetPlayer(id)
            if Target then
                players[#players + 1] = { source = id, name = fullName(Target.PlayerData.charinfo), citizenid = Target.PlayerData.citizenid }
            end
        end
    end
    table.sort(players, function(a, b) return a.name < b.name end)
    return players
end)

RegisterNetEvent('rsg-gangmenu:server:HireMember', function(recruit)
    local src = source
    local Player = GetBoss(src)
    recruit = tonumber(recruit)
    if not Player or not recruit or recruit == src or OnCooldown(src) then return end
    local Target = RSGCore.Functions.GetPlayer(recruit)
    if not Target then return notify(src, locale('cl_1'), locale('sv_37'), 'error') end

    local myGang = Player.PlayerData.gang
    if #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(GetPlayerPed(recruit))) > Config.HireDistance then
        return notify(src, locale('cl_1'), locale('sv_too_far'), 'error')
    end
    if Target.PlayerData.gang.name == myGang.name then
        return notify(src, locale('cl_1'), locale('sv_already_member'), 'error')
    end
    if PendingInvites[recruit] then return notify(src, locale('cl_1'), locale('sv_invite_pending'), 'error') end

    PendingInvites[recruit] = true
    notify(src, locale('cl_1'), locale('sv_invite_sent'), 'inform')
    local accepted = lib.callback.await('rsg-gangmenu:client:ConfirmInvite', recruit, myGang.label)
    PendingInvites[recruit] = nil

    -- re-validate after the (async) prompt
    Player, Target = GetBoss(src), RSGCore.Functions.GetPlayer(recruit)
    if not Player or not Target then return end
    if not accepted then return notify(src, locale('cl_1'), locale('sv_invite_declined'), 'error') end

    if Target.Functions.SetGang(myGang.name, 0) then
        local bossName, targetName = fullName(Player.PlayerData.charinfo), fullName(Target.PlayerData.charinfo)
        notify(src, locale('cl_1'), ('%s %s %s'):format(locale('sv_46'), targetName, locale('sv_47') .. ' ' .. myGang.label), 'success')
        notify(recruit, locale('cl_1'), locale('sv_48') .. ' ' .. myGang.label, 'success')
        log(locale('sv_49'), 'yellow', ('%s %s %s (%s)'):format(bossName, locale('sv_50'), targetName, myGang.name))
    end
end)

-----------------------------------------------------------------------
-- admin: /removegang [id]
-----------------------------------------------------------------------
RSGCore.Commands.Add('removegang', locale('sv_admin_usage'), { { name = 'id', help = 'Player ID' } }, true, function(source, args)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(tonumber(args[1]))
    if not Player then return notify(src, locale('sv_43'), locale('sv_admin_error'), 'error') end
    Player.Functions.SetGang('none', 0)
    notify(src, locale('sv_39'), locale('sv_admin_remove'), 'success')
    notify(Player.PlayerData.source, locale('sv_39'), locale('sv_42'), 'inform')
end, 'admin')
