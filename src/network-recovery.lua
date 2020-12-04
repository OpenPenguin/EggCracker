--[[
    This is the network recovery system!

    It has been moved out of the EFI itself, and instead, it is downloaded when needed!
]]

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