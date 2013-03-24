require "xavante"

local XAVANTE_PORT = 8000
rdis.console("XAVANTE_PORT = " .. tostring(XAVANTE_PORT))

local tpl = {}

tpl.css = [[
body, div, td {
    font-family: terminus, monospace, courier new;
    font-size: 10pt;
}
li {
    list-style-type: square;
}
a {
    color: #009;
    text-decoration: none;
}
a:hover {
    text-decoration: underline;
}
#menu {
    display: none;
    position: absolute;
    padding: 4px;
    background-color: #eee;
    border: 1px solid #333;
}
.menuitem {
    color: #930;
    cursor: pointer;
}

]]

tpl.frames = [[
<html>
    <head>
        <title>Rdis, Cyber Style</title>
    </head>
    <frameset cols="20%, 80%">
        <frame src="/functions" name="functions">
        <frame src="/graph" name="graph">
    </frameset>
</html>
]]

tpl.global = [[
<home>
    <head>
        <script src="http://code.jquery.com/jquery.min.js"></script>
        <title>Rdis, Cyber Style</title>
        <style type="text/css">%css%</style>
    </head>
    <body>
        %content%
    </body>
</home>
]]


tpl.functions       = [[
<table>
    <tr>
        <td><strong><a href="/functions">Address</a></strong></td>
        <td><strong><a href="/functions/sort/label">Label</a></strong></td>
    </tr>
    %functions_items%
</table>
]]
tpl.functions_items = [[
    <tr>
        <td>%address%</td>
        <td><a href="/graph/%address%" target="graph">%name%</a></td>
    </tr>
]]
tpl.graph = [[
<script src="http://code.jquery.com/jquery.min.js"></script>
<script type="text/javascript">

var graphurl = '/graph/png/%address';

var lastx = 0;
var lasty = 0;

function nocache () {
    return '/nocache' + new Date().getTime();
}

$(document).ready(function () {
    $(document).click(function(e) {
        $('#menu').hide();
    });

    $('#graphpng').click(function(e) {
        var x = (e.pageX - $('#graphpng').offset().left);
        var y = (e.pageY - $('#graphpng').offset().top);

        lastx = x;
        lasty = y;

        $('#graphpng').attr('src', '/graph/png/%address%/' + x + '/' + y + nocache());
    });

    $(document).keypress(function (e) {
        if (e.which == 59) {
            docomment(lastx, lasty);
        }
    });

    function docomment (x, y) {
        $.ajax({
          url: "/graph/png/getcomment/%address%/" + x + "/" + y,
          beforeSend: function ( xhr ) {
            xhr.overrideMimeType("text/plain; charset=x-user-defined");
          }
        }).done(function (data) {
            var new_comment = prompt("Enter new comment", data);
            if (new_comment == null)
                new_comment = '';
            $.ajax({
                url: "/graph/png/setcomment/%address%/" + x + "/" + y + "/" + new_comment,
                beforeSend: function ( xhr ) {
                  xhr.overrideMimeType("text/plain; charset=x-user-defined");
                }
            }).done(function (data) {
                $('#graphpng').attr('src', '/graph/png/%address%/nocache' + new Date().getTime());
            });
        });
    }

    $('#graphpng').bind('contextmenu', function(e) {
        $('#menu').css({
            left: e.pageX+'px',
            top:  e.pageY+'px'
        }).show();
        var x = (e.pageX - $('#graphpng').offset().left);
        var y = (e.pageY - $('#graphpng').offset().top);

        $('#graphpng').attr('src', '/graph/png/%address%/' + x + '/' + y + nocache());
        return false;
    });

    $('#comment').click(function (e) {
        var x = $('#menu').offset().left - $('#graphpng').offset().left;
        var y = $('#menu').offset().top  - $('#graphpng').offset().top;
        docomment(x, y);
    });
});
</script>
<img id="graphpng" src="/graph/png/%address%%xy%" />
<div id="menu">
    <span class="menuitem" id="comment">Modify Comment</span>
</div>
]]


CALLBACKS = {}


function functions_sort (functions, sort_func)
    local sorted = {}
    for k,v in pairs(functions) do
        local item = {address = k, name = v}
        table.insert(sorted, item)
    end

    table.sort(sorted, sort_func)
    return sorted
end


function tplize (template, replacements)
    for k, v in pairs(replacements) do
        template = string.gsub(template, '%%' .. k .. '%%', v)
    end
    return template
end


function do_functions (functions_sorted)
    local functions_items = {}
    for k,func in pairs(functions_sorted) do
        local vars = {address = tostring(func.address), name = func.name}
        local item = tplize(tpl.functions_items, vars)
        table.insert(functions_items, item)
    end

    local content = tplize(tpl.functions, {functions_items=table.concat(functions_items)})

    local vars = {
                    functions = table.concat(functions_items),
                    content   = content,
                    css       = tpl.css
                }
    return tplize(tpl.global, vars)
end


function rdis_handler (req, res)
    res.headers['Content-Type']  = 'text/html'
    res.headers['Cache-Control'] = 'no-store, no-cache, must-revalidate, proxy-revalidate, max-age=0'
    res.headers['Expires']       = 'Thu, 01 Jan 1970 00:00:00 GMT'

    print(req.srv, "request: " .. req.relpath)

    if req.relpath == '/' then
        res.content = tpl.frames
        return res

    elseif req.relpath == '/graph' then
        res.content = 'graph here'
        return res

    elseif req.relpath == '/functions/sort/label' then
        local functions_sorted = functions_sort(rdis.functions(), function (lhs, rhs)
                if lhs.name < rhs.name then
                    return true
                end
                return false
                end)

        res.content = do_functions (functions_sorted)
        return res

    elseif req.relpath == '/functions' then
        local functions_sorted = functions_sort(rdis.functions(), function (lhs, rhs)
                if lhs.address < rhs.address then
                    return true
                end
                return false
                end)

        res.content = do_functions(functions_sorted)
        return res

    elseif string.match(req.relpath, '^/graph/0x[%dabcdef]+$') then
        local address = string.match(req.relpath, '/graph/(0x[%dabcdef]+)')
        local vars = {address=address, xy=''}
        local content = tplize(tpl.graph, vars)

        vars = {
            content = content,
            css     = tpl.css
        }
        res.content = tplize(tpl.global, vars)
        return res

    elseif string.match(req.relpath, '^/graph/png/0x[%dabcdef]+/%d+/%d+') then
        local pattern = '/graph/png/(0x[%dabcdef]+)/(%d+)/(%d+)'
        local address, x, y = string.match(req.relpath, pattern)
        local rdg = rdis.rdg(uint64(address))
        local ins = rdg:ins_by_coords(x, y)
        if ins ~= nil then
            local node = rdg:node_by_coords(x, y)
            local node_index = rdg:node_by_coords(x, y):index()
            local ins_address  = rdg:ins_by_coords(x, y):address()
            rdg:highlight_ins(node_index, ins_address)
        end

        
        res.headers['Content-Type'] = 'image/png'
        rdg:save_png('/tmp/rdis.png')
        local fh = io.open('/tmp/rdis.png')
        local png = fh:read('*a')
        fh:close()
        res.content = png
        return res

    elseif string.match(req.relpath, '^/graph/png/getcomment/0x[%dabcdef]+/%d+/%d+$') then
        local pattern = '/graph/png/getcomment/(0x[%dabcdef]+)/(%d+)/(%d+)'
        local address, x, y = string.match(req.relpath, pattern)
        local rdg = rdis.rdg(uint64(address))
        local ins   = rdg:ins_by_coords(x, y)
        res.content = ins:comment()
        return res

    elseif string.match(req.relpath, '^/graph/png/setcomment/0x[%dabcdef]+/%d+/%d+/[%w%s%p]*$') then
        local pattern = '/graph/png/setcomment/(0x[%dabcdef]+)/(%d+)/(%d+)/([%w%s%p]*)'
        local address, x, y, comment = string.match(req.relpath, pattern)
        local rdg = rdis.rdg(uint64(address))
        local node = rdg:node_by_coords(x, y)
        local ins  = rdg:ins_by_coords(x, y)
        rdis.set_ins_comment(node:index(), ins:address(), comment)
        res.content = 'done'
        return res

    elseif string.match(req.relpath, '^/graph/png/0x[%dabcdef]+') then
        local address = string.match(req.relpath, '/graph/png/(0x[%dabcdef]+)')
        local rdg     = rdis.rdg(uint64(address))
        rdg:save_png('/tmp/rdis.png')
        
        res.headers['Content-Type'] = 'image/png'
        local fh = io.open('/tmp/rdis.png', 'r')
        local png = fh:read('*a')
        fh:close()
        res.content = png
        return res
    else
        print("bad query")
    end
end

local simplerules = {
    {
        match = '.*',
        with = rdis_handler
    }
}

xavante.HTTP {
    server = {host = "*", port = XAVANTE_PORT},
    defaultHost = {
        rules = simplerules
    }
}