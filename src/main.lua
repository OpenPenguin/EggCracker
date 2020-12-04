--[[
    This is the entry point for the bootloader!
]]

function init(config, consts)
    --==========[ Define shared variables! ]==========--
    -- General shared data
    local shared = {
        bootAddress = nil,
        graphics = nil
    }
    -- Defines "states" for the system
    local states = {
        supports = {
            video = false,
            keyboard = false,
            internet = false,
            network = false,
            tmpfs = false
        },
        bootable = false,
    }

    --==========[ Define helper methods ]==========--
    -- TODO: Get rid of this. It's just here for now to make development easier.
    -- @DEPRECIATED get rid of this ASAP
    function boot_invoke(address, method, ...)
        local result = table.pack(pcall(component.invoke, address, method, ...))
        if not result[1] then
            return nil, result[2]
        else
            return table.unpack(result, 2, result.n)
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
                    if keyboard.isKeyDown(symbol_code) then
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
                    if keyboard.isKeyDown(symbol) then
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

    -- @UNSAFE this hasn't been tested
    function sleep(seconds)
        local currentTime = os.time()
        repeat
            -- Just do SOMETHING to try and prevent a crash from looping!
            computer.uptime()
            currentTime = os.time()
        until (currentTime >= currentTime + seconds) or shouldEscape
    end

    --==========[ Begin preboot process ]==========--
    -- Init the graphics system!
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

    -- Get the keyboard!
    do
        local keyboards = component.proxy(component.list("screen")()).getKeyboards()
        if not (keyboards == nil or #keyboards == 0) then
            states.supports.keyboard = true
            shared.keyboards = {}
            for addr in pairs(keyboards) do
                table.insert(shared.keyboards, component.proxy(addr))
            end
        end
    end

    -- Check for a few more capibilities
    do
        video.println("Checking for capibilities...")
        -- 1. Internet capibilities (HTTP)
        do
            local devices = component.list("internet")()
            if devices == nil or #devices == 0 then
                states.supports.internet = false
                video.println("No internet capibility found!")
            else
                states.supports.internet = true
                video.println("Internet capibility found!")
            end
        end

        -- 3. Temporary filesystem capibilities
        do
            local tmpfs = computer.tmpAddress()
            if not tmpfs then
                states.supports.tmpfs = false
                video.println("No TMPFS capibility found!")
            else
                states.supports.tmpfs = true
                video.println("TMPFS capibility found!")
            end
        end

        video.println("Capibility test done!")
    end

    --==========[ Define boot loader methods ]==========--
    function readFile(address, target, isHandle, loadLua)
        local buffer = ""
        local reason = nil
        local data = nil

        local handle

        if isHandle then
            handle = target
        else
            local reason = nil
            handle, reason = boot_invoke(address, "open", target)
        end

        repeat
            data, reason = boot_invoke(address, "read", handle, math.huge)
            if not data and reason then
                return false, reason
            end
            buffer = buffer .. (data or "")
        until not data

        if loadLua then
            -- @TODO maybe get rid of the second argument. I don't know what it does...
            return true, load(buffer, "=init")
        else
            return true, buffer
        end
    end

    function checkDeviceForBootable(address)
        local exists, reason = boot_invoke(address, "exists", "/init.lua")
        return exists
    end

    function attemptBootFromDevice(address)
        local isBootable = checkDeviceForBootable(address)
        if not isBootable then
            return nil
        end

        local entryPoint = readFile(address, "/init.lua", false, true)
        boot_invoke(address, "close", handle)

        return entryPoint
    end

    function findAllBootableDevices()
        local addrs = {}
        for address, _ in component.list("filesystem") do
            local bootable = checkDeviceForBootable(address)
            if bootable then
                table.insert(addrs, address)
            end
        end
        return addrs
    end

    function standardBoot()
        println("Booting into operating system...")
        attemptBootFromDevice(computer.getBootAddress())()
    end

    --==========[ Define EFI ]==========--

    -- Define the EFI menu
    local launch_efi_menu = function() end
    do
        -- Define video methods
        local clearScreen = video.clearScreen
        local print = video.print
        local println = video.println

        -- Define helpers
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

        -- @TODO make this to help prevent repeating code!
        -- @UNSAFE this has not been tested
        local function makeSelectionMenu(...)
            -- Choices represent the options at the begining (what the user clicks!)
            -- Options are the text after that

            local args = {...}
            local choices = {}
            local values = {}
            local genChoices = true
            local returnSelectedValue = true

            if #args == 0 then
                return nil
            elseif #args == 1 then
                values = args[1]
            elseif #args == 2 then
                genChoices = false
                choices = args[1]
                values = args[2]
            elseif #args == 3 then
                genChoices = false
                choices = args[1]
                values = args[2]
                returnSelectedValue = args[3]
            end

            for index, text in pairs(options) do
                if genChoices then
                    table.insert(choices, index)
                end
                println(options[index], ". ", text)
            end

            local selection = waitForSelection(choices)

            if returnSelectedValue then
                return values[selection] or nil
            else
                return selection or nil
            end
        end

        -- Define various screens
        local function main_menu()
            -- @TODO use the makeSelectionMenu() method to create this menu!
            -- Draw the screen
            clearScreen()
            local targets = {boot_selector_menu, boot_settings_menu, run_network_recovery, exit_efi}
            local selection = makeSelectionMenu({
                "Select boot device", 
                "Edit boot settings", 
                "Network recovery mode", 
                "Continue normal boot"
            })
            println("Loading selection!")
            targets[tonumber(selection)]()
        end

        local function boot_selector_menu()
            -- Get the screen ready!
            clearScreen()
            println("Getting bootable devices...")

            -- Get a list of all bootable devices
            local devices = findAllBootableDevices()

            -- Draw a menu!
            clearScreen()
            local option = makeSelectionMenu(devices)

            local boot_target = devices[option]
            local entry = attemptBootFromDevice(boot_target)

            if entry ~= nil then
                println("Booting target system...")
                entry()
            else
                println("Unable to boot to selected device!")
                println("Shutting down!")
                computer.shutdown()
                return
            end
        end

        -- @TODO implement
        local function boot_settings_menu()
            clearScreen()
            println("Boot settings menu is not currently implemented!")
            println("System will shutdown in five seconds!")
            sleep(5)
            computer.shutdown()
        end

        local function exit_efi()
            println("Exiting EFI system...")
            standardBoot()
        end

        -- Allow external methods to launch this!
        launch_efi_menu = function()
            video.println("Launching EFI menu...")
            main_menu()
        end
    end

    --==========[ Begin boot process ]==========--
    do
        -- Define helpers
        local function runWhileTimer(seconds, method)
            local currentTime = os.time()
            local endTime = currentTime + seconds
            local shouldEscape = false

            repeat
                local r = method(currentTime)
                if r then
                    shouldEscape = true
                end
                currentTime = os.time()
            until (currentTime >= endTime) or shouldEscape
        end

        -- Define constants
        
        -- Tell the user we are booting!
        video.clearScreen()
        video.println("EggCracker version ", table.concat(consts["version"],"."), " booting!")
        video.println("Press shift within the next ", consts["bios_menu_delay"], " seconds to open menu!")

        -- Get important information
        shared.bootAddress = computer.getBootAddress()
        video.println("Got boot address!")

        -- Check for interrupt!
        local intTriggered = false
        if states.supports.keyboard then
            runWhileTimer(consts["bios_menu_delay"], function()
                for _, keyboard in pairs(shared.keyboards) do
                    if keyboard.isShiftDown() then
                        intTriggered = true
                        return true
                    end
                end
                if intTriggered then
                    return true
                end
                return false
            end)
        end

        if intTriggered then
            computer.beep(1000, 0.2)
            video.println("Interrupt detected! Attempting to start EFI menu...")
            launch_efi_menu()
        else
            video.println("Running normal boot operations...")
            standardBoot()
        end
    end
end

-- Launch the bootloader
--[[
    The line below may be rewritten by the settings configuration system!
    The "init(...)" line ALWAYS must be the very last line in this file, otherwise things may
    break.
]]
init({["allowEFIMenu"] = true},{version = {1,0,0},bios_menu_delay = 5,root_repo_url = "https://raw.githubusercontent.com/OpenPenguin/EggCracker/master"})