script_name("Combined Script")
script_author("ChatGPT & Gemini")
script_version("2.5")

require 'moonloader'
local requests = require 'requests'
local VERSION = "2.0" -- Текущая версия вашего скрипта
local URL_VERSION = "https://raw.githubusercontent.com/ssouthh/phelp/refs/heads/main/version.json"
local URL_SCRIPT = "https://raw.githubusercontent.com/ssouthh/phelp/refs/heads/main/dep.lua"

local inicfg = require 'inicfg'
local sampev = require 'lib.samp.events'

local COLOR_MAIN = 0xFF3FA9F5
local COLOR_CC_LABEL = 0xFF3FA9F5
local COLOR_CC_STATUS = 0xFF00FF00

local config_name = "phelp"
local default_config = {
    tag = {
        value = "",
        draw = true,
        ccmode = false
    },
    nickname = {
        saved = "",
        check_enabled = true,
        manual = ""
    },
    features = {
        cuff_enabled = true,
        dep_enabled = true
    }
}

local config = inicfg.load(default_config, config_name)
inicfg.save(config, config_name)

local MY_NICKNAME = nil
local tag = nil
local font = nil
local drawEnabled = true
local ccMode = false
local BASE_X, BASE_Y = 1920, 1080
local BASE_POS_X, BASE_POS_Y = 332, 750

-- Переменные для испытательного срока
local last_srok = {day = 0, month = 0, year = 0, hour = 0, min = 0, sec = 0}
local srok_captured = false

-- Флаги включения/отключения функций
local CUFF_ENABLED = config.features.cuff_enabled
local DEP_ENABLED = config.features.dep_enabled

-- Глобальная переменная для хранения цели
local LAST_CUFF_TARGET = nil
local INVITE_TARGET_ID = nil
local INVITE_TIMER = 0 -- Добавьте эту строку

function checkUpdate()
    lua_thread.create(function()
        try {
            function()
                local response = requests.get(URL_VERSION)
                if response.status_code == 200 then
                    local json = response.json()
                    if json and json.version > VERSION then
                        sampAddChatMessage("{3fa9f5}[PH] {ffffff}Найдено обновление! Скрипт обновляется с версии {ff4d4d}" .. VERSION .. " {ffffff}до {00ff00}" .. json.version, -1)
                        
                        local res = requests.get(URL_SCRIPT)
                        if res.status_code == 200 then
                            local file = io.open(thisScript().path, "wb")
                            file:write(res.text)
                            file:close()
                            sampAddChatMessage("{3fa9f5}[PH] {ffffff}Обновление завершено! Перезагрузка...", -1)
                            thisScript():reload()
                        end
                    end
                end
            end,
            catch {
                function(error)
                    print("[PH] Ошибка обновления: " .. error)
                end
            }
        }
    end)
end

function main()
    while not isSampAvailable() do wait(100) end
    checkUpdate() -- Запуск проверки при старте
    
    wait(1000)
    local myId = select(2, sampGetPlayerIdByCharHandle(PLAYER_PED))
    local autoNick = nil
    if myId and myId >= 0 then autoNick = sampGetPlayerNickname(myId) end
    
    -- Логика определения ника
    if config.nickname.manual ~= "" then
        MY_NICKNAME = config.nickname.manual
        sampAddChatMessage("{3fa9f5}[PH] {ffffff}Используется ручной ник: {6fc3ff}" .. MY_NICKNAME, -1)
        if config.nickname.check_enabled and autoNick then
            if config.nickname.saved == "" then
                config.nickname.saved = autoNick
                inicfg.save(config, config_name)
            elseif config.nickname.saved ~= autoNick then
                config.nickname.saved = autoNick
                inicfg.save(config, config_name)
            end
        end
    elseif autoNick then
        MY_NICKNAME = autoNick
    end
    
    tag = config.tag.value ~= "" and config.tag.value or nil
    drawEnabled = config.tag.draw
    ccMode = config.tag.ccmode

    -- Регистрация команд
    sampRegisterChatCommand("stag", cmdSetTag)
    sampRegisterChatCommand("dep", cmdDepartment)
    sampRegisterChatCommand("depc", cmdToggleCC)
    sampRegisterChatCommand("taghud", cmdToggleHud)
    sampRegisterChatCommand("cnick", cmdNickCheck)
    sampRegisterChatCommand("snick", cmdSetNick)
    sampRegisterChatCommand("phelp", cmdPHelp)
    sampRegisterChatCommand("pcuff", cmdToggleCuff)
    sampRegisterChatCommand("pdep", cmdToggleDep)
    sampRegisterChatCommand("sk", cmdSrok)
    sampRegisterChatCommand("invzv", cmdInviteZv)

    font = renderCreateFont("Segoe UI Semibold", 14, FCR_BOLD)

    while true do
        wait(0)
        if drawEnabled and DEP_ENABLED then drawTag() end
    end
end

-- ==========================================================
-- ОБРАБОТКА ИСПЫТАТЕЛЬНОГО СРОКА
-- ==========================================================

function cmdSrok(arg)
    if not srok_captured then
        sampAddChatMessage("{3fa9f5}[PH] {ff4d4d}Ошибка: {ffffff}Сначала откройте диалог со статистикой!", -1)
        return
    end

    local hours = tonumber(arg)
    if not hours then
        sampAddChatMessage("{3fa9f5}[PH] {ffffff}Используй: {6fc3ff}/sk [часы]", -1)
        return
    end

    local old_time = os.time({
        day = last_srok.day, month = last_srok.month, year = last_srok.year,
        hour = last_srok.hour, min = last_srok.min, sec = last_srok.sec
    })

    local new_time = old_time + (hours * 3600)
    local result = os.date("%d.%m.%Y %H:%M:%S", new_time)

    sampAddChatMessage("{3fa9f5}[PH] {ffffff}Исп. срок ("..hours.."ч) истекает: {00ff00}"..result, -1)
end

function cmdInviteZv(arg)
    local id = tonumber(arg)
    if not id or not sampIsPlayerConnected(id) then
        sampAddChatMessage("{3fa9f5}[PH] {ffffff}Используй: {6fc3ff}/invzv [ID]", -1)
        return
    end

    lua_thread.create(function()
        sampSendChat("/me снял с пояса связку ключей, после чего достал один ключ от раздевалки из связки")
        wait(1500)
        sampSendChat("/todo Удачной работы*протягивая ключ от раздевалки человеку")
        wait(500)
        sampSendChat("/invite " .. id)
        
        INVITE_TARGET_ID = id
        INVITE_TIMER = os.time() -- Запоминаем время ввода команды
    end)
end

-- ==========================================================
-- СОБЫТИЯ
-- ==========================================================

function sampev.onShowDialog(id, style, title, button1, button2, text)
    if id == 0 then
        local pattern = "Последнее повышение:.-(%d%d)%.(%d%d)%.(%d%d%d%d)%s+(%d%d):(%d%d):(%d%d)"
        local d, m, y, hh, mm, ss = text:match(pattern)
        
        if d and m and y then
            last_srok = {day = tonumber(d), month = tonumber(m), year = tonumber(y), hour = tonumber(hh), min = tonumber(mm), sec = tonumber(ss)}
            srok_captured = true
            -- Теперь выводит и дату, и время
            sampAddChatMessage("{3fa9f5}[PH] {ffffff}Дата последнего повышения захвачена: {6fc3ff}"..d.."."..m.."."..y.." "..hh..":"..mm..":"..ss, -1)
        end
    end
end

function sampev.onServerMessage(color, text)
    if not MY_NICKNAME then return end
    if not CUFF_ENABLED then return end

    if string.match(text, MY_NICKNAME .. "%s+начал%(а%) сковывать") then
        local target = string.match(text, MY_NICKNAME .. "%s+начал%(а%) сковывать%s+(%S+)")
        if target then LAST_CUFF_TARGET = target:gsub(",.*$", "") end
        lua_thread.create(function()
            wait(250)
            sampSendChat("/me сняв наручники с пояса, надел их на кисти человека")
        end)
    end

    if string.match(text, "^%*%s+" .. MY_NICKNAME .. "%s+перестал%(а%) тащить за собой игрока") then
        lua_thread.create(function()
            wait(100)
            sampSendChat("/me отпустил цепь наручников")
        end)
    end
    
    if string.match(text, MY_NICKNAME .. "%s+сковал%(а%)") then
        local target = string.match(text, MY_NICKNAME .. "%s+сковал%(а%)%s+(%S+)")
        if not target then target = string.match(text, MY_NICKNAME .. "%s+сковал%(а%)%s+(.-),") end
        if not target and LAST_CUFF_TARGET then target = LAST_CUFF_TARGET end
        if target then
            target = target:gsub("[,%.]*$", "")
            lua_thread.create(function()
                wait(100)
                sampSendChat("/gotome " .. target)
                wait(1000)
                sampSendChat("/me схватив человека за цепь наручников, ведет его перед собой")
            end)
            LAST_CUFF_TARGET = nil
        end
    end

-- 1. Очистка текста от цветов
    local cleanText = text:gsub("{%x+}", "")
    
    -- 2. Поиск системной строки о принятии предложения
    -- Паттерн вырезает ник принявшего игрока: (.+)
    local name = cleanText:match("%[Информация%] (.+) принял ваше предложение вступить к вам в организацию%.")
    
    if name then
        local targetName = "Unknown"
        if INVITE_TARGET_ID and sampIsPlayerConnected(INVITE_TARGET_ID) then
            targetName = sampGetPlayerNickname(INVITE_TARGET_ID)
        end
        if INVITE_TARGET_ID and name == targetName and (os.time() - INVITE_TIMER) <= 60 then
            lua_thread.create(function()
                wait(500)
                sampSendChat("/me достав телефон из правого кармана брюк, зашел в базу сотрудников")
                wait(1500)
                sampSendChat("/me найдя нужного сотрудника, изменил о нем информацию, и вышел с базы")
                wait(1500)
                sampSendChat("/me убрал телефон в правый карман брюк")
                wait(500)
                sampSendChat(string.format("/giverank %d 4", INVITE_TARGET_ID))
                wait(500)
                sampSendChat(string.format("/settag %d PD", INVITE_TARGET_ID))
                sampAddChatMessage("{3fa9f5}[PH] {ffffff}Игрок {6fc3ff}"..name.."{ffffff} принят на 4 ранг с тегом PD.", -1)
                INVITE_TARGET_ID = nil
                INVITE_TIMER = 0
            end)
        end
    end
    
    if text:find("%[Ошибка%]") and text:find("Вы не в своем авто!") then
        return false
    elseif text:find("Необходимо вставить ключи в зажигание%. Используйте: /key") then
        sampSendChat("/key")
        return false
    elseif text:find(MY_NICKNAME) and text:find("заглушил") and text:find("двигатель") then
        sampSendChat("/key")
    end
end

-- ==========================================================
-- ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ И КОМАНДЫ
-- ==========================================================

function drawTag()
    if not tag then return end
    local sx, sy = getScreenResolution()
    local x = BASE_POS_X * (sx / BASE_X)
    local y = BASE_POS_Y * (sy / BASE_Y)
    local shadow = 0xFF000000
    local tagText = "TAG: " .. string.upper(tag)
    
    renderFontDrawText(font, tagText, x + 1, y + 1, shadow)
    renderFontDrawText(font, tagText, x - 1, y + 1, shadow)
    renderFontDrawText(font, tagText, x + 1, y - 1, shadow)
    renderFontDrawText(font, tagText, x - 1, y - 1, shadow)
    renderFontDrawText(font, tagText, x, y, COLOR_MAIN)
    
    if ccMode then
        local ccY = y + 20
        local ccLabel = "CC: "
        local ccLabelWidth = renderGetFontDrawTextLength(font, ccLabel, true)
        local ccStatus = "Enable"
        local fullCcText = ccLabel .. ccStatus
        renderFontDrawText(font, fullCcText, x + 1, ccY + 1, shadow)
        renderFontDrawText(font, fullCcText, x - 1, ccY + 1, shadow)
        renderFontDrawText(font, fullCcText, x + 1, ccY - 1, shadow)
        renderFontDrawText(font, fullCcText, x - 1, ccY - 1, shadow)
        renderFontDrawText(font, ccLabel, x, ccY, COLOR_CC_LABEL)
        renderFontDrawText(font, ccStatus, x + ccLabelWidth, ccY, COLOR_CC_STATUS)
    end
end

function cmdSetTag(arg)
    if arg == nil or arg == "" then return end
    tag = arg
    config.tag.value = arg
    inicfg.save(config, config_name)
    sampAddChatMessage("{3fa9f5}[PH] {ffffff}Тег сохранён: {6fc3ff}[" .. tag .. "]", -1)
end

function cmdDepartment(arg)
    if not DEP_ENABLED then return end
    if not tag then
        sampAddChatMessage("{3fa9f5}[PH] {ff4d4d}Сначала задай тег через /stag", -1)
        return
    end
    local dep, message = arg:match("^(%S+)%s+(.+)$")
    if not dep or not message then return end
    local chatMessage = ccMode and string.format("/d [%s] »c.c» [%s]: %s", tag, dep, message) or string.format("/d [%s] » [%s]: %s", tag, dep, message)
    sampSendChat(chatMessage)
end

function cmdToggleCC()
    ccMode = not ccMode
    config.tag.ccmode = ccMode
    inicfg.save(config, config_name)
    sampAddChatMessage(ccMode and "{3fa9f5}[PH] {ffffff}Режим закрытого канала {00ff00}включен" or "{3fa9f5}[PH] {ffffff}Режим закрытого канала {ff0000}выключен", -1)
end

function cmdToggleHud()
    drawEnabled = not drawEnabled
    config.tag.draw = drawEnabled
    inicfg.save(config, config_name)
    sampAddChatMessage("{3fa9f5}[PH] {ffffff}HUD: " .. (drawEnabled and "{6fc3ff}ВКЛЮЧЁН" or "{ff4d4d}ВЫКЛЮЧЕН"), -1)
end

function cmdNickCheck()
    config.nickname.check_enabled = not config.nickname.check_enabled
    inicfg.save(config, config_name)
    sampAddChatMessage("{3fa9f5}[PH] {ffffff}Проверка ника " .. (config.nickname.check_enabled and "{00ff00}включена" or "{ff0000}выключена"), -1)
end

function cmdSetNick(arg)
    if arg == "clear" then
        config.nickname.manual = ""
        inicfg.save(config, config_name)
        thisScript():reload()
    else
        config.nickname.manual = arg
        inicfg.save(config, config_name)
        thisScript():reload()
    end
end

function cmdToggleCuff()
    CUFF_ENABLED = not CUFF_ENABLED
    config.features.cuff_enabled = CUFF_ENABLED
    inicfg.save(config, config_name)
    sampAddChatMessage("{3fa9f5}[PH] {ffffff}Авто /gotome: " .. (CUFF_ENABLED and "{00ff00}включено" or "{ff0000}выключено"), -1)
end

function cmdToggleDep()
    DEP_ENABLED = not DEP_ENABLED
    config.features.dep_enabled = DEP_ENABLED
    inicfg.save(config, config_name)
    sampAddChatMessage("{3fa9f5}[PH] {ffffff}Команды департамента: " .. (DEP_ENABLED and "{00ff00}включены" or "{ff0000}выключены"), -1)
end

function cmdPHelp()
    local helpText = "Команды скрипта:\n\n" ..
                    "{3FA9F5}/stag <тег>{FFFFFF} - Установить тег департамента\n" ..
                    "{3FA9F5}/dep <деп> <текст>{FFFFFF} - Сообщение в департамент\n" ..
                    "{3FA9F5}/depc{FFFFFF} - Режим закрытого канала (C.C.)\n" ..
                    "{3FA9F5}/taghud{FFFFFF} - Включить/выключить HUD\n" ..
                    "{3FA9F5}/sk <часы>{FFFFFF} - Расчет исп. срока (нужно открыть диалог 0)\n" ..
                    "{3FA9F5}/cnick {FFFFFF} - Включить/выключить проверку ника\n" ..
                    "{3FA9F5}/snick <ник>{FFFFFF} - Ручной ник (clear для сброса)\n" ..
                    "{3FA9F5}/pcuff{FFFFFF} - Включить/выключить авто /gotome\n" ..
                    "{3FA9F5}/pdep{FFFFFF} - Включить/выключить функции депа\n" ..
                    "{3FA9F5}/invzv <ID>{FFFFFF} - Принять по заявлению\n" ..
                    "{3FA9F5}/phelp{FFFFFF} - Это окно"
                    
    
    sampShowDialog(1000, "Справка по командам", helpText, "Закрыть", "", 0)
end

function sampev.onSendCommand(command)
    local cmd = command:lower()
    if cmd:find("^/dep") and not cmd:find("^/depc") then
        if not DEP_ENABLED then return false end
        cmdDepartment(command:sub(6))
        return false
    elseif cmd:find("^/depc") then
        cmdToggleCC()
        return false
    end
end