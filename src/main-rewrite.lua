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
        for charnum = 1, string.len(text), 1 do
            local char = string.sub(text, charnum, charnum)

            _gpu.set(video["data"]["x"], video["data"]["y"], string.sub(text, charnum, charnum))
            video["data"]["x"] = video["data"]["x"] + 1
        end
    end

    video.println = function(...)
        video.print(...)
        video["data"]["y"] = video["data"]["y"] + 1
        video["data"]["x"] = 1
        -- sleep()
    end
end

function readFile(address, target, loadLua)
    local buffer = ""
    local data = nil

    local handle = component.invoke(address, "open", target)

    repeat
        data = component.invoke(address, "read", handle, math.huge)
        buffer = buffer .. (data or "")
    until not data

    if loadLua then
        return true, load(buffer, "=init")
    else
        return true, buffer
    end
end

function attemptBootFromDevice(address)
    local isBootable = component.invoke(address, "exists", "/init.lua")
    if not isBootable then
        return nil
    end

    local _, entryPoint = readFile(address, "/init.lua", true)
    component.invoke(address, "close", handle)

    computer.getBootAddress = function()
        return address
    end

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
    local ba = findAllBootableDevices()
    if #ba == 0 then
        assert(nil, "NO BOOTABLE DEVICES FOUND!")
    end
    local e = attemptBootFromDevice(ba[1])
    e()
end

-- Define the EFI menu
local launch_efi_menu = function() end
do
    -- Define video methods
    local clearScreen = video.clearScreen
    local print = video.print
    local println = video.println

    -- @TODO make this to help prevent repeating code!
    -- @UNSAFE this has not been tested
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

    local function downloadFile(url, targetDevice, targetPath)
        -- Get our file handle
        local filehandle = targetDevice.open(targetPath, "wb")

        -- Get our HTTP handle
        local tcphandle = request(url)

        -- Start downloading!
        local data
        repeat
            data = tcphandle:read(1)
            targetPath.write(filehandle, data)
        until not data
        targetDevice.close(filehandle)
        return
    end

    -- Define various screens

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
        sleep(5)
        computer.shutdown()
    end

    local function exit_efi()
        video.println("Exiting EFI system...")
        standardBoot()
    end

    local function run_network_recovery()
        video.println("Downloading network recovery")
        local tmpfs = computer.tmpAddress()
        local _tmpfs = component.proxy(tmpfs)
        downloadFile(
            "https://raw.githubusercontent.com/OpenPenguin/EggCracker/master/src/network-recovery.lua",
            _tmpfs,
            "/recovery.lua"
        )
        local _, entryPoint = readFile(tmpfs, "/recovery.lua", true)
        entryPoint()
    end

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
        targets[tonumber(selection)]()
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
    video.println("Press shift within the next 5 seconds to open menu!")

    -- Check for interrupt!
    local intTriggered = false
    local target_time = os.clock() + 5
    repeat
        local signal_name, _, _, code = computer.pullSignal()
        if signal_name == "key_down" and (code == 42 or code == 54) then
            intTriggered = true
        end
    until (os.clock() >= target_time) or intTriggered

    if intTriggered then
        computer.beep(1000, 0.2)
        video.println("Interrupt detected! Attempting to start EFI menu...")
        sleep(1)
        launch_efi_menu()
    else
        video.println("Running normal boot operations...")
        standardBoot()
    end
end