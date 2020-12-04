--[[
    This is the network recovery system!

    It has been moved out of the EFI itself, and instead, it is downloaded when needed!
]]

local video = {}
do
    local screen = component.list("screen")()
    local gpu = component.list("gpu")()

    if (not screen) and (not gpu) then
        states.supports.video = false
        return
    end

    if screen and gpu then
        boot_invoke(gpu, "bind", screen)
        states.supports.video = true
    end

    local _screen = component.proxy(screen)
    local _gpu = component.proxy(gpu)

    video["data"] = {x = 1, y = 1}

    video.clearScreen = function()
        local width, height = _gpu.getResolution()
        gpu.setForeground(0x000000)
        gpu.setBackground(0xFFFFFF)
        _gpu.fill(1, 1, width, height, "")
    end

    video.print = function(...)
        -- @TODO implement video scrolling!
        local width, height = _gpu.getResolution()

        local text = (table.concat({...}, "")) or ""
        local strlen = string.len(text)

        for charnum = 1, strlen, 1 do
            local char = string.sub(text, charnum, charnum)

            _gpu.set(video["data"]["x"], video["data"]["y"], string.sub(text, charnum, charnum))
            video["data"]["x"] = video["data"]["x"] + 1

            -- Run cursor checks
            do
                if video["data"]["x"] > width then
                    video["data"]["x"] = 1
                    video["data"]["y"] = video["data"]["y"] + 1
                end

                if video["data"]["y"] > height then
                    video.clearScreen()
                    video["data"]["x"] = 1
                    video["data"]["y"] = 1
                end
            end
        end
    end

    video.println = function(...)
        local text = {...}
        table.insert(text, "\n")
        video.print(table.unpack(text))
    end
end

local getKeysPressed
local getKeysPressedMin
do
    
    local symbol_list = {
        ["1"] = 0x02,
        ["2"] = 0x03,
        ["3"] = 0x04,
        ["4"] = 0x05,
        ["5"] = 0x06,
        ["6"] = 0x07,
        ["7"] = 0x08,
        ["8"] = 0x09,
        ["9"] = 0x0A,
        ["0"] = 0x0B,
        ["a"] = 0x1E,
        ["b"] = 0x30,
        ["c"] = 0x2E,
        ["d"] = 0x20,
        ["e"] = 0x12,
        ["f"] = 0x21,
        ["g"] = 0x22,
        ["h"] = 0x23,
        ["i"] = 0x17,
        ["j"] = 0x24,
        ["k"] = 0x25,
        ["l"] = 0x26,
        ["m"] = 0x32,
        ["n"] = 0x31,
        ["o"] = 0x18,
        ["p"] = 0x19,
        ["q"] = 0x10,
        ["r"] = 0x13,
        ["s"] = 0x1F,
        ["t"] = 0x14,
        ["u"] = 0x16,
        ["v"] = 0x2F,
        ["w"] = 0x11,
        ["x"] = 0x2D,
        ["y"] = 0x15,
        ["z"] = 0x2C,
        ["apostrophe"] = 0x28,
        ["at"] = 0x91,
        ["back"] = 0x0E ,
        ["backslash"] = 0x2B,
        ["capital"] = 0x3A ,
        ["colon"] = 0x92,
        ["comma"] = 0x33,
        ["enter"] = 0x1C,
        ["equals"] = 0x0D,
        ["grave"] = 0x29 ,
        ["lbracket"] = 0x1A,
        ["lcontrol"] = 0x1D,
        ["lmenu"] = 0x38 ,
        ["lshift"] = 0x2A,
        ["minus"] = 0x0C,
        ["numlock"] = 0x45,
        ["pause"] = 0xC5,
        ["period"] = 0x34,
        ["rbracket"] = 0x1B,
        ["rcontrol"] = 0x9D,
        ["rmenu"] = 0xB8 ,
        ["rshift"] = 0x36,
        ["scroll"] = 0x46 ,
        ["semicolon"] = 0x27,
        ["slash"] = 0x35 ,
        ["space"] = 0x39,
        ["stop"] = 0x95,
        ["tab"] = 0x0F,
        ["underline"] = 0x93,
        ["up"] = 0xC8,
        ["down"] = 0xD0,
        ["left"] = 0xCB,
        ["right"] = 0xCD,
        ["home"] = 0xC7,
        ["end"] = 0xCF,
        ["pageUp"] = 0xC9,
        ["pageDown"] = 0xD1,
        ["insert"] = 0xD2,
        ["delete"] = 0xD3,
        ["f1"] = 0x3B,
        ["f2"] = 0x3C,
        ["f3"] = 0x3D,
        ["f4"] = 0x3E,
        ["f5"] = 0x3F,
        ["f6"] = 0x40,
        ["f7"] = 0x41,
        ["f8"] = 0x42,
        ["f9"] = 0x43,
        ["f10"] = 0x44,
        ["f11"] = 0x57,
        ["f12"] = 0x58,
        ["f13"] = 0x64,
        ["f14"] = 0x65,
        ["f15"] = 0x66,
        ["f16"] = 0x67,
        ["f17"] = 0x68,
        ["f18"] = 0x69,
        ["f19"] = 0x71,
        ["kana"] = 0x70,
        ["kanji"] = 0x94,
        ["convert"] = 0x79,
        ["noconvert"] = 0x7B,
        ["yen"] = 0x7D,
        ["circumflex"] = 0x90,
        ["ax"] = 0x96,
        ["numpad0"] = 0x52,
        ["numpad1"] = 0x4F,
        ["numpad2"] = 0x50,
        ["numpad3"] = 0x51,
        ["numpad4"] = 0x4B,
        ["numpad5"] = 0x4C,
        ["numpad6"] = 0x4D,
        ["numpad7"] = 0x47,
        ["numpad8"] = 0x48,
        ["numpad9"] = 0x49,
        ["numpadmul"] = 0x37,
        ["numpaddiv"] = 0xB5,
        ["numpadsub"] = 0x4A,
        ["numpadadd"] = 0x4E,
        ["numpaddecimal"] = 0x53,
        ["numpadcomma"] = 0xB3,
        ["numpadenter"] = 0x9C,
        ["numpadequals"] = 0x8D
    }

    local keys_pressed = {
        ["0x02"] = false,
        ["0x03"] = false,
        ["0x04"] = false,
        ["0x05"] = false,
        ["0x06"] = false,
        ["0x07"] = false,
        ["0x08"] = false,
        ["0x09"] = false,
        ["0x0A"] = false,
        ["0x0B"] = false,
        ["0x1E"] = false,
        ["0x30"] = false,
        ["0x2E"] = false,
        ["0x20"] = false,
        ["0x12"] = false,
        ["0x21"] = false,
        ["0x22"] = false,
        ["0x23"] = false,
        ["0x17"] = false,
        ["0x24"] = false,
        ["0x25"] = false,
        ["0x26"] = false,
        ["0x32"] = false,
        ["0x31"] = false,
        ["0x18"] = false,
        ["0x19"] = false,
        ["0x10"] = false,
        ["0x13"] = false,
        ["0x1F"] = false,
        ["0x14"] = false,
        ["0x16"] = false,
        ["0x2F"] = false,
        ["0x11"] = false,
        ["0x2D"] = false,
        ["0x15"] = false,
        ["0x2C"] = false,
        ["0x28"] = false,
        ["0x91"] = false,
        ["0x0E"] = false ,
        ["0x2B"] = false,
        ["0x3A"] = false ,
        ["0x92"] = false,
        ["0x33"] = false,
        ["0x1C"] = false,
        ["0x0D"] = false,
        ["0x29"] = false ,
        ["0x1A"] = false,
        ["0x1D"] = false,
        ["0x38"] = false ,
        ["0x2A"] = false,
        ["0x0C"] = false,
        ["0x45"] = false,
        ["0xC5"] = false,
        ["0x34"] = false,
        ["0x1B"] = false,
        ["0x9D"] = false,
        ["0xB8"] = false ,
        ["0x36"] = false,
        ["0x46"] = false ,
        ["0x27"] = false,
        ["0x35"] = false ,
        ["0x39"] = false,
        ["0x95"] = false,
        ["0x0F"] = false,
        ["0x93"] = false,
        ["0xC8"] = false,
        ["0xD0"] = false,
        ["0xCB"] = false,
        ["0xCD"] = false,
        ["0xC7"] = false,
        ["0xCF"] = false,
        ["0xC9"] = false,
        ["0xD1"] = false,
        ["0xD2"] = false,
        ["0xD3"] = false,
        ["0x3B"] = false,
        ["0x3C"] = false,
        ["0x3D"] = false,
        ["0x3E"] = false,
        ["0x3F"] = false,
        ["0x40"] = false,
        ["0x41"] = false,
        ["0x42"] = false,
        ["0x43"] = false,
        ["0x44"] = false,
        ["0x57"] = false,
        ["0x58"] = false,
        ["0x64"] = false,
        ["0x65"] = false,
        ["0x66"] = false,
        ["0x67"] = false,
        ["0x68"] = false,
        ["0x69"] = false,
        ["0x71"] = false,
        ["0x70"] = false,
        ["0x94"] = false,
        ["0x79"] = false,
        ["0x7B"] = false,
        ["0x7D"] = false,
        ["0x90"] = false,
        ["0x96"] = false,
        ["0x52"] = false,
        ["0x4F"] = false,
        ["0x50"] = false,
        ["0x51"] = false,
        ["0x4B"] = false,
        ["0x4C"] = false,
        ["0x4D"] = false,
        ["0x47"] = false,
        ["0x48"] = false,
        ["0x49"] = false,
        ["0x37"] = false,
        ["0xB5"] = false,
        ["0x4A"] = false,
        ["0x4E"] = false,
        ["0x53"] = false,
        ["0xB3"] = false,
        ["0x9C"] = false,
        ["0x8D"] = false
    }

    coroutine.resume(coroutine.create(function ()
        while true do
            local signal_name, _, _, code = computer.pullSignal()
            if signal_name == "key_down" then
                keys_pressed[tostring(code)] = true
            elseif signal_name == "key_up" then
                keys_pressed[tostring(code)] = false
            end
        end
    end))

    local function isKeyDown(val)
        local lup = symbol_list[val] or 0
        return keys_pressed[val] or keys_pressed[lup] 
    end

    getKeysPressed = function(keyboards, symbols, symbolsAreChars)
        -- The argument of keyboards passed should be PROXIES to the keyboard!
        -- @TODO make sure a custom symbol list works!
        -- @UNSTABLE this code isn't tested!

        if symbols and symbolsAreChars then
            local newsyms = {}
            for _, char in pairs(symbols) do
                newsyms[char] = char
            end
            symbols = newsyms
        else
            symbols = symbols or symbol_list
        end

        local keysPressed = {}
        local index = {}

        for _, keyboard in pairs(keyboards) do
            for symbol_name, symbol_code in pairs(symbol_list) do
                if isKeyDown(symbol_code) then
                    if index[symbol_name] == nil then
                        index[symbol_name] = true
                        table.insert(keysPressed, symbol_name)
                    end
                end
            end
        end

        return keysPressed
    end


    getKeysPressedMin = function(keyboards, symbols)
        local keysPressed = {}
        local index = {}

        for _, keyboard in pairs(keyboards) do
            for _, symbol in pairs(symbols) do
                if isKeyDown(symbol) then
                    if index[symbol] == nil then
                        index[symbol] = true
                        table.insert(keysPressed, symbol)
                    end
                end
            end
        end

        return keysPressed, index
    end
end

function sleep(s)
    computer.pullSignal(os.clock() + (s or 1))
end

local run_network_recovery = function() end

do
    -- Define variables
    local os_candidates = {}
    local libs = {}
    local tmpfs, _tmpfs
    
    -- Define video refrences
    local clearScreen = video.clearScreen
    local print = video.print
    local println = video.println

    -- Define helpers!
    local function waitForSelection(options)
        local keys_pressed, selection
        repeat
            _, keys_pressed = getKeysPressedMin(shared.keyboards, options)
            if #keys_pressed > 0 then
                selection = keys_pressed
            end
        until selection
        return selection
    end


    local function makeSelectionMenu(options)
        for num, val in pairs(options) do
            video.println(num .. ". " .. val)
        end
        while true do
            local signal_name, _, _, code = computer.pullSignal()
            if signal_name == "key_down" then
                if options[code - 1] ~= nil then
                    return code - 1
                else
                end
            end
        end
    end

    -- Network helpers
    local function downloadFile(url, targetDevice, targetPath)
        -- Get our file handle
        println("Opening file...")
        local filehandle = targetDevice.open(targetPath, "wb")

        -- Get our HTTP handle
        println("Opening HTTP session...")
        local tcphandle = request(url)

        -- Start downloading!
        println("Downloading file...")
        local data
        repeat
            data = tcphandle:read(1)
            targetPath.write(filehandle, data)
        until not data

        println("Closing file...")
        targetDevice.close(filehandle)

        println("Download complete!")
        return
    end

    -- File system helpers
    local function mkfs(targetDevice, targetPath)
        targetDevice.makeDirectory(targetPath)
    end

    local function readFile(targetDevice, targetPath, loadLua, targetENV)
        local buffer = ""
        local handle = targetDevice.open(targetPath)
        local data
        repeat
            -- invoke(addr, "read", handle, math.huge)
            data = targetDevice.read(handle, math.huge)
            buffer = buffer .. (data or "")
        until not data 
        targetDevice.close(handle)

        if loadLua then
            return load(buffer, "=" .. targetPath, "bt", (targetENV or _G))
        else
            return buffer
        end
    end

    -- Define all targets
    local start_os_installer
    local start_efi_updater
    local start_os_selector
    local get_resources

    -- Define EFI updater
    do
        start_efi_updater = function()
            clearScreen()
            println("Not yet implemented!")
            println("Shutting down in five seconds")
        end
    end

    -- Define OS installer
    do
        local os_dest
        local target_os

        local arch_down_target = "/operation-system.cpio"

        start_os_installer = function(target_id)
            clearScreen()
            -- Let's begin installing the system!!
            target_os = os_candidates[target_id]
            target_location_selector_menu()
            download_os()
            extract_os()
            install_os()
        end

        local function target_location_selector_menu()
            println("Please select destination for OS:")

            local devices = component.list("filesystems")()
            local options = {}

            for index, address in pairs(devices) do
                table.insert(index)
                println(index, ". ", address)
            end

            local selection = waitForSelection(options)
            os_dest = devices[selection]

            println("Target location set to \"", os_dest, "\"...")
            return true
        end

        local function download_os_github()
            -- @TODO
            -- This method will be used to download an OS via github
            println("Unsupported!")
            return
        end

        local function extract_os()
            -- Extract the operating system!
            println("Extracting OS...")
            mkfs(_tmpfs, "/os")

            if target_os.archive.format == "cpio" then
                println("Opening CPIO archive...")
                libs["uncpio"](_tmpfs, arch_down_target, "/os")
            else
                println("Unsupported archive format!")
                return
            end

            println("OS extracted!")
            return
        end

        local function download_os()
            -- Download the operating system
            println("Downloading OS...")
            downloadFile(target_os.url, _tmpfs, arch_down_target)
            return
        end

        local function install_os()
            local src_os_root = "/os/"
            println("Installing OS...")

            local function copyFiles(path)
                println("Searching ", path)

                local children = _tmpfs.list(src_os_root .. path)
                local next_level = {}

                for _, child in pairs(children) do
                    local destpath = path .. "/" .. child
                    local srcpath = src_os_root .. destpath

                    if _tmpfs.isDirectory(srcpath) then
                        -- Do these later!
                        table.insert(next_level, destpath)
                    else
                        -- File!
                        println("Moving file ", destpath, "...")
                        local inhandle = _tmpfs.open(srcpath, "r")
                        local outhandle = os_dest.open(destpath, "w")

                        -- Copy the file!
                        do
                            local data
                            repeat
                                data = _tmpfs.read(handle, math.huge)
                                os_dest.write(outhandle, data)
                            until not data 
                            targetDevice.close(handle)
                        end
                    end
                end

                -- Now process the next level!
                for _, target in pairs(next_level) do
                    copyFiles(target)
                end

            end

            copyFiles("/")
            println("Operating system installed!")
            return
        end
    end

    -- Define OS option selectors
    do
        local function download_list()
            -- Fetch the list of available operating systems!
            do
                -- Download the file!
                downloadFile(consts.root_repo_url .. "/static/operating-system-candidates.json", _tmpfs, "/oslist.json")
                
                -- Read the file
                local file_contents = readFile(_tmpfs, "/oslist.json", false)

                -- Decode the file
                os_candidates = JSON:decode(file_contents)
            end

            -- Display the menus
            println("OS candidates found, displaying menu!")
        end

        local function os_list_menu()
            clearScreen()
            local choices = {}
            for option, value in pairs(os_candidates) do
                table.insert(choices, option)
                println(option, ". ", value.name)
            end
            local selection = waitForSelection(choices)
            local target = os_candidates[tonumber(selection)]
            os_info_menu(id)
        end

        local function os_info_menu(id)
            clearScreen()
            local target = os_candidates[id]
            println("Operation System Selection:")
            println(target.name, ", version ", table.concat(target.version, "."))
            println("-----")
            println(target.meta.description)

            video.setCursor(1, "bottom")
            print("[B]ack    [I]nstall")
            local selection = waitForSelection({"b","i","B","I"})

            if selection == "b" or selection == "B" then
                os_list_menu()
            elseif selection == "i" or selection == "I" then
                start_os_installer(id)
            end

        end

        start_os_selector = function()
            download_list()
            os_list_menu()
        end
    end

    -- Define the menus!
    

    -- Define entry
    run_network_recovery = function()
        -- Check if the system supports this
        if not states.supports.internet or not states.supports.tmpfs then
            println("This system does not support network recovery!")
            println("Network recovery requires internet access and a temporary file system!")
            exit_efi()
            return
        end

        -- Get the screen ready
        clearScreen()
        println("Preparing network recovery...")

        -- Start preparing!
        -- Get needed variables
        tmpfs = computer.tmpAddress()
        _tmpfs = component.proxy(tmpfs)

        -- Download libraries!
        println("Downloading libararies...")
        mkfs(_tmpfs, "/libs")
        --downloadFile(consts.root_repo_url .. "/static/libs/deflate.lua", _tmpfs, "/libs/deflate.lua")
        downloadFile(consts.root_repo_url .. "/static/libs/jsonify.lua", _tmpfs, "/libs/jsonify.lua")
        downloadFile(consts.root_repo_url .. "/static/libs/uncpio.lua", _tmpfs, "/libs/uncpio.lua")

        -- Load libraries
        println("Loading libraries...")
        --libs["deflate"] = readFile(_tmpfs, "/libs/deflate.lua", true)()
        libs["jsonify"] = readFile(_tmpfs, "/libs/jsonify.lua", true)()
        libs["uncpio"] = readFile(_tmpfs, "/libs/uncpio.lua", true)()

        -- Give them an option of where to go next
        clearScreen()
        println("1. Check for [E]FI update")
        println("2. [D]ownload OS")
        println("3. [S]hutdown")
        local selection = waitForSelection({"1","2","3","e","d","s"})

        if selection == "1" or selection == "e" then
            println("Launching EFI updator...")
            start_efi_updater()
        elseif selection == "2" or selection == "d" then
            println("Launching OS selector...")
            start_os_selector()
        elseif selection == "3" or selection == "s" then
            println("Shutting down...")
            computer.shutdown()
        else
            println("Unknown selection")
        end

    end
end

video.clearScreen("Launching network recovery...")
sleep(5)
run_network_recovery()