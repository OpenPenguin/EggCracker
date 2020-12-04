--[[
    EggCracker Bootloader

    Rewritten to make it fit within the size constraints!
]]

-- Helpers
function boot_invoke(address, method, ...)
    local result = table.pack(pcall(component.invoke, address, method, ...))
    if not result[1] then
        return nil, result[2]
    else
        return table.unpack(result, 2, result.n)
    end
end

-- Load graphics system!
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

local video = {data = {x = 1, y = 1}}
do
    video.clearScreen = function()
        local width, height = _gpu.getResolution()
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