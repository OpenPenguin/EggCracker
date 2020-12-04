--[[

	Original code by "bad at vijya"
	(Link here: https://oc.cil.li/topic/1898-uncpio-a-simple-cpio-extraction-utility/?tab=comments#comment-8892)

	Code modified to make it into a library!
	For now, I am just wrapping the code into a function, to make it callable like a library.

	# Changes
	- I had to patch the reference to the "filesystem" library. I'm not in OpenOS, it isn't available!
	- I had to patch the methods in which the system get's the working directory!
	- I had to patch any usage of the "io" library. Again, I don't beleive it is available!

	# Info
	When the code runs PWD (Print Working Directory), it's bascially checking for the target folder!
]]

function patched(source_device, source_file, dest_folder)
	-- Define constants
	local dent = {
		magic = 0,
		dev = 0,
		ino = 0,
		mode = 0,
		uid = 0,
		gid = 0,
		nlink = 0,
		rdev = 0,
		mtime = 0,
		namesize = 0,
		filesize = 0,
	}

	-- Define helpers
	local function readint(amt, rev)
		local tmp = 0
		for i=(rev and amt) or 1, (rev and 1) or amt, (rev and -1) or 1 do
			-- tmp = tmp | (file:read(1):byte() << ((i-1)*8))
			tmp = tmp | (source_device.read(file, 1):byte() << ((i-1)*8))
		end
		return tmp
	end

	local function fwrite()
		local dir = dent.name:match("(.+)/.*%.?.+")
		if (dir) then
			-- filesystem.makeDirectory(os.getenv("PWD").."/"..dir)
			source_device.makeDirectory(dest_folder.."/"..dir)
		end
		--[[
		local hand = io.open(dent.name, "w")
		hand:write(file:read(dent.filesize))
		hand:close()
		]]--
		local hand = source_device.open(dent.name, "w")
		source_device.write(hand, source_device.read(file, dent.filesize))
		source_device.close(hand)
	end

	-- Open the file
	local file = source_device.open(source_file)

	-- Main code!
	while true do
		dent.magic = readint(2)
		local rev = false
		if (dent.magic ~= tonumber("070707", 8)) then rev = true end
		dent.dev = readint(2)
		dent.ino = readint(2)
		dent.mode = readint(2)
		dent.uid = readint(2)
		dent.gid = readint(2)
		dent.nlink = readint(2)
		dent.rdev = readint(2)
		dent.mtime = (readint(2) << 16) | readint(2)
		dent.namesize = readint(2)
		dent.filesize = (readint(2) << 16) | readint(2)
		-- local name = file:read(dent.namesize):sub(1, dent.namesize-1)
		local name = source_device.read(file, dent.namesize):sub(1, dent.namesize-1)
		if (name == "TRAILER!!!") then break end
		--for k, v in pairs(dent) do
		--	print(k, v)
		--end
		dent.name = name
		print(name)
		if (dent.namesize % 2 ~= 0) then
			-- file:seek("cur", 1)
			source_device.seek(file, "cur", 1)
		end
		if (dent.mode & 32768 ~= 0) then
			fwrite()
		end
		if (dent.filesize % 2 ~= 0) then
			-- file:seek("cur", 1)
			source_device.seek(file, "cur", 1)
		end
	end
end

return patched