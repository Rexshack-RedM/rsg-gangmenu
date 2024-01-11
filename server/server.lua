local RSGCore = exports['rsg-core']:GetCoreObject()
local GangAccounts = {}

-----------------------------------------------------------------------
-- version checker
-----------------------------------------------------------------------
local function versionCheckPrint(_type, log)
    local color = _type == 'success' and '^2' or '^1'

    print(('^5['..GetCurrentResourceName()..']%s %s^7'):format(color, log))
end

local function CheckVersion()
    PerformHttpRequest('https://raw.githubusercontent.com/Rexshack-RedM/rsg-gangmenu/main/version.txt', function(err, text, headers)
        local currentVersion = GetResourceMetadata(GetCurrentResourceName(), 'version')

        if not text then 
            versionCheckPrint('error', 'Currently unable to run a version check.')
            return 
        end

        --versionCheckPrint('success', ('Current Version: %s'):format(currentVersion))
        --versionCheckPrint('success', ('Latest Version: %s'):format(text))
        
        if text == currentVersion then
            versionCheckPrint('success', 'You are running the latest version.')
        else
            versionCheckPrint('error', ('You are currently running an outdated version, please update to version %s'):format(text))
        end
    end)
end

-----------------------------------------------------------------------
-- functions
-----------------------------------------------------------------------
function GetGangAccount(account)
    return GangAccounts[account] or 0
end

function AddGangMoney(account, amount)
    if not GangAccounts[account] then
        GangAccounts[account] = 0
    end

    GangAccounts[account] = GangAccounts[account] + amount
    MySQL.insert('INSERT INTO management_funds (job_name, amount, type) VALUES (:job_name, :amount, :type) ON DUPLICATE KEY UPDATE amount = :amount',
        {
            ['job_name'] = account,
            ['amount'] = GangAccounts[account],
            ['type'] = 'gang'
        })
end

function RemoveGangMoney(account, amount)
    local isRemoved = false
    if amount > 0 then
        if not GangAccounts[account] then
            GangAccounts[account] = 0
        end

        if GangAccounts[account] >= amount then
            GangAccounts[account] = GangAccounts[account] - amount
            isRemoved = true
        end

        MySQL.update('UPDATE management_funds SET amount = ? WHERE job_name = ? and type = "gang"', { GangAccounts[account], account })
    end
    return isRemoved
end

-----------------------------------------------------------------------
-- sql
-----------------------------------------------------------------------
MySQL.ready(function ()
    local gangmenu = MySQL.query.await('SELECT job_name,amount FROM management_funds WHERE type = "gang"', {})
    if not gangmenu then return end

    for _,v in ipairs(gangmenu) do
        GangAccounts[v.job_name] = v.amount
    end
end)

-----------------------------------------------------------------------
-- money
-----------------------------------------------------------------------
RegisterNetEvent("rsg-gangmenu:server:withdrawMoney", function(amount)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)

    if not Player.PlayerData.gang.isboss then return end

    local gang = Player.PlayerData.gang.name
    if RemoveGangMoney(gang, amount) then
        Player.Functions.AddMoney("cash", amount, Lang:t('lang_24'))
        TriggerEvent('rsg-log:server:CreateLog', 'gangmenu', Lang:t('lang_25'), 'yellow', Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname .. Lang:t('lang_51') .. amount .. ' (' .. gang .. ')', false)
        TriggerClientEvent('ox_lib:notify', src, {title = Lang:t('lang_27') ..amount, type = 'inform', duration = 5000 })
    else
        TriggerClientEvent('ox_lib:notify', src, {title = Lang:t('lang_28'), type = 'error', duration = 5000 })
    end
end)

RegisterNetEvent("rsg-gangmenu:server:depositMoney", function(amount)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)

    if not Player.PlayerData.gang.isboss then return end

    if Player.Functions.RemoveMoney("cash", amount) then
        local gang = Player.PlayerData.gang.name
        AddGangMoney(gang, amount)
        TriggerEvent('rsg-log:server:CreateLog', 'gangmenu', Lang:t('lang_29'), 'yellow', Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname .. Lang:t('lang_52') .. amount .. ' (' .. gang .. ')', false)
        TriggerClientEvent('ox_lib:notify', src, {title = Lang:t('lang_31') ..amount, type = 'inform', duration = 5000 })
    else
        TriggerClientEvent('ox_lib:notify', src, {title = Lang:t('lang_32'), type = 'error', duration = 5000 })
    end
end)

RSGCore.Functions.CreateCallback('rsg-gangmenu:server:GetAccount', function(_, cb, GangName)
    local gangmoney = GetGangAccount(GangName)
    cb(gangmoney)
end)

-----------------------------------------------------------------------
-- Get Employees
-----------------------------------------------------------------------
RSGCore.Functions.CreateCallback('rsg-gangmenu:server:GetEmployees', function(source, cb, gangname)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)

    if not Player.PlayerData.gang.isboss then return end

    local employees = {}
    local players = MySQL.query.await("SELECT * FROM `players` WHERE `gang` LIKE '%".. gangname .."%'", {})
    if players[1] ~= nil then
        for _, value in pairs(players) do
            local isOnline = RSGCore.Functions.GetPlayerByCitizenId(value.citizenid)

            if isOnline then
                employees[#employees+1] = {
                empSource = isOnline.PlayerData.citizenid,
                grade = isOnline.PlayerData.gang.grade,
                isboss = isOnline.PlayerData.gang.isboss,
                name = '🟢' .. isOnline.PlayerData.charinfo.firstname .. ' ' .. isOnline.PlayerData.charinfo.lastname
                }
            else
                employees[#employees+1] = {
                empSource = value.citizenid,
                grade =  json.decode(value.gang).grade,
                isboss = json.decode(value.gang).isboss,
                name = '❌' ..  json.decode(value.charinfo).firstname .. ' ' .. json.decode(value.charinfo).lastname
                }
            end
        end
    end
    cb(employees)
end)

-----------------------------------------------------------------------
-- Grade Change
-----------------------------------------------------------------------
RegisterNetEvent('rsg-gangmenu:server:GradeUpdate', function(data)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    local Employee = RSGCore.Functions.GetPlayerByCitizenId(data.cid)

    if not Player.PlayerData.gang.isboss then return end
    if data.grade > Player.PlayerData.gang.grade.level then TriggerClientEvent('ox_lib:notify', src, {title = "You cannot promote to this rank!", type = 'error', duration = 5000 }) return end

    if Employee then
        if Employee.Functions.SetGang(Player.PlayerData.gang.name, data.grade) then
            TriggerClientEvent('ox_lib:notify', src, {title = Lang:t('lang_34'), type = 'inform', duration = 5000 })
            TriggerClientEvent('ox_lib:notify', Employee.PlayerData.source, {title = Lang:t('lang_35')..data.gradename..".", type = 'inform', duration = 5000 })
        else
            TriggerClientEvent('ox_lib:notify', src, {title = Lang:t('lang_36'), type = 'error', duration = 5000 })
        end
    else
        TriggerClientEvent('ox_lib:notify', src, {title = Lang:t('lang_37'), type = 'error', duration = 5000 })
    end
end)

-----------------------------------------------------------------------
-- Fire Member
-----------------------------------------------------------------------
RegisterNetEvent('rsg-gangmenu:server:FireMember', function(target)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    local Employee = RSGCore.Functions.GetPlayerByCitizenId(target)

    if not Player.PlayerData.gang.isboss then return end

    if Employee then
        if target ~= Player.PlayerData.citizenid then
            if Employee.PlayerData.gang.grade.level > Player.PlayerData.gang.grade.level then TriggerClientEvent('ox_lib:notify', src, {title = Lang:t('lang_38'), type = 'error', duration = 5000 }) return end
            if Employee.Functions.SetGang("none", '0') then
                TriggerEvent("rsg-log:server:CreateLog", "gangmenu", Lang:t('lang_39'), "orange", Player.PlayerData.charinfo.firstname .. " " .. Player.PlayerData.charinfo.lastname .. Lang:t('lang_40') .. Employee.PlayerData.charinfo.firstname .. " " .. Employee.PlayerData.charinfo.lastname .. " (" .. Player.PlayerData.gang.name .. ")", false)
                TriggerClientEvent('ox_lib:notify', src, {title = Lang:t('lang_41'), type = 'inform', duration = 5000 })
                TriggerClientEvent('ox_lib:notify', Employee.PlayerData.source, {title = Lang:t('lang_42'), type = 'error', duration = 5000 })
            else
                TriggerClientEvent('ox_lib:notify', src, {title = Lang:t('lang_43'), type = 'error', duration = 5000 })
            end
        else
            TriggerClientEvent('ox_lib:notify', src, {title = Lang:t('lang_44'), type = 'error', duration = 5000 })
        end
    else
        local player = MySQL.query.await('SELECT * FROM players WHERE citizenid = ? LIMIT 1', {target})
        if player[1] ~= nil then
            Employee = player[1]
            Employee.gang = json.decode(Employee.gang)
            if Employee.gang.grade.level > Player.PlayerData.job.grade.level then TriggerClientEvent('ox_lib:notify', src, {title = "You cannot fire this citizen!", type = 'error', duration = 5000 }) return end
            local gang = {}
            gang.name = "none"
            gang.label = "No Affiliation"
            gang.payment = 0
            gang.onduty = true
            gang.isboss = false
            gang.grade = {}
            gang.grade.name = nil
            gang.grade.level = 0
            MySQL.update('UPDATE players SET gang = ? WHERE citizenid = ?', {json.encode(gang), target})
            TriggerClientEvent('ox_lib:notify', src, {title = "Gang member fired!", type = 'inform', duration = 5000 })
            TriggerEvent("rsg-log:server:CreateLog", "gangmenu", Lang:t('lang_39'), "orange", Player.PlayerData.charinfo.firstname .. " " .. Player.PlayerData.charinfo.lastname .. Lang:t('lang_40') .. Employee.PlayerData.charinfo.firstname .. " " .. Employee.PlayerData.charinfo.lastname .. " (" .. Player.PlayerData.gang.name .. ")", false)
        else
            TriggerClientEvent('ox_lib:notify', src, {title = Lang:t('lang_37'), type = 'error', duration = 5000 })
        end
    end
end)

-----------------------------------------------------------------------
-- Recruit Player
-----------------------------------------------------------------------
RegisterNetEvent('rsg-gangmenu:server:HireMember', function(recruit)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    local Target = RSGCore.Functions.GetPlayer(recruit)

    if not Player.PlayerData.gang.isboss then return end

    if Target and Target.Functions.SetGang(Player.PlayerData.gang.name, 0) then
        TriggerClientEvent('ox_lib:notify', src, {title = Lang:t('lang_46') .. (Target.PlayerData.charinfo.firstname .. ' ' .. Target.PlayerData.charinfo.lastname) .. Lang:t('lang_47') .. Player.PlayerData.gang.label .. "", type = 'inform', duration = 5000 })
        TriggerClientEvent('ox_lib:notify', Target.PlayerData.source, {title = Lang:t('lang_48') .. Player.PlayerData.gang.label .. "", type = 'inform', duration = 5000 })
        TriggerEvent('rsg-log:server:CreateLog', 'gangmenu', Lang:t('lang_49'), 'yellow', (Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname).. Lang:t('lang_50') .. Target.PlayerData.charinfo.firstname .. ' ' .. Target.PlayerData.charinfo.lastname .. ' (' .. Player.PlayerData.gang.name .. ')', false)
    end
end)

-----------------------------------------------------------------------
-- Get closest player sv
-----------------------------------------------------------------------
RSGCore.Functions.CreateCallback('rsg-gangmenu:getplayers', function(source, cb)
    local src = source
    local players = {}
    local PlayerPed = GetPlayerPed(src)
    local pCoords = GetEntityCoords(PlayerPed)
    for _, v in pairs(RSGCore.Functions.GetPlayers()) do
        local targetped = GetPlayerPed(v)
        local tCoords = GetEntityCoords(targetped)
        local dist = #(pCoords - tCoords)
        if PlayerPed ~= targetped and dist < 10 then
            local ped = RSGCore.Functions.GetPlayer(v)
            players[#players+1] = {
            id = v,
            coords = GetEntityCoords(targetped),
            name = ped.PlayerData.charinfo.firstname .. " " .. ped.PlayerData.charinfo.lastname,
            citizenid = ped.PlayerData.citizenid,
            sources = GetPlayerPed(ped.PlayerData.source),
            sourceplayer = ped.PlayerData.source
            }
        end
    end
        table.sort(players, function(a, b)
            return a.name < b.name
        end)
    cb(players)
end)

--------------------------------------------------------------------------------------------------
-- start version check
--------------------------------------------------------------------------------------------------
CheckVersion()
