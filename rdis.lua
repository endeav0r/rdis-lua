print('loading rdis catch all')

GDB_TMP_FILENAME = '/tmp/rdis.gdb.tmp'

Gdb = require("gdb")

function gdb_remote(host, port, arch)
    -- create gdb remote connection
    local gdb, errormsg = Gdb.new(host, port, arch)
    if gdb == nil then
        rdis.console(errormsg)
        return nil
    end
    rdis.console('gdb connected')

    -- get process id
    gdb.pid = gdb:thread_pid()
    if gdb.pid == nil then
        gdb:close()
        rdis.console('Could not get process id')
        return nil
    end
    rdis.console('process id: ' .. gdb.pid)
    

    -- get path to remote process
    gdb.filename = gdb:readlink('/proc/' .. tostring(gdb:thread_pid()) .. '/exe')
    if gdb.filename == nil then
        gdb:close()
        rdis.console('Could not get process filename')
        return nil
    end
    rdis.console('process filename: ' .. gdb.filename)

    -- get remote file, store in tmp file, load in rdis
    local file = gdb:readfile(gdb.filename)
    if file == nil then
        gdb:close()
        rdis.console('Could not read debugged executable file')
        return nil
    end

    local fh, errormsg = io.open(GDB_TMP_FILENAME, 'w')
    if fh == nil then
        gdb:close()
        rdis.console('IO ERROR: ' .. errormsg)
        return nil
    end

    fh:write(file)
    fh:close()

    local loader_error = rdis.loader(GDB_TMP_FILENAME)
    if loader_error == false then
        gdb:close()
        rdis.console('error loading debug executable file')
        return nil
    end

    gdb_remote_update_mem(gdb)

    return gdb
end


function gdb_remote_update_mem (gdb)
    local filename = '/proc/' .. tostring(gdb.pid) .. '/maps'
    local maps = gdb:readfile(filename)
    local tofetch = {}
    for line in string.gmatch(maps, '(.-)\n') do
        local low  = line.match(line, '([%dabcdef]+).*')
        local high = line.match(line, '.-%-([%dabcdef]+).*')

        low  = uint64('0x' .. low)
        high = uint64('0x' .. high)
        local size = high - low
        if size ~= uint64(0) then
            tofetch[low] = size
        end
    end

    maps = {}
    local filename = '/proc/' .. tostring(gdb.pid) .. '/mem'
    for base,size in pairs(tofetch) do
        base_str = tostring(base):sub(3)
        size_str = tostring(size):sub(3)

        local bytes = gdb:readfileoffset(filename, base_str, size_str)
        if bytes == nil then
            bytes = gdb:memory(base, size)
        end
        if bytes == nil then
            rdis.console('failed fetching mem at ' .. tostring(base))
        else
            print(type(base))
            print(type(bytes))
            rdis.poke(base, bytes)
        end
    end
end