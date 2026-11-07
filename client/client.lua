local RSGCore = exports['rsg-core']:GetCoreObject()

local PlayerGang = {}
local isFromCommand = false
local gangBlips = {}
local promptIds = {}
local uiOpen = false
local invitePending = nil

local function isBoss()
    return PlayerGang and PlayerGang.name and PlayerGang.name ~= 'none' and PlayerGang.isboss
end

local function notify(msg, nType)
    RSGCore.Functions.Notify({
        title = locale('cl_1'),
        description = msg,
        type = nType or 'inform',
        duration = 5000,
    })
end

local function nuiLocales()
    return {
        menu = locale('cl_1'),
        members = locale('cl_2'),
        members_desc = locale('cl_3'),
        hire = locale('cl_4'),
        hire_desc = locale('cl_5'),
        storage = locale('cl_6'),
        storage_desc = locale('cl_7'),
        money = locale('cl_8'),
        money_desc = locale('cl_9'),
        grade = locale('cl_12'),
        set_grade = locale('cl_11'),
        fire = locale('cl_13'),
        fire_confirm = locale('cl_fire_confirm'),
        citizenid = locale('cl_15'),
        id = locale('cl_16'),
        balance = locale('cl_17'),
        deposit = locale('cl_18'),
        deposit_desc = locale('cl_19'),
        withdraw = locale('cl_20'),
        withdraw_desc = locale('cl_21'),
        available = locale('cl_22'),
        no_members = locale('cl_no_members'),
        no_nearby = locale('cl_no_nearby'),
        current = locale('cl_current'),
        invite = locale('cl_invite'),
        confirm = locale('cl_confirm'),
        cancel = locale('cl_cancel'),
        accept = locale('cl_accept'),
    }
end

-------------------------------------------------------------------------------------------
-- NUI bridge
-------------------------------------------------------------------------------------------
local function closeUI()
    if not uiOpen then return end
    uiOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

local function openMain()
    if not isBoss() then
        notify(locale('cl_cmd_error'), 'error')
        return
    end
    uiOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'open',
        locales = nuiLocales(),
        data = {
            title = PlayerGang.label or locale('cl_1'),
            subtitle = isFromCommand and locale('cl_cmd_remote') or '',
            showLocation = not isFromCommand,
        },
    })
end

local function showMembers()
    local result = RSGCore.Functions.AwaitCallback('rsg-gangmenu:server:GetEmployees')
    if not result then return end
    SendNUIMessage({
        action = 'members',
        locales = nuiLocales(),
        data = {
            gangLabel = PlayerGang.label or '',
            members = result,
        },
    })
end

local function showManage(citizenid)
    local result = RSGCore.Functions.AwaitCallback('rsg-gangmenu:server:GetEmployees')
    if not result then return end
    local emp
    for _, v in ipairs(result) do
        if v.citizenid == citizenid then
            emp = v
            break
        end
    end
    if not emp then return end

    local gang = RSGCore.Shared.Gangs[PlayerGang.name]
    if not gang then return end
    local myLevel = PlayerGang.grade and tonumber(PlayerGang.grade.level) or 0
    local levels = {}
    for k in pairs(gang.grades) do
        levels[#levels + 1] = tonumber(k)
    end
    table.sort(levels)

    local grades = {}
    for _, lvl in ipairs(levels) do
        local g = gang.grades[tostring(lvl)] or gang.grades[lvl]
        if g then
            grades[#grades + 1] = {
                level = lvl,
                name = g.name,
                current = lvl == emp.gradeLevel,
                disabled = (lvl == emp.gradeLevel) or (lvl > myLevel),
            }
        end
    end

    SendNUIMessage({
        action = 'manage',
        locales = nuiLocales(),
        data = { employee = emp, grades = grades },
    })
end

local function showHire()
    local players = RSGCore.Functions.AwaitCallback('rsg-gangmenu:server:GetNearbyPlayers') or {}
    SendNUIMessage({
        action = 'hire',
        locales = nuiLocales(),
        data = { players = players },
    })
end

local function showSociety()
    local balance = RSGCore.Functions.AwaitCallback('rsg-gangmenu:server:GetAccount')
    if balance == nil then return end
    local pdata = RSGCore.Functions.GetPlayerData()
    local cash = (pdata.money and pdata.money.cash) or 0
    SendNUIMessage({
        action = 'society',
        locales = nuiLocales(),
        data = {
            balance = balance,
            cash = cash,
            maxTransaction = Config.MaxTransaction,
        },
    })
end

RegisterNUICallback('close', function(_, cb)
    closeUI()
    cb('ok')
end)

RegisterNUICallback('action', function(data, cb)
    cb('ok')
    if type(data) ~= 'table' or type(data.type) ~= 'string' then return end

    if data.type == 'back' then
        -- Always return to main from any sub-view
        openMain()
        return
    end
    if data.type == 'members' then
        showMembers()
        return
    end
    if data.type == 'hire' then
        showHire()
        return
    end
    if data.type == 'hirePlayer' then
        local sid = tonumber(data.source)
        if sid then
            TriggerServerEvent('rsg-gangmenu:server:HireMember', sid)
        end
        return
    end
    if data.type == 'storage' then
        if isFromCommand then return end
        closeUI()
        TriggerServerEvent('rsg-gangmenu:server:openinventory')
        return
    end
    if data.type == 'money' then
        if isFromCommand then return end
        showSociety()
        return
    end
    if data.type == 'manage' and type(data.citizenid) == 'string' then
        showManage(data.citizenid)
        return
    end
    if data.type == 'setGrade' and type(data.citizenid) == 'string' then
        TriggerServerEvent('rsg-gangmenu:server:GradeUpdate', {
            cid = data.citizenid,
            grade = tonumber(data.grade),
        })
        showMembers()
        return
    end
    if data.type == 'fire' and type(data.citizenid) == 'string' then
        TriggerServerEvent('rsg-gangmenu:server:FireMember', data.citizenid)
        showMembers()
        return
    end
    if data.type == 'deposit' then
        local amount = tonumber(data.amount)
        if amount and amount >= 1 then
            TriggerServerEvent('rsg-gangmenu:server:depositMoney', math.floor(amount))
            SetTimeout(400, showSociety)
        end
        return
    end
    if data.type == 'withdraw' then
        local amount = tonumber(data.amount)
        if amount and amount >= 1 then
            TriggerServerEvent('rsg-gangmenu:server:withdrawMoney', math.floor(amount))
            SetTimeout(400, showSociety)
        end
        return
    end
end)

RegisterNUICallback('inviteResult', function(data, cb)
    cb('ok')
    if invitePending then
        invitePending(data and data.accepted == true)
        invitePending = nil
    end
    -- Invite can open focus while the boss UI is closed
    if not uiOpen then
        SetNuiFocus(false, false)
        SendNUIMessage({ action = 'close' })
    end
end)

-------------------------------------------------------------------------------------------
-- blips
-------------------------------------------------------------------------------------------
local function ClearGangBlips()
    for i = 1, #gangBlips do
        if DoesBlipExist(gangBlips[i]) then
            RemoveBlip(gangBlips[i])
        end
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
    local data = RSGCore.Functions.GetPlayerData()
    PlayerGang = (data and data.gang) or {}
    CreateGangBlips()
end

AddEventHandler('onResourceStart', function(resource)
    if resource == GetCurrentResourceName() and LocalPlayer.state.isLoggedIn then
        RefreshGang()
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    closeUI()
    ClearGangBlips()
    for _, id in ipairs(promptIds) do
        pcall(function()
            exports['rsg-core']:deletePrompt(id)
        end)
    end
    promptIds = {}
end)

RegisterNetEvent('RSGCore:Client:OnPlayerLoaded', RefreshGang)

RegisterNetEvent('RSGCore:Client:OnPlayerUnload', function()
    PlayerGang = {}
    ClearGangBlips()
    closeUI()
end)

RegisterNetEvent('RSGCore:Client:OnGangUpdate', function(gangInfo)
    PlayerGang = gangInfo or {}
    CreateGangBlips()
end)

CreateThread(function()
    for _, v in ipairs(Config.GangLocations) do
        if v.id and v.coords then
            exports['rsg-core']:createPrompt(v.id, v.coords, RSGCore.Shared.Keybinds[Config.Keybind], locale('cl_open', v.name), {
                type = 'client',
                event = 'rsg-gangmenu:client:mainmenu',
                args = {},
            })
            promptIds[#promptIds + 1] = v.id
        end
    end
end)

-------------------------------------------------------------------------------------------
-- open menu
-------------------------------------------------------------------------------------------
local function OpenMenu(fromCommand)
    if not isBoss() then
        return notify(locale('cl_cmd_error'), 'error')
    end
    isFromCommand = fromCommand and true or false
    openMain()
end

RegisterNetEvent('rsg-gangmenu:client:mainmenu', function()
    OpenMenu(false)
end)

RegisterCommand('gangmenu', function()
    OpenMenu(true)
end, false)

-------------------------------------------------------------------------------------------
-- recruit invite (server awaits client callback)
-------------------------------------------------------------------------------------------
RSGCore.Functions.CreateClientCallback('rsg-gangmenu:client:ConfirmInvite', function(cb, gangLabel)
    -- Show invite modal even if boss UI is closed
    invitePending = cb
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'invite',
        locales = nuiLocales(),
        gangLabel = gangLabel or '?',
    })
    -- Safety timeout
    SetTimeout(30000, function()
        if invitePending then
            invitePending(false)
            invitePending = nil
            if not uiOpen then
                SetNuiFocus(false, false)
                SendNUIMessage({ action = 'close' })
            end
        end
    end)
end)
