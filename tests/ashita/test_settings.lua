local a = require('tests.lib.assertions')

local function memory_fs(options)
    options = options or {}
    local files = {}
    local dirs = {}
    local ops = {}
    local fs = {}

    function fs.exists(path)
        return files[path] ~= nil
    end

    function fs.read(path)
        return files[path]
    end

    function fs.mkdirp(path)
        dirs[path] = true
        ops[#ops + 1] = {'mkdirp', path}
        return true
    end

    function fs.write(path, data)
        files[path] = data
        ops[#ops + 1] = {'write', path}
        return true
    end

    function fs.rename(from, to)
        if files[from] == nil then return false end
        if options.rename_refuses_existing and files[to] ~= nil then
            ops[#ops + 1] = {'rename_refused_existing', from, to}
            return false
        end
        files[to] = files[from]
        files[from] = nil
        ops[#ops + 1] = {'rename', from, to}
        return true
    end

    function fs.remove(path)
        files[path] = nil
        ops[#ops + 1] = {'remove', path}
        return true
    end

    fs._files = files
    fs._dirs = dirs
    fs._ops = ops
    return fs
end

return function()
    package.loaded['ashita.settings'] = nil
    local loaded, settings = pcall(require, 'ashita.settings')
    a.equal(loaded, true, 'Phase 4 Task 1 requires ashita.settings')
    a.equal(type(settings.new), 'function', 'settings.new must expose an injectable store')
    a.equal(type(settings.path), 'function', 'settings.path production interface must exist')
    a.equal(type(settings.load), 'function', 'settings.load production interface must exist')
    a.equal(type(settings.save), 'function', 'settings.save production interface must exist')

    local fs = memory_fs()
    local store = settings.new(fs, '/cfg')
    local alice = {name='Alice', id=1001}
    local alice_alt = {name='Alice', id=1002}
    local bob = {name='Bob', id=1001}

    a.equal(store.path(alice), '/cfg/Alice_1001/rahvings/settings.lua')
    a.equal(store.path(alice_alt), '/cfg/Alice_1002/rahvings/settings.lua',
        'same name with different id must be isolated')
    a.equal(store.path(bob), '/cfg/Bob_1001/rahvings/settings.lua',
        'same id with different name must be isolated')

    local defaults = {
        visible=true,
        oneline=false,
        Display_Style='lattice',
        Display_MinValueCells=0,
        debug=false,
        info=true,
        warn=true,
        gear_reporting=false,
        Display_Box={pos={x=20,y=30}},
        Lattice={pad=4},
        Halo={value_cap=20},
        Keybinds={offensemode='f12', treasurehunter='f11'},
    }

    local first = store.load(alice, defaults)
    a.deep_equal(first, defaults, 'missing settings file must return defaults')
    first.Display_Box.pos.x = 999
    a.equal(defaults.Display_Box.pos.x, 20, 'missing-file defaults must be copied, not aliased')

    local saved = {
        visible=false,
        oneline=true,
        Display_Style='halo',
        Display_MinValueCells=14,
        debug=true,
        info=false,
        warn=false,
        gear_reporting=true,
        Display_Box={pos={x=111,y=222}},
        Lattice={pad=7},
        Halo={value_cap=17},
        Keybinds={offensemode='^f12', treasurehunter='f9', hoxne='!f10'},
    }

    a.equal(store.save(alice, saved), true, 'settings save must succeed')
    a.deep_equal(store.load(alice, defaults), saved,
        'display/chat/debug/warn/info/gear-reporting/keybind settings must round-trip')
    a.deep_equal(store.load(alice_alt, defaults), defaults,
        'another character identity must not see Alice settings')

    local final_path = store.path(alice)
    local saw_temp_write, saw_atomic_rename = false, false
    for _, op in ipairs(fs._ops) do
        if op[1] == 'write' and op[2] ~= final_path and op[2]:find('settings.lua.tmp', 1, true) then
            saw_temp_write = true
        end
        if op[1] == 'rename' and op[3] == final_path and op[2]:find('settings.lua.tmp', 1, true) then
            saw_atomic_rename = true
        end
    end
    a.equal(saw_temp_write, true, 'save must write a temporary file first')
    a.equal(saw_atomic_rename, true, 'save must atomically replace settings via rename')

    -- Windows/Ashita may refuse rename(temp, final) while final already exists. Repeated
    -- saves must still replace the character settings without deleting the only good copy
    -- before the new file has been written.
    local windows_fs = memory_fs({rename_refuses_existing=true})
    local windows_store = settings.new(windows_fs, 'C:\\Ashita\\config\\addons\\luashitacast')
    local first_windows = {visible=true, Display_Style='classic', Keybinds={offensemode='f12'}}
    local second_windows = {visible=false, Display_Style='halo', Keybinds={offensemode='^f12'}}
    a.equal(windows_store.save(alice, first_windows), true,
        'first Windows-style settings save must succeed')
    a.equal(windows_store.save(alice, second_windows), true,
        'repeated save must succeed when rename refuses an existing target')
    a.deep_equal(windows_store.load(alice, {}), second_windows,
        'repeated Windows-style save must expose only the replacement settings')

    local windows_path = windows_store.path(alice)
    for path in pairs(windows_fs._files) do
        a.equal(path:find(windows_path .. '.tmp.', 1, true) == nil, true,
            'successful replacement must not leave a temp settings file')
        a.equal(path:find(windows_path .. '.bak.', 1, true) == nil, true,
            'successful replacement must not leave a backup settings file')
    end

    local corrupt_path = store.path(bob)
    fs._files[corrupt_path] = 'this is not valid lua settings data'
    local corrupt_before = fs._files[corrupt_path]
    local recovered = store.load(bob, defaults)
    a.deep_equal(recovered, defaults, 'corrupt settings must recover to defaults')
    a.equal(fs._files[corrupt_path], corrupt_before,
        'loading corrupt settings must not silently overwrite/delete the original file')
end
