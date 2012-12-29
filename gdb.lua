local socket = require("socket")
local bit    = require("bit")

-- architecture specific information
local architectures = {}
architectures['amd64'] = {}
architectures['amd64']['registers'] = {
    {'rax', 64}, {'rbx', 64},    {'rcx', 64}, {'rdx', 64},
    {'rsi', 64}, {'rdi', 64},    {'rbp', 64}, {'rsp', 64},
    {'r8',  64}, {'r9',  64},    {'r10', 64}, {'r11', 64},
    {'r12', 64}, {'r13', 64},    {'r14', 64}, {'r15', 64},
    {'rip', 64}, {'eflags', 32}, {'cs',  32}, {'ss',  32},
    {'ds',  32}, {'es',  32},    {'fs',  32}, {'gs',  32}
}
architectures['amd64']['endian'] = 'little'

Gdb = {}
Gdb.__index = Gdb

function stringtohex (string)
    local hexchars = {'0', '1', '2', '3', '4', '5', '6', '7',
                      '8', '9', 'a', 'b', 'c', 'd', 'e', 'f'}
    local hexstring = ''
    for i=1,#string do
        local byte = string:byte(i)
        local lo = byte % 16 + 1
        local hi = math.floor(byte / 16) + 1
        hexstring = hexstring .. hexchars[hi] .. hexchars[lo]
    end
    return hexstring
end


-- Gdb.new         (host, port arch)
-- Gdb.recv_packet (gdb)
-- Gdb.make_packet (gdb)
-- Gdb.close       (gdb)

-- Gdb.raw_query   (gdb, text)
-- Gdb.registers   (gdb)
-- Gdb.step        (gdb)
-- Gdb.thread_pid  (gdb)
-- Gdb.readfile    (gdb, filename)


function Gdb.new (host, port, arch)
    local supported = false
    for supported_arch, i in pairs(architectures) do
        if arch == supported_arch then
            supported = true
            break
        end
    end
    
    if not supported then
        return nil, "architecture not supported"
    end
    
    local gdb = {}
    setmetatable(gdb, Gdb)
    
    gdb.arch = arch

    gdb.sock = socket.tcp()
    if gdb.sock:connect(host, port) ~= 1 then
        return nil, "could not connect to " .. host .. tostring(port)
    end
    
    gdb.sock:send(gdb:make_packet("qSupported:"))
    gdb.supported = gdb:recv_packet()
    
    return gdb
end


-- http://sourceware.org/gdb/current/onlinedocs/gdb/Overview.html
function Gdb.recv_packet (gdb)

    local function unescape (c)
        return string.char(bit.bxor(c:byte(1,1), 0x20))
    end
    
    -- start be receiving data from the server
    local tmp  = ''
    local data = ''
    
    while true do
        tmp = tmp .. gdb.sock:receive(1)
        if tmp:match('$(.*)#..') ~= nil then
            data = tmp:match('$(.*)#..')
            break
        end
    end
    
    -- send acknowledgement back to server
    gdb.sock:send('+')
    
    local result = ''
    local i = 0
    while i <= #data do
        local c = data:sub(i, i)
        
        -- check for RLE
        if data:sub(i+1, i+1) == '*' then
            -- get repeat count
            
            local repeat_n = data:byte(i+2, i+2) - 28
                
            while repeat_n > 0 do
                result = result .. c
                repeat_n = repeat_n - 1
            end
            i = i + 3
            
        -- check for escaped characters
        elseif c == '}' then
            result = result .. unescape(data:sub(i+1,i+1))
            i = i + 2
        -- just a char :( we never go out anymore )
        else
            result = result .. data:sub(i, i)
            i = i + 1
        end
    end
    return result
end


function Gdb.make_packet (gdb, data)
    local checksum = 0
    for i = 1,#data do
        checksum = (checksum + data:byte(i,i)) % 256
    end
    return '$' .. data .. '#' .. bit.tohex(checksum, 2)
end


function Gdb.close (gdb)
    gdb.sock:close()
end






function Gdb.raw_query (gdb, query)
    gdb.sock:send(gdb:make_packet(query))
    return gdb:recv_packet()
end


-- reads registers and applies architecture specific information to
-- the registers
function Gdb.registers (gdb)
    gdb.sock:send(gdb:make_packet('g'))
    
    local result = gdb:recv_packet()
    
    local register_strings = {}
    local i = 1
    while i < #result do
        local reg_string = result:sub(i, i+15)
        table.insert(register_strings, reg_string)
        i = i + 16
    end
    
    local text_i = 1
    local registers = {}
    for i,reg in pairs(architectures[gdb.arch]['registers']) do
        local name = reg[1]
        local size = reg[2]
        
        local register_string = result:sub(text_i, text_i + (size / 4) - 1)
        text_i = text_i + (size / 4)
        
        -- if needed adjust string for endianness
        if architectures[gdb.arch]['endian'] == 'little' then
            local fixed_string = ''
            local i = #register_string - 1
            while i >= 1 do
                fixed_string = fixed_string .. register_string:sub(i,i+1)
                i = i - 2
            end
            register_string = fixed_string
        end
        
        registers[name] = register_string
    end
    
    return registers
end


function Gdb.step (gdb)
    gdb:raw_query('s')
end


function Gdb.thread_pid (gdb)
    local response = gdb:raw_query("qC")
    if response:sub(1,2) ~= "QC" then
        return nil
    end
    
    local digits = response:sub(3)
    return tonumber(digits, 16)
end

function Gdb.readlink (gdb, filename)
    if filename == nil then
        print('Gdb.readlink got nil filename')
        return nil
    end
    local query = 'vFile:readlink:' .. stringtohex(filename)
    local response = gdb:raw_query(query)

    print(response)

    if response:sub(1, 1) == 'F' then
        return response:match('F[%dabcdef]-;(.*)')
    end
    return nil
end

function Gdb.readfile (gdb, filename)
    local query = 'vFile:open:' .. stringtohex(filename) .. ',0,0'

    local fd = gdb:raw_query(query)
    fd = fd:sub(2)
    if fd:sub(1,2) == '-1' then
        print('error opening file')
        return nil
    end

    local file = gdb:raw_query('vFile:pread:' .. fd .. ',fffffff,0')

    gdb:raw_query('vFile:close:' .. fd)

    if file:sub(2,3) == '-1' then
        print('filesize was -1')
        return nil
    end

    return file:match('F[%dabdef]-;(.*)')
end

return Gdb