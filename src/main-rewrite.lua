--[[
    EggCracker Bootloader

    Rewritten to make it fit within the size constraints!
]]

--local consts = {version = {1,0,0},bios_menu_delay = 5,root_repo_url = "https://raw.githubusercontent.com/OpenPenguin/EggCracker/master"}
local shared = {}
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

-- Helpers
--[[
function boot_invoke(address, method, ...)
    local result = table.pack(pcall(component.invoke, address, method, ...))
    if not result[1] then
        return nil, result[2]
    else
        return table.unpack(result, 2, result.n)
    end
end
]]--

-- Load graphics system!
local screen = component.list("screen")()
local gpu = component.list("gpu")()

if (not screen) and (not gpu) then
    states.supports.video = false
    return
end

if screen and gpu then
    component.invoke(gpu, "bind", screen)
    states.supports.video = true
end

function sleep(s)
    computer.pullSignal(os.clock() + (s or 1))
end

local video = {data = {x = 1, y = 1}}
do
    local _gpu = component.proxy(gpu)
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
                --[[
                if video["data"]["x"] > width then
                    video["data"]["x"] = 1
                    video["data"]["y"] = video["data"]["y"] + 1
                end
                ]]

                if video["data"]["y"] > height then
                    video.clearScreen()
                    video["data"]["x"] = 1
                    video["data"]["y"] = 1
                end
            end
        end
    end

    video.println = function(...)
        video.print(...)
        video["data"]["y"] = video["data"]["y"] + 1
        video["data"]["x"] = 1
        sleep()
    end
end

function readFile(address, target, isHandle, loadLua)
    local buffer = ""
    local data = nil

    local handle

    if isHandle then
        handle = target
    else
        -- handle, _ = boot_invoke(address, "open", target)
        handle = component.invoke(address, "open", target)
    end

    repeat
        -- data, _ = boot_invoke(address, "read", handle, math.huge)
        data = component.invoke(address, "read", handle, math.huge)
        buffer = buffer .. (data or "")
    until not data

    if loadLua then
        -- @TODO maybe get rid of the second argument. I don't know what it does...
        return true, load(buffer, "=init")
    else
        return true, buffer
    end
end

--[[
function checkDeviceForBootable(address)
    component.invoke(address, "exists", "/init.lua")
    local exists, reason = boot_invoke(address, "exists", "/init.lua")
    return exists
end
]]--

function attemptBootFromDevice(address)
    -- address = computer.getBootAddress()
    assert(address, "NO BOOT ADDR GIVEN")
    local isBootable = component.invoke(address, "exists", "/init.lua")
    if not isBootable then
        return nil
    end

    local _, entryPoint = readFile(address, "/init.lua", false, true)
    -- boot_invoke(address, "close", handle)
    component.invoke(address, "close", handle)
    return entryPoint
end

function findAllBootableDevices()
    local addrs = {}
    for address, _ in component.list("filesystem") do
        local bootable = component.invoke(address, "exists", "/init.lua")
        if bootable then
            table.insert(addrs, address)
        end
    end
    return addrs
end

function standardBoot()
    video.println("Booting into operating system...")
    -- local ba = computer.getBootAddress()
    -- boot_invoke(eeprom, "getData")
    --[[
    local ba
    if computer.getBootAddress then
        ba = computer.getBootAddress()
    else
        -- ba = component.invoke(assert(component.list("eeprom")(), "No EEPROM!"), "getData")
    end
    assert(ba, "No boot address found!")
    ]]
    local ba = findAllBootableDevices()
    if #ba == 0 then
        assert(nil, "NO BOOTABLE DEVICES FOUND!")
    end
    local e = attemptBootFromDevice(assert(ba[1], "No boot address found!"))
    computer.getBootAddress = function()
        return ba[1]
    end
    e()
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
                table.insert(choices, assert(index, "No index!"))
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
        video.println("Loading selection!")
        targets[tonumber(selection)]()
    end

    local function boot_selector_menu()
        -- Get the screen ready!
        clearScreen()
        video.println("Getting bootable devices...")

        -- Get a list of all bootable devices
        local devices = findAllBootableDevices()

        -- Draw a menu!
        clearScreen()
        local option = makeSelectionMenu(devices)

        local boot_target = devices[option]
        local entry = attemptBootFromDevice(boot_target)

        if entry ~= nil then
            video.println("Booting target system...")
            entry()
        else
            video.println("Unable to boot to selected device!")
            video.println("Shutting down!")
            computer.shutdown()
            return
        end
    end

    -- @TODO implement
    local function boot_settings_menu()
        clearScreen()
        video.println("Boot settings menu is not currently implemented!")
        video.println("System will shutdown in five seconds!")
        -- sleep(5)
        computer.shutdown()
    end

    local function exit_efi()
        video.println("Exiting EFI system...")
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
        local currentTime = os.clock()
        local endTime = currentTime + seconds
        local shouldEscape = false

        repeat
            local r = method(currentTime)
            if r then
                shouldEscape = true
            end
            currentTime = os.clock()
        until (currentTime >= endTime) or shouldEscape
    end

    -- Define constants
    
    -- Tell the user we are booting!
    video.clearScreen()
    video.println("EggCracker version 1.0.0 booting!")
    video.println("Waiting for 5 seconds...")

    -- Sleep
    local now = os.clock()
    sleep(3)

    computer.beep(1000, 0.2)
    computer.beep(1000, 0.2)
    computer.beep(1000, 0.2)

    video.println("Press shift within the next 5 seconds to open menu!")

    -- Check for interrupt!
    local intTriggered = false
    if states.supports.keyboard then
        --[[
        runWhileTimer(5, function()
            if component.invoke(keyboard, "isShiftDown") then
                intTriggered = true
                return true
            end
        end)
        ]]--

        local signal_name, _, _, _ = computer.pullSignal()
        if signal_name == "key_down" then
            intTriggered = true
            return true
        end

        --[[
        runWhileTimer(5, function()
            local signal_name, _, _, _ = computer.pullSignal()
            if signal_name == "key_down" then
                intTriggered = true
                return true
            end
        end)
        ]]--
    end

    if intTriggered then
        computer.beep(1000, 0.2)
        video.println("Interrupt detected! Attempting to start EFI menu...")
        -- sleep(5)
        launch_efi_menu()
    else
        video.println("Running normal boot operations...")
        sleep(5)
        standardBoot()
    end
end