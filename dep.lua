script_name("Combined Script")
script_author("ChatGPT")
script_version("2.4")

require 'moonloader'
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

-- Флаги включения/отключения функций
local CUFF_ENABLED = config.features.cuff_enabled
local DEP_ENABLED = config.features.dep_enabled

-- Глобальная переменная для хранения цели
local LAST_CUFF_TARGET = nil

local version = 1
local update_url = "https://raw.githubusercontent.com/ssouthh/phelp/main/version.json"
local script_path = thisScript().path

function check_updates()
    downloadUrlToFile(update_url, os.getenv("TEMP") .. "\\version.json", function(id, status, p1, p2)
        if status == 6 then
            local f = io.open(os.getenv("TEMP") .. "\\version.json", "r")
            if f then
                local content = f:read("*a")
                f:close()
                os.remove(os.getenv("TEMP") .. "\\version.json")
                local new_version = content:match('"version":%s*(%d+)')
                local download_link = content:match('"download_url":%s*"(.-)"')
                if new_version and tonumber(new_version) > version then
                    sampAddChatMessage("{3fa9f5}[PH] {ffffff}Найдено обновление! Загружаю...", -1)
                    update_script(download_link)
                end
            end
        end
    end)
end

function update_script(link)
    downloadUrlToFile(link, script_path, function(id, status, p1, p2)
        if status == 6 then
            sampAddChatMessage("{3fa9f5}[PH] {ffffff}Скрипт обновлен! Перезагружаю...", -1)
            thisScript():reload()
        end
    end)
end

function main()
    while not isSampAvailable() do wait(100) end
    
    wait(1000)

    check_updates()

    local myId = select(2, sampGetPlayerIdByCharHandle(PLAYER_PED))
    local autoNick = nil
    if myId and myId >= 0 then autoNick = sampGetPlayerNickname(myId) end
    
    -- Логика определения ника
    if config.nickname.manual ~= "" then
        -- Если установлен ручной ник
        MY_NICKNAME = config.nickname.manual
        sampAddChatMessage("{3fa9f5}[PH] {ffffff}Используется ручной ник: {6fc3ff}" .. MY_NICKNAME, -1)
        
        -- Если проверка включена, сохраняем текущий автоматический ник для сравнения
        if config.nickname.check_enabled and autoNick then
            if config.nickname.saved == "" then
                config.nickname.saved = autoNick
                inicfg.save(config, config_name)
                sampAddChatMessage("{3fa9f5}[PH] {ffffff}Автоматический ник сохранён: {6fc3ff}" .. autoNick, -1)
            elseif config.nickname.saved ~= autoNick then
                sampAddChatMessage("{3fa9f5}[PH] {ffff00}Сохранённый ник (" .. config.nickname.saved .. ") не совпадает с текущим (" .. autoNick .. ")", -1)
                config.nickname.saved = autoNick
                inicfg.save(config, config_name)
            end
        end
    elseif autoNick then
        -- Если нет ручного ника, используем автоматический
        MY_NICKNAME = autoNick
        
        if config.nickname.check_enabled then
            if config.nickname.saved == "" then
                config.nickname.saved = MY_NICKNAME
                inicfg.save(config, config_name)
                sampAddChatMessage("{3fa9f5}[PH] {ffffff}Ник сохранён: {6fc3ff}" .. MY_NICKNAME, -1)
            elseif config.nickname.saved ~= MY_NICKNAME then
                sampAddChatMessage("{3fa9f5}[PH] {ffff00}Ник в настройках (" .. config.nickname.saved .. ") не совпадает с текущим (" .. MY_NICKNAME .. "). Обновляю...", -1)
                config.nickname.saved = MY_NICKNAME
                inicfg.save(config, config_name)
            else
                sampAddChatMessage("{3fa9f5}[PH] {ffffff}Используется ник: {6fc3ff}" .. MY_NICKNAME, -1)
            end
        else
            sampAddChatMessage("{3fa9f5}[PH] {ffffff}Проверка ника отключена. Используется: {6fc3ff}" .. MY_NICKNAME, -1)
        end
    end
    
    if not MY_NICKNAME then
        sampAddChatMessage("{3fa9f5}[PH] {ff4d4d}Не удалось получить ваш ник", -1)
        return
    end
    
    tag = config.tag.value ~= "" and config.tag.value or nil
    drawEnabled = config.tag.draw
    ccMode = config.tag.ccmode

    if tag then
        sampAddChatMessage("{3fa9f5}[PH] {ffffff}Текущий тег: {6fc3ff}[" .. tag .. "]", -1)
    else
        sampAddChatMessage("{3fa9f5}[PH] {ff4d4d}Тег не установлен (/stag <тег>)", -1)
    end

    sampAddChatMessage("{3fa9f5}[PH] {ffffff}Отображение HUD: " .. (drawEnabled and "{00ff00}ВКЛ" or "{ff0000}ВЫКЛ"), -1)
    sampAddChatMessage("{3fa9f5}[PH] {ffffff}Режим C.C.: " .. (ccMode and "{00ff00}ВКЛ" or "{ff0000}ВЫКЛ"), -1)
    sampAddChatMessage("{3fa9f5}[PH] {ffffff}Проверка ника: " .. (config.nickname.check_enabled and "{00ff00}ВКЛ" or "{ff0000}ВЫКЛ"), -1)

    if config.nickname.manual ~= "" then
        sampAddChatMessage("{3fa9f5}[PH] {ffffff}Ручной ник: {6fc3ff}" .. config.nickname.manual, -1)
    end
    
    sampAddChatMessage("{3fa9f5}[PH] {ffffff}Авто /gotome: " .. (CUFF_ENABLED and "{00ff00}ВКЛ" or "{ff0000}ВЫКЛ"), -1)
    sampAddChatMessage("{3fa9f5}[PH] {ffffff}Команды департамента: " .. (DEP_ENABLED and "{00ff00}ВКЛ" or "{ff0000}ВЫКЛ"), -1)

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

    font = renderCreateFont("Segoe UI Semibold", 14, FCR_BOLD)

    while true do
        wait(0)
        if drawEnabled and DEP_ENABLED then drawTag() end
    end
end

function sampev.onServerMessage(color, text)
    if not MY_NICKNAME then return end
    
    if not CUFF_ENABLED then return end

    if string.match(text, MY_NICKNAME .. "%s+начал%(а%) сковывать") then
        local target = string.match(text, MY_NICKNAME .. "%s+начал%(а%) сковывать%s+(%S+)")
        if target then
            LAST_CUFF_TARGET = target:gsub(",.*$", "")
        end
        
        lua_thread.create(function()
            wait(250)
            sampSendChat("/me сняв наручники с пояса, надел их на кисти человека")
        end)
    end

    if string.match(text, "^%*%s+" .. MY_NICKNAME .. "%s+перестал%(а%) тащить за собой игрока") then
        lua_thread.create(function()
            wait(100) -- Та самая задержка 100мс
            sampSendChat("/me отпустил цепь наручников")
        end)
    end
    
    if string.match(text, MY_NICKNAME .. "%s+сковал%(а%)") then
        local target = string.match(text, MY_NICKNAME .. "%s+сковал%(а%)%s+(%S+)")
        
        if not target then
            target = string.match(text, MY_NICKNAME .. "%s+сковал%(а%)%s+(.-),")
        end
        
        if not target and LAST_CUFF_TARGET then
            target = LAST_CUFF_TARGET
        end
        
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
    
    if text:find("%[Ошибка%]") and text:find("Вы не в своем авто!") then
        return false
    elseif text:find("Необходимо вставить ключи в зажигание%. Используйте: /key") then
        sampSendChat("/key")
        return false
    elseif text:find(MY_NICKNAME) and text:find("заглушил") and text:find("двигатель") then
        sampSendChat("/key")
    end
end

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
    if arg == nil or arg == "" then
        sampAddChatMessage(tag and "{3fa9f5}[PH] {ffffff}Текущий тег: {6fc3ff}[" .. tag .. "]" or "{3fa9f5}[PH] {ff4d4d}Тег не установлен", -1)
        return
    end
    tag = arg
    config.tag.value = arg
    inicfg.save(config, config_name)
    sampAddChatMessage("{3fa9f5}[PH] {ffffff}Тег сохранён: {6fc3ff}[" .. tag .. "]", -1)
end

function cmdDepartment(arg)
    if not DEP_ENABLED then
        sampAddChatMessage("{3fa9f5}[PH] {ffffff}Команды департамента {ff0000}отключены{ffffff}. Включите через /pdep", -1)
        return
    end
    
    if not tag then
        sampAddChatMessage("{3fa9f5}[PH] {ff4d4d}Сначала задай тег через /stag", -1)
        return
    end
    local dep, message = arg:match("^(%S+)%s+(.+)$")
    if not dep or not message then
        sampAddChatMessage("{3fa9f5}[PH] {ff4d4d}Используй: /dep <департамент> <текст>", -1)
        return
    end
    local chatMessage = ccMode and string.format("/d [%s] »c.c» [%s]: %s", tag, dep, message) or string.format("/d [%s] » [%s]: %s", tag, dep, message)
    sampSendChat(chatMessage)
end

function cmdToggleCC()
    if not DEP_ENABLED then
        sampAddChatMessage("{3fa9f5}[PH] {ffffff}Команды департамента {ff0000}отключены{ffffff}. Включите через /pdep", -1)
        return
    end
    
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
    if not config.nickname.check_enabled and config.nickname.manual ~= "" then
        sampAddChatMessage("{3fa9f5}[PH] {ffffff}Используется ручной ник: {6fc3ff}" .. config.nickname.manual, -1)
    end
end

function cmdSetNick(arg)
    if arg == nil or arg == "" then
        if config.nickname.manual ~= "" then
            sampAddChatMessage("{3fa9f5}[PH] {ffffff}Текущий ручной ник: {6fc3ff}" .. config.nickname.manual, -1)
        else
            sampAddChatMessage("{3fa9f5}[PH] {ff4d4d}Ручной ник не установлен", -1)
        end
        sampAddChatMessage("{3fa9f5}[PH] {ffffff}Используй: /snick <ник> (оставьте пустым для сброса)", -1)
        return
    end
    
    if arg == "clear" or arg == "сброс" then
        config.nickname.manual = ""
        inicfg.save(config, config_name)
        sampAddChatMessage("{3fa9f5}[PH] {ffffff}Ручной ник сброшен. Скрипт будет перезапущен", -1)
        thisScript():reload()
    else
        config.nickname.manual = arg
        inicfg.save(config, config_name)
        sampAddChatMessage("{3fa9f5}[PH] {ffffff}Ручной ник установлен: {6fc3ff}" .. arg, -1)
        sampAddChatMessage("{3fa9f5}[PH] {ffffff}Скрипт будет перезапущен", -1)
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
                    "{3FA9F5}/dep <деп> <текст>{FFFFFF} - Отправить сообщение в департамент\n" ..
                    "{3FA9F5}/depc{FFFFFF} - Переключить режим закрытого канала (C.C.)\n" ..
                    "{3FA9F5}/taghud{FFFFFF} - Включить/выключить HUD\n" ..
                    "{3FA9F5}/cnick {FFFFFF} - Включить/выключить проверку ника\n" ..
                    "{3FA9F5}/snick <ник>{FFFFFF} - Установить ручной ник (clear для сброса)\n" ..
                    "{3FA9F5}/pcuff{FFFFFF} - Включить/выключить функцию сковывания\n" ..
                    "{3FA9F5}/pdep{FFFFFF} - Включить/выключить команды /dep и /depc\n" ..
                    "{3FA9F5}/phelp{FFFFFF} - Показать это окно\n\n" ..
                    "{FFFF00}Текущие настройки:{FFFFFF}\n" ..
                    "Тег: {6fc3ff}[" .. (tag or "не установлен") .. "]{ffffff}\n" ..
                    "HUD: " .. (drawEnabled and "{00FF00}ВКЛ" or "{FF0000}ВЫКЛ") .. "{FFFFFF}\n" ..
                    "C.C.: " .. (ccMode and "{00FF00}ВКЛ" or "{FF0000}ВЫКЛ") .. "{FFFFFF}\n" ..
                    "Проверка ника: " .. (config.nickname.check_enabled and "{00FF00}ВКЛ" or "{FF0000}ВЫКЛ") .. "{FFFFFF}\n" ..
                    "Ручной ник: " .. (config.nickname.manual ~= "" and "{6FC3FF}" .. config.nickname.manual .. "{FFFFFF}" or "{FF0000}не установлен{FFFFFF}") .. "\n" ..
                    "Авто /gotome: " .. (CUFF_ENABLED and "{00FF00}ВКЛ" or "{FF0000}ВЫКЛ") .. "{FFFFFF}\n" ..
                    "Команды департамента: " .. (DEP_ENABLED and "{00FF00}ВКЛ" or "{FF0000}ВЫКЛ") .. "{FFFFFF}\n" ..
                    "Сохранённый ник: " .. (config.nickname.saved ~= "" and "{6FC3FF}" .. config.nickname.saved .. "{FFFFFF}" or "{FF0000}не сохранён{FFFFFF}") .. "\n" ..
                    "Текущий ник: " .. (MY_NICKNAME and "{6FC3FF}" .. MY_NICKNAME .. "{FFFFFF}" or "{FF0000}не определён{FFFFFF}")
    
    sampShowDialog(1000, "Справка по командам", helpText, "Закрыть", "", 0)
end

function sampev.onSendCommand(command)
    local cmd = command:lower()
    
    if cmd:find("^/dep") and not cmd:find("^/depc") then
        if not DEP_ENABLED then
            sampAddChatMessage("{3fa9f5}[PH] {ffffff}Команды департамента {ff0000}отключены{ffffff}. Включите через /pdep", -1)
            return false
        end
        cmdDepartment(command:sub(6))
        return false
        
    elseif cmd:find("^/depc") then
        if not DEP_ENABLED then
            sampAddChatMessage("{3fa9f5}[PH] {ffffff}Команды департамента {ff0000}отключены{ffffff}. Включите через /pdep", -1)
            return false
        end
        cmdToggleCC()
        return false
    end
end