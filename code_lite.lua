-- WIA HUB v15 PAPER (бумажный стиль, бумажные звуки, фикс аимбота, новые функции)
-- Данные снайпера: wia_emotes.txt / wia_anims.txt / wia_anims_offsale.txt в workspace экзекьютора
local BASE = "https://raw.githubusercontent.com/wiascripts/whitehub/main/"
local SNIPER_DATA = setmetatable({}, {
    __index = function(t, mode)
        local names = { emotes = "wia_emotes.txt", anims = "wia_anims.txt", offsale = "wia_anims_offsale.txt" }
        local f = names[mode]
        if not f then return nil end
        local txt
        if readfile and isfile and isfile(f) then
            local ok, r = pcall(readfile, f)
            if ok then txt = r end
        end
        if not txt then
            local ok, r = pcall(function() return game:HttpGet(BASE .. f) end)
            if ok and type(r) == "string" and #r > 100 then
                txt = r
                if writefile then pcall(writefile, f, r) end
            end
        end
        if txt then rawset(t, mode, txt) end
        return txt
    end,
})

local function main()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local InsertService = game:GetService("InsertService")
local Stats = game:GetService("Stats")
local Debris = game:GetService("Debris")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local Mouse = LocalPlayer:GetMouse()
local hasDrawing = pcall(function() local d = Drawing.new("Line") d:Remove() end)

-- ========== CORE HELPERS ==========
local conns, guis = {}, {}
local function bind(sig, fn)
    local c = sig:Connect(fn)
    conns[#conns + 1] = c
    return c
end

local function parentGui(gui)
    local ok = pcall(function() gui.Parent = (gethui and gethui()) or CoreGui end)
    if not ok or not gui.Parent then gui.Parent = LocalPlayer:WaitForChild("PlayerGui") end
    guis[#guis + 1] = gui
end

local function font(name, fb)
    local ok, f = pcall(function() return Enum.Font[name] end)
    return ok and f or fb
end
local FONTSETS = {
    hand = { font("PatrickHand", Enum.Font.Gotham), font("Kalam", Enum.Font.GothamBold) },
    type = { font("SpecialElite", Enum.Font.Code), font("Code", Enum.Font.Code) },
    serif = { font("Merriweather", Enum.Font.Gotham), font("Merriweather", Enum.Font.GothamBold) },
    clean = { font("Nunito", Enum.Font.Gotham), font("Nunito", Enum.Font.GothamBold) },
}
local F = { body = FONTSETS.hand[1], bold = FONTSETS.hand[2] }
local fontObjs = setmetatable({}, { __mode = "k" })
local function applyFont(k)
    local set = FONTSETS[k] or FONTSETS.hand
    F.body, F.bold = set[1], set[2]
    for o, kind in pairs(fontObjs) do pcall(function() o.Font = F[kind] end) end
end
local function new(class, props, parent)
    local o = Instance.new(class)
    local fk
    for k, v in pairs(props) do
        if k == "Font" then
            if v == Enum.Font.Gotham then fk = "body" elseif v == Enum.Font.GothamBold then fk = "bold" end
            o.Font = fk and F[fk] or v
        else
            o[k] = v
        end
    end
    if fk then fontObjs[o] = fk end
    if parent then o.Parent = parent end
    return o
end

local function trim(s) return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", "")) end

-- ========== THEME ==========
local S
local T = {
    bg = Color3.fromRGB(242, 234, 214), panel = Color3.fromRGB(250, 245, 232),
    row = Color3.fromRGB(252, 249, 240), rowd = Color3.fromRGB(226, 216, 193),
    rowh = Color3.fromRGB(238, 229, 207),
    accent = Color3.fromRGB(52, 98, 190),
    text = Color3.fromRGB(52, 45, 40), dim = Color3.fromRGB(128, 116, 100),
    stroke = Color3.fromRGB(196, 182, 154), ok = Color3.fromRGB(70, 150, 90), err = Color3.fromRGB(200, 70, 65),
    onAccent = Color3.fromRGB(255, 255, 255), note = Color3.fromRGB(255, 243, 168),
}
local accentRefs = {}
local function ref(obj, prop, fn)
    accentRefs[#accentRefs + 1] = { obj, prop, fn }
    obj[prop] = fn and fn() or T.accent
end
local function setAccent(c)
    T.accent = c
    for i = #accentRefs, 1, -1 do
        local r = accentRefs[i]
        if r[1].Parent then r[1][r[2]] = r[3] and r[3]() or c else table.remove(accentRefs, i) end
    end
    if S.fovRef then S.fovRef.Color = c end
end

local function addCorner(o, r, exact) return new("UICorner", { CornerRadius = UDim.new(0, exact and (r or 8) or math.max(2, math.floor((r or 8) * 0.45))) }, o) end
local function addStroke(o, col, th, tr) return new("UIStroke", { Color = col or T.stroke, Thickness = th or 1, Transparency = tr or 0.2 }, o) end

-- ========== STATE ==========
S = {
    unloaded = false,
    fly = false, flySpeed = 50, noclip = false, flyUp = false, flyDown = false,
    cfSpeed = false, cfMult = 2, walk = 16, jump = 50, infJump = false, bhop = false,
    spin = false, spinSpeed = 20, god = false, tpTool = false, chams = false, chamsOp = 0.35,
    antiAFK = false, antiVoid = false, antiFall = false, antiFling = false, antiRagdoll = false,
    lowGrav = false, wallRun = false, freecam = false, fcSpeed = 50, spectate = nil,
    aimbot = false, aimFov = 90, smooth = 5, selected = nil, fovCircle = false, silent = false,
    autoShoot = false, wallcheck = false, aimPart = "Head", holdAim = false,
    hitbox = false, hitSize = 5, trigger = false,
    espBox = false, espTracer = false, espName = false, espDist = false, espHealth = false,
    skeleton = false, skelSelf = false, itemEsp = false, team = false,
    espColor = Color3.fromRGB(124, 92, 255), skelColor = Color3.fromRGB(124, 92, 255),
    dash = false, dashPower = 90, dashKey = Enum.KeyCode.Q, dashCd = 0.4, dashLast = 0,
    menuKey = Enum.KeyCode.RightShift, guiVisible = true,
    headless = false, korblox = false, lastPack = nil,
    fovOn = false, fovVal = 70, zoom = false, zoomKey = Enum.KeyCode.C, fovDefault = 70, fovTouched = false,
    crosshair = false, clickTP = false, autoClick = false, cps = 10, clickAcc = 0,
    fullbright = false, noFog = false, playerList = false,
    curTarget = nil, curPart = nil, curVisible = true, randPart = "Head",
    itemCache = {}, savedGravity = workspace.Gravity, lastSafe = nil,
    rainbow = false, emoteSpeed = 100, emoteLoop = false, aimMethod = "Camera", predict = 0, maxDist = 1000, espMax = 2000, espTool = false,
    sprint = false, sprintMult = 1.6, airWalk = false, airY = 0, silentRay = false, coords = false, autoRejoin = false, idSlot = "WalkAnim",
}
local binds = {}
local capturing = nil
local function waitKey(cb) capturing = cb end

local function getChar()
    local c = LocalPlayer.Character
    return c, c and c:FindFirstChild("HumanoidRootPart"), c and c:FindFirstChildOfClass("Humanoid")
end

local function enemy(plr)
    return not (S.team and plr.Team ~= nil and plr.Team == LocalPlayer.Team)
end

-- ========== NOTIFICATIONS ==========
local sfx = function() end
local notify
do
    local gui = new("ScreenGui", { Name = "WiaNotifs", ResetOnSpawn = false, DisplayOrder = 200 })
    parentGui(gui)
    local holder = new("Frame", { Size = UDim2.new(0, 270, 1, -20), Position = UDim2.new(1, -282, 0, 10), BackgroundTransparency = 1 }, gui)
    new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, holder)
    local order = 0
    notify = function(text, kind)
        if S.unloaded then return end
        order += 1
        sfx("note")
        local kids = holder:GetChildren()
        if #kids > 7 then for _, k in ipairs(kids) do if k:IsA("Frame") then k:Destroy() break end end end
        local col = kind == "error" and T.err or kind == "success" and T.ok or T.accent
        local f = new("Frame", { Size = UDim2.new(1, 0, 0, 46), BackgroundColor3 = T.note, Rotation = (order % 2 == 0) and 1.2 or -1.2, BorderSizePixel = 0, LayoutOrder = order, ClipsDescendants = true }, holder)
        addCorner(f, 10) addStroke(f)
        local a = new("Frame", { Size = UDim2.new(0, 3, 1, 0), BackgroundColor3 = col, BorderSizePixel = 0 }, f)
        local l = new("TextLabel", { Size = UDim2.new(1, -22, 1, 0), Position = UDim2.new(0, 14, 0, 0), BackgroundTransparency = 1, Text = text, TextColor3 = T.text, TextSize = 13, Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true }, f)
        local s = new("UIScale", { Scale = 0.85 }, f)
        TweenService:Create(s, TweenInfo.new(0.2, Enum.EasingStyle.Back), { Scale = 1 }):Play()
        task.delay(2.6, function()
            if not f.Parent then return end
            TweenService:Create(f, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
            TweenService:Create(l, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
            TweenService:Create(a, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
            task.wait(0.3)
            f:Destroy()
        end)
    end
end

-- ========== PAPER SOUNDS (генерируются в WAV и играются через getcustomasset) ==========
local SND = { enabled = true, vol = 0.6, sounds = {} }
do
    local RATE = 22050
    local function wav(samples)
        local parts = table.create(#samples)
        for i, x in ipairs(samples) do
            local v = math.floor(math.clamp(x, -1, 1) * 30000)
            if v < 0 then v += 65536 end
            parts[i] = string.char(v % 256, math.floor(v / 256))
        end
        local data = table.concat(parts)
        return "RIFF" .. string.pack("<I4", 36 + #data) .. "WAVEfmt " .. string.pack("<I4I2I2I4I4I2I2", 16, 1, 1, RATE, RATE * 2, 2, 16) .. "data" .. string.pack("<I4", #data) .. data
    end
    local DUR = { tap = 0.06, on = 0.07, off = 0.07, flip = 0.32, crumple = 0.42, note = 0.16 }
    local function synth(kind)
        local n = math.floor(DUR[kind] * RATE)
        local out = table.create(n)
        local rnd = Random.new(11)
        local lp, crack = 0, 0
        for i = 1, n do
            local t = i / RATE
            local noise = rnd:NextNumber() * 2 - 1
            local x = 0
            if kind == "tap" or kind == "on" or kind == "off" then
                local a = kind == "on" and 0.55 or kind == "off" and 0.2 or 0.38
                lp += a * (noise - lp)
                x = lp * math.exp(-t / 0.014) * 1.7
            elseif kind == "flip" then
                lp += 0.3 * (noise - lp)
                local env = math.min(1, t / 0.05) * math.exp(-math.max(0, t - 0.05) / 0.1)
                if rnd:NextNumber() < 0.006 then crack = rnd:NextNumber() * 1.2 + 0.3 end
                x = ((noise - lp) * 0.55 + crack) * env
                crack *= 0.7
            elseif kind == "crumple" then
                lp += 0.4 * (noise - lp)
                if rnd:NextNumber() < 0.03 then crack = (rnd:NextNumber() * 0.9 + 0.2) * (rnd:NextNumber() < 0.5 and -1 or 1) end
                x = (crack + (noise - lp) * 0.18) * math.exp(-t / 0.18)
                crack *= 0.82
            else
                lp += 0.5 * (noise - lp)
                local env = math.min(1, t / 0.01) * math.exp(-t / 0.05)
                x = ((noise - lp) * 0.9 + lp * 0.3) * env
            end
            out[i] = x * 0.8
        end
        return wav(out)
    end
    local FALLBACK = {
        tap = "rbxasset://sounds/clickfast.wav", on = "rbxasset://sounds/switch.wav", off = "rbxasset://sounds/clickfast.wav",
        flip = "rbxasset://sounds/snap.mp3", crumple = "rbxasset://sounds/snap.mp3", note = "rbxasset://sounds/clickfast.wav",
    }
    local gca = getcustomasset or getsynasset
    local folder = new("Folder", { Name = "WiaSounds" })
    pcall(function() folder.Parent = game:GetService("SoundService") end)
    SND.folder = folder
    task.spawn(function()
        for kind in pairs(DUR) do
            local id
            if writefile and gca then
                pcall(function()
                    local fname = "wia_paper_" .. kind .. ".wav"
                    if not (isfile and isfile(fname)) then writefile(fname, synth(kind)) end
                    id = gca(fname)
                end)
            end
            SND.sounds[kind] = new("Sound", { Name = kind, SoundId = id or FALLBACK[kind], Volume = 0.5 }, folder)
            SND.custom = SND.custom or id ~= nil
        end
    end)
    sfx = function(kind)
        if not SND.enabled or S.unloaded then return end
        local sd = SND.sounds[kind]
        if sd then
            sd.Volume = SND.vol
            sd.PlaybackSpeed = (kind == "off" and 0.85 or 1) * (0.94 + math.random() * 0.12)
            sd.TimePosition = 0
            sd:Play()
        end
    end
end

-- ========== DRAWING POOLS ==========
local function newPool(kind, init)
    local p = { items = {}, n = 0, last = 0 }
    function p.reset() p.n = 0 end
    function p.get()
        local n = p.n + 1
        p.n = n
        local o = p.items[n]
        if not o then
            o = Drawing.new(kind)
            if init then init(o) end
            p.items[n] = o
        end
        o.Visible = true
        return o
    end
    function p.finish()
        for i = p.n + 1, p.last do local o = p.items[i] if o then o.Visible = false end end
        p.last = p.n
    end
    function p.destroy()
        for _, o in ipairs(p.items) do pcall(function() o:Remove() end) end
        p.items = {}
    end
    return p
end
local poolL, poolT, poolS, fovCircle, crossLines
if hasDrawing then
    poolL = newPool("Line")
    poolS = newPool("Square", function(o) o.Filled = false o.Thickness = 1.5 end)
    poolT = newPool("Text", function(o) o.Size = 13 o.Center = true o.Outline = true end)
    fovCircle = Drawing.new("Circle")
    fovCircle.Thickness = 1 fovCircle.NumSides = 64 fovCircle.Filled = false fovCircle.Color = T.accent fovCircle.Visible = false
    S.fovRef = fovCircle
end

-- ========== ANIMATION PACKS ==========
local function P(w, r, j, f, si, s, c, a1, a2)
    return { WalkAnim = w, RunAnim = r, JumpAnim = j, FallAnim = f, SwimIdle = si, Swim = s, ClimbAnim = c, Animation1 = a1, Animation2 = a2 }
end
local function Q(r, w, j, f, s, si, c, idle)
    return { Run = r, Walk = w, Jump = j, Fall = f, Swim = s, SwimIdle = si, Climb = c, Idle = idle }
end
local PACKS = {
    ["Adidas Sports"] = P(18537392113, 18537384940, 18537380791, 18537367238, 18537387180, 18537389531, 18537363391, 18537376492, 18537371272),
    ["Adidas Community"] = P(122150855457006, 82598234841035, 75290611992385, 98600215928904, 109346520324160, 133308483266208, 88763136693023, 122257458498464, 102357151005774),
    ["Adidas Aura"] = P(83842218823011, 118320322718866, 109996626521204, 95603166884636, 94922130551805, 134530128383903, 97824616490448, 110211186840347, 114191137265065),
    ["Wicked Popular"] = P(92072849924640, 72301599441680, 104325245285198, 121152442762481, 113199415118199, 99384245425157, 131326830509784, 118832222982049, 76049494037641),
    Elder = P(10921111375, 10921104374, 10921107367, 10921105765, 10921110146, 10921108971, 10921100400, 10921101664, 10921102574),
    Zombie = P(10921355261, 616163682, 10921351278, 10921350320, 10921353442, 10921352344, 10921343576, 10921344533, 10921345304),
    Mage = P(10921152678, 10921148209, 10921149743, 10921148939, 10921151661, 10921150788, 10921143404, 10921144709, 10921145797),
    ["Catwalk Glam"] = P(109168724482748, 81024476153754, 116936326516985, 92294537340807, 98854111361360, 134591743181628, 119377220967554, 133806214992291, 94970088341563),
    Astronaut = P(10921046031, 10921039308, 10921042494, 10921040576, 10921045006, 10921044000, 10921032124, 10921034824, 10921036806),
    ['Wicked "Dancing Through Life"'] = P(73718308412641, 135515454877967, 78508480717326, 78147885297412, 129183123083281, 110657013921774, 129447497744818, 92849173543269, 132238900951109),
    Werewolf = P(10921342074, 10921336997, nil, 10921337907, 10921341319, 10921340419, 10921329322, 10921330408, 10921333667),
    Superhero = P(10921298616, 10921291831, 10921294559, 10921293373, 10921297391, 10921295495, 10921286911, 10921288909, 10921290167),
    Toy = P(10921312010, 10921306285, 10921308158, 10921307241, 10921310341, 10921309319, 10921300839, 10921301576, nil),
    ["No Boundaries"] = P(18747074203, 18747070484, 18747069148, 18747062535, 18747071682, 18747073181, 18747060903, 18747067405, 18747063918),
    NFL = P(110358958299415, 117333533048078, 119846112151352, 129773241321032, 79090109939093, 132697394189921, 134630013742019, 92080889861410, 74451233229259),
    ["Amazon Unboxed"] = P(90478085024465, 134824450619865, 121454505477205, 94788218468396, 129126268464847, 105962919001086, 121145883950231, 98281136301627, nil),
    Vampire = P(10921326949, 10921320299, 10921322186, 10921321317, 10921325443, 10921324408, 10921314188, 10921315373, nil),
    Ninja = Q(656118852, 656121766, 656117878, 656115606, 656119721, 656121397, 656114359, { 656117400, 656118341, 886742569 }),
    Robot = Q(616091570, 616095330, 616090535, 616087089, 616092998, 616094091, 616086039, { 616088211, 616089559, 885531463 }),
    Levitation = Q(616010382, 616013216, 616008936, 616005863, 616011509, 616012453, 616003713, { 616006778, 616008087, 886862142 }),
    Stylish = Q(616140816, 616146177, 616139451, 616134815, 616143378, 616144772, 616133594, { 616136790, 616138447, 886888594 }),
    Bubbly = Q(910025107, 910034870, 910016857, 910001910, 910028158, 910030921, 909997997, { 910004836, 910009958, 1018536639 }),
    Cartoon = Q(742638842, 742640026, 742637942, 742637151, 742639220, 742639812, 742636889, { 742637544, 742638445, 885477856 }),
}

local applyPack
do
    local applying = false
    local function waitForAnimate(char)
        for _ = 1, 40 do
            local a = char:FindFirstChild("Animate")
            if a and a:FindFirstChild("idle") and a:FindFirstChild("run") and a:FindFirstChild("walk") then return a end
            task.wait(0.1)
        end
    end
    local function setAnim(o, id) if o and id then o.AnimationId = "rbxassetid://" .. tostring(id) end end
    local function ensureAnim(folder, name)
        if not folder then return nil end
        local a = folder:FindFirstChild(name)
        if not a then a = Instance.new("Animation") a.Name = name a.Parent = folder end
        return a
    end
    local function pick(pack, ...)
        for i = 1, select("#", ...) do
            local v = pack[select(i, ...)]
            if v ~= nil then return v end
        end
    end
    local function inner(packName, silent)
        local pack = PACKS[packName]
        if not pack then return false end
        local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
        local animate = waitForAnimate(char)
        if not animate then notify("Animate не найден", "error") return false end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then for _, t in ipairs(hum:GetPlayingAnimationTracks()) do pcall(function() t:Stop(0) end) end end
        setAnim(ensureAnim(animate:FindFirstChild("walk"), "WalkAnim"), pick(pack, "WalkAnim", "Walk"))
        setAnim(ensureAnim(animate:FindFirstChild("run"), "RunAnim"), pick(pack, "RunAnim", "Run"))
        setAnim(ensureAnim(animate:FindFirstChild("jump"), "JumpAnim"), pick(pack, "JumpAnim", "Jump"))
        setAnim(ensureAnim(animate:FindFirstChild("fall"), "FallAnim"), pick(pack, "FallAnim", "Fall"))
        setAnim(ensureAnim(animate:FindFirstChild("climb"), "ClimbAnim"), pick(pack, "ClimbAnim", "Climb"))
        setAnim(ensureAnim(animate:FindFirstChild("swim"), "Swim"), pick(pack, "Swim"))
        setAnim(ensureAnim(animate:FindFirstChild("swimidle"), "SwimIdle"), pick(pack, "SwimIdle") or pick(pack, "Swim"))
        local idle = animate:FindFirstChild("idle")
        if idle then
            local a1, a2 = pick(pack, "Animation1"), pick(pack, "Animation2")
            if a1 or a2 then
                for i = 1, 2 do ensureAnim(idle, "Animation" .. i) end
                setAnim(idle:FindFirstChild("Animation1"), a1 or a2)
                setAnim(idle:FindFirstChild("Animation2"), a2 or a1)
            elseif pack.Idle and #pack.Idle > 0 then
                for i = 1, math.max(2, #pack.Idle) do ensureAnim(idle, "Animation" .. i) end
                setAnim(idle:FindFirstChild("Animation1"), pack.Idle[1])
                setAnim(idle:FindFirstChild("Animation2"), pack.Idle[2] or pack.Idle[1])
                for i = 3, #pack.Idle do setAnim(idle:FindFirstChild("Animation" .. i), pack.Idle[i]) end
            end
        end
        animate.Disabled = true
        task.wait(0.06)
        animate.Disabled = false
        if hum then
            pcall(function()
                hum:ChangeState(Enum.HumanoidStateType.Landed)
                task.wait(0.03)
                hum:ChangeState(Enum.HumanoidStateType.Running)
            end)
        end
        S.lastPack = packName
        if not silent then notify("Анимация: " .. packName, "success") end
        return true
    end
    applyPack = function(packName, silent)
        if applying then return false end
        applying = true
        local ok, res = pcall(inner, packName, silent)
        applying = false
        return ok and res
    end
end

-- ========== COSMETICS ==========
local function applyHeadless()
    local char = LocalPlayer.Character
    local head = char and char:FindFirstChild("Head")
    if not head then return end
    head.Transparency = 1
    head.CanCollide = false
    for _, v in ipairs(head:GetChildren()) do if v:IsA("Decal") then v:Destroy() end end
    local mesh = head:FindFirstChildOfClass("SpecialMesh") or Instance.new("SpecialMesh", head)
    mesh.MeshType = Enum.MeshType.FileMesh
    mesh.MeshId = "rbxassetid://1095708"
    mesh.Scale = Vector3.new(0.001, 0.001, 0.001)
end

local function applyKorblox()
    local char = LocalPlayer.Character
    if not char then return end
    local DARK = Color3.fromRGB(64, 64, 64)
    local function mk(parent)
        for _, c in ipairs(parent:GetChildren()) do
            if c:IsA("SpecialMesh") or c:IsA("CharacterMesh") then c:Destroy() end
        end
        local m = Instance.new("SpecialMesh")
        m.MeshType = Enum.MeshType.FileMesh
        m.MeshId = "rbxassetid://139607718"
        m.TextureId = "rbxassetid://139607389"
        m.Scale = Vector3.new(1, 1, 1)
        m.Parent = parent
        parent.Color = DARK
    end
    local upper, lower, foot = char:FindFirstChild("RightUpperLeg"), char:FindFirstChild("RightLowerLeg"), char:FindFirstChild("RightFoot")
    if upper and lower and foot then
        mk(upper) lower.Transparency = 1 foot.Transparency = 1
        return
    end
    local leg = char:FindFirstChild("Right Leg")
    if leg then mk(leg) end
end

local function removeCosmetics()
    local char = LocalPlayer.Character
    if not char then return end
    local head = char:FindFirstChild("Head")
    if head then
        head.Transparency = 0
        local m = head:FindFirstChildOfClass("SpecialMesh")
        if m and m.MeshId == "rbxassetid://1095708" then m:Destroy() end
    end
    for _, name in ipairs({ "RightUpperLeg", "RightLowerLeg", "RightFoot", "Right Leg" }) do
        local p = char:FindFirstChild(name)
        if p then
            for _, c in ipairs(p:GetChildren()) do
                if c:IsA("SpecialMesh") and c.MeshId == "rbxassetid://139607718" then c:Destroy() end
            end
            if name == "RightLowerLeg" or name == "RightFoot" then p.Transparency = 0 end
        end
    end
end

-- ========== WATERMARK ==========
local WmGui, WmStats = new("ScreenGui", { Name = "WiaWm", ResetOnSpawn = false, DisplayOrder = 50 })
parentGui(WmGui)
do
    local Wm = new("Frame", { Size = UDim2.new(0, 300, 0, 44), Position = UDim2.new(0, 12, 0, 12), BackgroundColor3 = T.panel, BackgroundTransparency = 0.12, BorderSizePixel = 0 }, WmGui)
    addCorner(Wm, 10) addStroke(Wm)
    local acc = new("Frame", { Size = UDim2.new(0, 3, 1, 0), BorderSizePixel = 0 }, Wm)
    ref(acc, "BackgroundColor3") addCorner(acc, 2)
    new("TextLabel", { Size = UDim2.new(1, -20, 0, 20), Position = UDim2.new(0, 14, 0, 4), BackgroundTransparency = 1, Text = "WIA HUB v14", TextColor3 = T.text, TextSize = 13, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left }, Wm)
    WmStats = new("TextLabel", { Size = UDim2.new(1, -20, 0, 16), Position = UDim2.new(0, 14, 0, 23), BackgroundTransparency = 1, Text = "60 FPS  ·  0 ms  ·  " .. LocalPlayer.Name, TextColor3 = T.dim, TextSize = 11, Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left }, Wm)
end

-- ========== DRAG ==========
local function makeDraggable(frame, handle)
    handle = handle or frame
    local dragging, dragInput, dragStart, startPos = false, nil, nil, nil
    bind(handle.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging, dragStart, startPos = true, input.Position, frame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    bind(handle.InputChanged, function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then dragInput = input end
    end)
    bind(UserInputService.InputChanged, function(input)
        if dragging and input == dragInput then
            local d = input.Position - dragStart
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
end

-- ========== MAIN GUI ==========
local ScreenGui = new("ScreenGui", { Name = "WiaHubGUI", ResetOnSpawn = false })
parentGui(ScreenGui)

local Main, TabBar, PageHolder, StatusBar, Underline, MainScale, SearchFrame
do
    local vp0 = Camera.ViewportSize
    local w, h = math.clamp(vp0.X - 20, 260, 360), math.clamp(vp0.Y - 40, 260, 520)
    Main = new("Frame", { Size = UDim2.new(0, w, 0, h), Position = UDim2.new(0, 12, 0, 64), BackgroundColor3 = T.bg, BackgroundTransparency = 0.04, BorderSizePixel = 0, ClipsDescendants = true }, ScreenGui)
    addCorner(Main, 12) addStroke(Main, T.stroke, 1.5, 0)
    MainScale = new("UIScale", { Scale = 1 }, Main)
    local shadow = new("Frame", { BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.8, BorderSizePixel = 0, ZIndex = 0 }, ScreenGui)
    addCorner(shadow, 12)
    local shScale = new("UIScale", {}, shadow)
    local function syncShadow()
        shadow.Size = Main.Size
        shadow.Position = UDim2.new(Main.Position.X.Scale, Main.Position.X.Offset + 5, Main.Position.Y.Scale, Main.Position.Y.Offset + 6)
        shScale.Scale = MainScale.Scale
    end
    syncShadow()
    Main:GetPropertyChangedSignal("Position"):Connect(syncShadow)
    Main:GetPropertyChangedSignal("Size"):Connect(syncShadow)
    MainScale:GetPropertyChangedSignal("Scale"):Connect(syncShadow)
    local margin = new("Frame", { Size = UDim2.new(0, 2, 1, -44), Position = UDim2.new(0, 22, 0, 42), BackgroundColor3 = Color3.fromRGB(222, 130, 125), BackgroundTransparency = 0.4, BorderSizePixel = 0, ZIndex = 0 }, Main)
    local tape1 = new("Frame", { Size = UDim2.new(0, 58, 0, 16), Position = UDim2.new(0, -16, 0, 6), Rotation = -38, BackgroundColor3 = Color3.fromRGB(238, 214, 120), BackgroundTransparency = 0.2, BorderSizePixel = 0, ZIndex = 6 }, Main)
    local tape2 = new("Frame", { Size = UDim2.new(0, 58, 0, 16), Position = UDim2.new(1, -44, 1, -22), Rotation = -38, BackgroundColor3 = Color3.fromRGB(238, 214, 120), BackgroundTransparency = 0.2, BorderSizePixel = 0, ZIndex = 6 }, Main)
    S.decor = { shadow, margin, tape1, tape2 }

    local top = new("Frame", { Size = UDim2.new(1, 0, 0, 3), BorderSizePixel = 0 }, Main)
    ref(top, "BackgroundColor3")
    new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 0.7) }) }, top)

    local Title = new("TextLabel", { Size = UDim2.new(0, 80, 0, 34), Position = UDim2.new(0, 14, 0, 3), Text = "WIA HUB", TextColor3 = T.text, TextSize = 16, TextXAlignment = Enum.TextXAlignment.Left, BackgroundTransparency = 1, Font = Enum.Font.GothamBold }, Main)
    local ver = new("TextLabel", { Size = UDim2.new(0, 60, 0, 34), Position = UDim2.new(0, 88, 0, 3), Text = "v14 PAPER", TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, BackgroundTransparency = 1, Font = Enum.Font.GothamBold }, Main)
    ref(ver, "TextColor3")
    local drag = new("Frame", { Size = UDim2.new(1, -90, 0, 36), Position = UDim2.new(0, 0, 0, 3), BackgroundTransparency = 1 }, Main)
    makeDraggable(Main, drag)
    Title.ZIndex, ver.ZIndex = 2, 2

    Underline = new("Frame", { Size = UDim2.new(1, -24, 0, 1), Position = UDim2.new(0, 12, 0, 38), BackgroundColor3 = T.stroke, BorderSizePixel = 0 }, Main)

    local function headBtn(txt, x)
        local b = new("TextButton", { Size = UDim2.new(0, 26, 0, 24), Position = UDim2.new(1, x, 0, 8), Text = txt, TextColor3 = T.dim, BackgroundColor3 = T.row, BorderSizePixel = 0, Font = Enum.Font.GothamBold, TextSize = 14, ZIndex = 5 }, Main)
        addCorner(b, 6)
        return b
    end
    local MinBtn = headBtn("—", -62)
    local CloseBtn = headBtn("✕", -32)

    TabBar = new("ScrollingFrame", { Size = UDim2.new(1, -12, 0, 30), Position = UDim2.new(0, 6, 0, 43), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 0, ScrollingDirection = Enum.ScrollingDirection.X, AutomaticCanvasSize = Enum.AutomaticSize.X, CanvasSize = UDim2.new(0, 0, 0, 0) }, Main)
    new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, TabBar)

    PageHolder = new("Frame", { Size = UDim2.new(1, 0, 1, -140), Position = UDim2.new(0, 0, 0, 114), BackgroundTransparency = 1, ClipsDescendants = true }, Main)
    StatusBar = new("TextLabel", { Size = UDim2.new(1, -20, 0, 20), Position = UDim2.new(0, 12, 1, -22), Text = "Ready · " .. S.menuKey.Name .. " — скрыть меню", TextColor3 = T.dim, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, BackgroundTransparency = 1, Font = Enum.Font.Gotham }, Main)

    local minimized, fullSize = false, Main.Size
    MinBtn.MouseButton1Click:Connect(function()
        sfx("flip")
        minimized = not minimized
        if minimized then
            fullSize = Main.Size
            TabBar.Visible, PageHolder.Visible, StatusBar.Visible, Underline.Visible = false, false, false, false
            if SearchFrame then SearchFrame.Visible = false end
            Main.Size = UDim2.new(0, fullSize.X.Offset, 0, 40)
            MinBtn.Text = "+"
        else
            Main.Size = fullSize
            TabBar.Visible, PageHolder.Visible, StatusBar.Visible, Underline.Visible = true, true, true, true
            if SearchFrame then SearchFrame.Visible = true end
            MinBtn.Text = "—"
        end
    end)
    CloseBtn.MouseButton1Click:Connect(function()
        sfx("crumple")
        S.guiVisible = false
        ScreenGui.Enabled = false
    end)
end

-- ========== TABS ==========
local tabs, currentPage, currentTab, activeTab, tabCount = {}, nil, nil, nil, 0
local function selectTab(name)
    activeTab = name
    for n, t in pairs(tabs) do
        local on = (n == name)
        TweenService:Create(t.btn, TweenInfo.new(0.15), { BackgroundColor3 = on and T.accent or T.row, TextColor3 = on and T.onAccent or T.dim }):Play()
        t.page.Visible = on
    end
end
local function createTab(name)
    tabCount += 1
    local btn = new("TextButton", { Size = UDim2.new(0, math.max(58, #name * 8 + 22), 1, 0), Text = name, TextSize = 12, Font = Enum.Font.GothamBold, BackgroundColor3 = T.row, TextColor3 = T.dim, BorderSizePixel = 0, AutoButtonColor = false, LayoutOrder = tabCount }, TabBar)
    addCorner(btn, 8)
    local page = new("ScrollingFrame", { Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3, ScrollBarImageColor3 = T.accent, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(0, 0, 0, 0), Visible = false }, PageHolder)
    ref(page, "ScrollBarImageColor3")
    new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, page)
    new("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 10) }, page)
    tabs[name] = { btn = btn, page = page }
    btn.MouseButton1Click:Connect(function() sfx("flip") selectTab(name) end)
    currentPage, currentTab = page, name
    if tabCount == 1 then selectTab(name) end
    return page
end

-- ========== FLY BUTTONS ==========
local FlyGui = new("ScreenGui", { Name = "WiaFly", ResetOnSpawn = false, Enabled = false })
parentGui(FlyGui)
do
    local function mk(text, pos, key)
        local b = new("TextButton", { Size = UDim2.new(0, 52, 0, 52), Position = pos, Text = text, TextColor3 = T.onAccent, TextSize = 20, Font = Enum.Font.GothamBold, BackgroundTransparency = 0.2, BorderSizePixel = 0 }, FlyGui)
        ref(b, "BackgroundColor3") addCorner(b, 26, true)
        b.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
                S[key] = true
                input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then S[key] = false end end)
            end
        end)
        b.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then S[key] = false end
        end)
    end
    mk("▲", UDim2.new(1, -74, 0.5, -66), "flyUp")
    mk("▼", UDim2.new(1, -74, 0.5, 0), "flyDown")
end

-- ========== UI FACTORY ==========
local elements, cfgReg = {}, {}
local function register(obj, name) elements[#elements + 1] = { obj = obj, name = name, tab = currentTab } end

local function createSection(text)
    local lbl = new("TextLabel", { Size = UDim2.new(1, 0, 0, 20), Text = "» " .. string.upper(text), TextColor3 = T.dim, TextSize = 10, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left, BackgroundTransparency = 1 }, currentPage)
    register(lbl, text)
    return lbl
end

local function hover(row)
    row.MouseEnter:Connect(function() TweenService:Create(row, TweenInfo.new(0.1), { BackgroundColor3 = T.rowh }):Play() end)
    row.MouseLeave:Connect(function() TweenService:Create(row, TweenInfo.new(0.1), { BackgroundColor3 = T.row }):Play() end)
end

local function createTumbler(label, default, opts)
    opts = opts or {}
    local bindable = opts.bindable ~= false
    local row = new("TextButton", { Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = T.row, BorderSizePixel = 0, AutoButtonColor = false, Text = "" }, currentPage)
    addCorner(row, 8) hover(row)
    new("TextLabel", { Size = UDim2.new(1, bindable and -158 or -70, 1, 0), Position = UDim2.new(0, 12, 0, 0), Text = label, TextColor3 = T.text, TextSize = 13, BackgroundTransparency = 1, Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd }, row)
    local state = default or false
    local pill = new("Frame", { Size = UDim2.new(0, 40, 0, 22), Position = bindable and UDim2.new(1, -118, 0.5, -11) or UDim2.new(1, -52, 0.5, -11), BorderSizePixel = 0 }, row)
    ref(pill, "BackgroundColor3", function() return state and T.accent or T.rowd end)
    addCorner(pill, 11, true)
    local knob = new("Frame", { Size = UDim2.new(0, 16, 0, 16), BorderSizePixel = 0 }, pill)
    addCorner(knob, 8, true)
    local function update(instant)
        local kp = state and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)
        local pc = state and T.accent or T.rowd
        local kc = state and T.onAccent or T.dim
        if instant then
            knob.Position, pill.BackgroundColor3, knob.BackgroundColor3 = kp, pc, kc
        else
            local ti = TweenInfo.new(0.12)
            TweenService:Create(knob, ti, { Position = kp, BackgroundColor3 = kc }):Play()
            TweenService:Create(pill, ti, { BackgroundColor3 = pc }):Play()
        end
    end
    update(true)

    local self, cbs = { key = nil }, {}
    local function fire() for _, cb in ipairs(cbs) do task.spawn(cb, state) end end
    self.toggle = function() state = not state sfx(state and "on" or "off") update() fire() end
    self.getState = function() return state end
    self.setState = function(n) state = n and true or false update() fire() end
    self.onToggle = function(cb) cbs[#cbs + 1] = cb return self end
    row.MouseButton1Click:Connect(self.toggle)

    if bindable then
        local bindBtn = new("TextButton", { Size = UDim2.new(0, 38, 0, 22), Position = UDim2.new(1, -74, 0.5, -11), Text = "⌨", TextColor3 = T.dim, BackgroundColor3 = T.rowd, TextSize = 10, Font = Enum.Font.GothamBold, BorderSizePixel = 0, TextTruncate = Enum.TextTruncate.AtEnd }, row)
        addCorner(bindBtn, 6)
        local resetBtn = new("TextButton", { Size = UDim2.new(0, 26, 0, 22), Position = UDim2.new(1, -32, 0.5, -11), Text = "✕", TextColor3 = T.dim, BackgroundColor3 = T.rowd, TextSize = 11, Font = Enum.Font.GothamBold, BorderSizePixel = 0 }, row)
        addCorner(resetBtn, 6)
        local function refreshBind()
            bindBtn.Text = self.key and self.key.Name or "⌨"
            bindBtn.BackgroundColor3 = self.key and Color3.fromRGB(196, 224, 190) or T.rowd
        end
        self.refreshBind = refreshBind
        bindBtn.MouseButton1Click:Connect(function()
            if capturing then capturing = nil refreshBind() return end
            bindBtn.Text = "..."
            bindBtn.BackgroundColor3 = T.accent
            waitKey(function(kc)
                self.key = kc ~= Enum.KeyCode.Escape and kc or nil
                refreshBind()
                if self.key then notify("Bind: " .. label .. " = " .. self.key.Name, "success") end
            end)
        end)
        resetBtn.MouseButton1Click:Connect(function() capturing = nil self.key = nil refreshBind() end)
        binds[#binds + 1] = self
    end

    register(row, label)
    if opts.cfg ~= false then
        cfgReg[currentTab .. "/" .. label] = {
            get = function() return { s = state, k = self.key and self.key.Name or nil } end,
            set = function(v)
                if type(v) ~= "table" then return end
                self.key = v.k and Enum.KeyCode[v.k] or nil
                if self.refreshBind then self.refreshBind() end
                self.setState(v.s)
            end,
        }
    end
    return self
end

local activeSlider = nil
bind(UserInputService.InputChanged, function(input)
    if activeSlider and (input == activeSlider.input or input.UserInputType == Enum.UserInputType.MouseMovement) then
        activeSlider.apply(input.Position.X)
    end
end)

local function createSlider(label, minV, maxV, default, callback)
    local page = currentPage
    local row = new("Frame", { Size = UDim2.new(1, 0, 0, 56), BackgroundColor3 = T.row, BorderSizePixel = 0 }, page)
    addCorner(row, 8)
    new("TextLabel", { Size = UDim2.new(1, -90, 0, 30), Position = UDim2.new(0, 12, 0, 2), Text = label, TextColor3 = T.text, TextSize = 13, BackgroundTransparency = 1, Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left }, row)
    local textBox = new("TextBox", { Size = UDim2.new(0, 56, 0, 24), Position = UDim2.new(1, -68, 0, 6), Text = tostring(default), TextColor3 = T.text, BackgroundColor3 = T.rowd, BorderSizePixel = 0, Font = Enum.Font.Gotham, TextSize = 12, ClearTextOnFocus = false }, row)
    addCorner(textBox, 6)
    local track = new("Frame", { Size = UDim2.new(1, -28, 0, 4), Position = UDim2.new(0, 14, 0, 44), BackgroundColor3 = T.rowd, BorderSizePixel = 0 }, row)
    addCorner(track, 2)
    local fill = new("Frame", { Size = UDim2.new(0, 0, 1, 0), BorderSizePixel = 0 }, track)
    ref(fill, "BackgroundColor3") addCorner(fill, 2)
    local knob = new("Frame", { Size = UDim2.new(0, 14, 0, 14), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 0, 0.5, 0), BackgroundColor3 = T.onAccent, BorderSizePixel = 0, ZIndex = 2 }, track)
    addCorner(knob, 7, true) addStroke(knob, T.accent, 2, 0)
    local hit = new("TextButton", { Size = UDim2.new(1, 0, 0, 26), Position = UDim2.new(0, 0, 0, 32), BackgroundTransparency = 1, Text = "" }, row)

    local value = default
    local function setVisual(v)
        local a = math.clamp((v - minV) / (maxV - minV), 0, 1)
        fill.Size = UDim2.new(a, 0, 1, 0)
        knob.Position = UDim2.new(a, 0, 0.5, 0)
        textBox.Text = tostring(v)
    end
    setVisual(value)
    local function applyFromX(x)
        local a = math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
        local v = math.floor(minV + a * (maxV - minV) + 0.5)
        setVisual(v)
        if v ~= value then value = v callback(v) end
    end
    hit.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            activeSlider = { apply = applyFromX, input = input }
            page.ScrollingEnabled = false
            applyFromX(input.Position.X)
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    if activeSlider and activeSlider.input == input then activeSlider = nil end
                    page.ScrollingEnabled = true
                end
            end)
        end
    end)
    textBox.FocusLost:Connect(function()
        local num = tonumber(textBox.Text)
        if num then
            num = math.floor(math.clamp(num, minV, maxV) + 0.5)
            value = num setVisual(num) callback(num)
        else setVisual(value) end
    end)
    register(row, label)
    cfgReg[currentTab .. "/" .. label] = { get = function() return value end, set = function(v) if type(v) == "number" then value = v setVisual(v) callback(v) end end }
    return { setValue = function(v) value = v setVisual(v) end }
end

local function createButton(text, callback)
    local btn = new("TextButton", { Size = UDim2.new(1, 0, 0, 36), Text = text, TextColor3 = T.text, BackgroundColor3 = T.row, BorderSizePixel = 0, Font = Enum.Font.GothamBold, TextSize = 13 }, currentPage)
    addCorner(btn, 8) hover(btn)
    local scale = new("UIScale", {}, btn)
    btn.MouseButton1Down:Connect(function() TweenService:Create(scale, TweenInfo.new(0.08), { Scale = 0.96 }):Play() end)
    btn.MouseButton1Up:Connect(function() TweenService:Create(scale, TweenInfo.new(0.12, Enum.EasingStyle.Back), { Scale = 1 }):Play() end)
    btn.MouseButton1Click:Connect(function() sfx("tap") callback(btn) end)
    register(btn, text)
    return btn
end

-- options = { {name, value}, ... }
local function createSelector(label, options, defaultIdx, cb)
    local idx = defaultIdx or 1
    local row = new("TextButton", { Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = T.row, BorderSizePixel = 0, AutoButtonColor = false, Text = "" }, currentPage)
    addCorner(row, 8) hover(row)
    new("TextLabel", { Size = UDim2.new(1, -130, 1, 0), Position = UDim2.new(0, 12, 0, 0), Text = label, TextColor3 = T.text, TextSize = 13, BackgroundTransparency = 1, Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd }, row)
    local val = new("TextLabel", { Size = UDim2.new(0, 112, 1, 0), Position = UDim2.new(1, -120, 0, 0), BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Right }, row)
    ref(val, "TextColor3")
    local function set(i, fire)
        idx = ((i - 1) % #options) + 1
        val.Text = options[idx][1] .. "  ›"
        if fire then cb(options[idx][2], idx) end
    end
    set(idx, false)
    row.MouseButton1Click:Connect(function() sfx("tap") set(idx + 1, true) end)
    register(row, label)
    cfgReg[currentTab .. "/" .. label] = { get = function() return idx end, set = function(v) if type(v) == "number" then set(v, true) end end }
    return { set = set }
end

local function createInputRow(label, placeholder, btnText, cb)
    local row = new("Frame", { Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = T.row, BorderSizePixel = 0 }, currentPage)
    addCorner(row, 8)
    local box = new("TextBox", { Size = UDim2.new(1, -96, 0, 28), Position = UDim2.new(0, 8, 0.5, -14), BackgroundColor3 = T.rowd, BorderSizePixel = 0, Text = "", PlaceholderText = placeholder, PlaceholderColor3 = T.dim, TextColor3 = T.text, TextSize = 12, Font = Enum.Font.Gotham, ClearTextOnFocus = false, TextXAlignment = Enum.TextXAlignment.Left }, row)
    addCorner(box, 6)
    new("UIPadding", { PaddingLeft = UDim.new(0, 6) }, box)
    local b = new("TextButton", { Size = UDim2.new(0, 76, 0, 28), Position = UDim2.new(1, -84, 0.5, -14), Text = btnText, TextColor3 = T.onAccent, TextSize = 12, Font = Enum.Font.GothamBold, BorderSizePixel = 0 }, row)
    ref(b, "BackgroundColor3") addCorner(b, 6)
    b.MouseButton1Click:Connect(function() sfx("tap") cb(trim(box.Text)) end)
    box.FocusLost:Connect(function(enter) if enter then cb(trim(box.Text)) end end)
    register(row, label)
    return box
end

-- ========== BROWSER (reusable pooled list: no lag) ==========
local PAGE = 40
local function createBrowser(opts)
    local panel = new("Frame", { Size = UDim2.new(1, 0, 0, 350), BackgroundTransparency = 1, BorderSizePixel = 0 }, currentPage)
    local search = new("TextBox", { Size = UDim2.new(1, -76, 0, 32), BackgroundColor3 = T.row, BorderSizePixel = 0, ClearTextOnFocus = false, PlaceholderText = opts.placeholder or "Search...", Text = "", TextColor3 = T.text, PlaceholderColor3 = T.dim, TextSize = 12, Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left }, panel)
    addCorner(search, 8)
    new("UIPadding", { PaddingLeft = UDim.new(0, 9), PaddingRight = UDim.new(0, 6) }, search)
    local sbtn = new("TextButton", { Size = UDim2.new(0, 68, 0, 32), Position = UDim2.new(1, -68, 0, 0), Text = "Search", TextColor3 = T.onAccent, TextSize = 11, Font = Enum.Font.GothamBold, BorderSizePixel = 0 }, panel)
    ref(sbtn, "BackgroundColor3") addCorner(sbtn, 8)

    local B = { items = {}, page = 1, mode = nil, remote = false }
    local yRes = 0 + 39
    local modeBtns = {}
    if opts.modes then
        local mrow = new("Frame", { Size = UDim2.new(1, 0, 0, 28), Position = UDim2.new(0, 0, 0, 39), BackgroundTransparency = 1 }, panel)
        local n = #opts.modes
        for i, m in ipairs(opts.modes) do
            local b = new("TextButton", { Size = UDim2.new(1 / n, -4, 1, 0), Position = UDim2.new((i - 1) / n, i == 1 and 0 or 4, 0, 0), Text = m[2], TextColor3 = T.text, TextSize = 11, Font = Enum.Font.GothamBold, BackgroundColor3 = T.row, BorderSizePixel = 0, AutoButtonColor = false }, mrow)
            addCorner(b, 7)
            modeBtns[m[1]] = b
        end
        B.mode = opts.modes[1][1]
        yRes = 74
    end
    local results = new("ScrollingFrame", { Size = UDim2.new(1, 0, 0, 292 - yRes), Position = UDim2.new(0, 0, 0, yRes), BackgroundColor3 = T.panel, BackgroundTransparency = 0.15, BorderSizePixel = 0, ScrollBarThickness = 3, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(0, 0, 0, 0) }, panel)
    ref(results, "ScrollBarImageColor3") addCorner(results, 8)
    new("UIPadding", { PaddingTop = UDim.new(0, 5), PaddingBottom = UDim.new(0, 5), PaddingLeft = UDim.new(0, 5), PaddingRight = UDim.new(0, 5) }, results)
    new("UIListLayout", { Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder }, results)

    local function nav(text, pos)
        local b = new("TextButton", { Size = UDim2.new(0, 84, 0, 26), Position = pos, Text = text, TextColor3 = T.text, TextSize = 10, Font = Enum.Font.GothamBold, BackgroundColor3 = T.row, BorderSizePixel = 0, Visible = false }, panel)
        addCorner(b, 7)
        return b
    end
    local prev, nextB = nav("Previous", UDim2.new(0, 0, 0, 298)), nav("Next", UDim2.new(1, -84, 0, 298))
    local pageLbl = new("TextLabel", { Size = UDim2.new(1, -176, 0, 26), Position = UDim2.new(0, 88, 0, 298), BackgroundTransparency = 1, Text = "", TextColor3 = T.dim, TextSize = 10, Font = Enum.Font.Gotham }, panel)
    local status = new("TextLabel", { Size = UDim2.new(1, -2, 0, 18), Position = UDim2.new(0, 1, 0, 329), BackgroundTransparency = 1, Text = "", TextColor3 = T.dim, TextSize = 10, Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd }, panel)

    local rows, handlers = {}, {}
    local function getRow(i)
        local r = rows[i]
        if r then return r end
        r = new("TextButton", { Size = UDim2.new(1, -2, 0, 32), BackgroundColor3 = T.row, BorderSizePixel = 0, TextColor3 = T.text, TextSize = 11, Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, LayoutOrder = i, Visible = false }, results)
        addCorner(r, 7)
        new("UIPadding", { PaddingLeft = UDim.new(0, 9), PaddingRight = UDim.new(0, 7) }, r)
        r.MouseButton1Click:Connect(function()
            local it = handlers[i]
            if it and opts.onClick then sfx("tap") opts.onClick(it, B.mode, B) end
        end)
        rows[i] = r
        return r
    end

    function B.query() return trim(search.Text) end
    function B.status(msg, col) status.Text = tostring(msg) status.TextColor3 = col or T.dim end
    function B.render()
        local total = #B.items
        local pages = math.max(1, math.ceil(total / PAGE))
        B.page = math.clamp(B.page, 1, pages)
        local from = (B.page - 1) * PAGE
        for i = 1, PAGE do
            local it = B.items[from + i]
            local r = getRow(i)
            if it then
                r.Text = "▶   " .. tostring(opts.label(it))
                handlers[i] = it
                r.Visible = true
            else
                handlers[i] = nil
                r.Visible = false
            end
        end
        results.CanvasPosition = Vector2.zero
        if not B.remote then
            prev.Visible = B.page > 1
            nextB.Visible = B.page < pages
            pageLbl.Text = total > 0 and (B.page .. " / " .. pages) or ""
        else
            pageLbl.Text = ""
        end
    end
    function B.setItems(items, reset)
        B.items = items
        if reset ~= false then B.page = 1 end
        B.render()
    end
    function B.setNav(p, n) prev.Visible, nextB.Visible = p, n end
    function B.setMode(m, silentCall)
        B.mode = m
        for k, b in pairs(modeBtns) do b.BackgroundColor3 = (k == m) and T.accent or T.row b.TextColor3 = (k == m) and T.onAccent or T.text end
        if not silentCall and opts.onMode then opts.onMode(m, B) end
    end
    for k, b in pairs(modeBtns) do b.MouseButton1Click:Connect(function() B.setMode(k) end) end
    if opts.modes then B.setMode(B.mode, true) end
    sbtn.MouseButton1Click:Connect(function() opts.onSearch(B.query(), B.mode, B) end)
    search.FocusLost:Connect(function(enter) if enter then opts.onSearch(B.query(), B.mode, B) end end)
    prev.MouseButton1Click:Connect(function()
        if B.remote then if opts.onPrev then opts.onPrev(B) end else B.page -= 1 B.render() end
    end)
    nextB.MouseButton1Click:Connect(function()
        if B.remote then if opts.onNext then opts.onNext(B) end else B.page += 1 B.render() end
    end)
    return B
end

-- ========== SEARCH BAR ==========
do
    SearchFrame = new("Frame", { Size = UDim2.new(1, -24, 0, 30), Position = UDim2.new(0, 12, 0, 77), BackgroundColor3 = T.row, BorderSizePixel = 0 }, Main)
    addCorner(SearchFrame, 8)
    local box = new("TextBox", { Size = UDim2.new(1, -44, 1, 0), Position = UDim2.new(0, 12, 0, 0), BackgroundTransparency = 1, Text = "", PlaceholderText = "🔍 Поиск функций...", TextColor3 = T.text, PlaceholderColor3 = T.dim, TextSize = 12, Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left, ClearTextOnFocus = false }, SearchFrame)
    local clear = new("TextButton", { Size = UDim2.new(0, 24, 0, 22), Position = UDim2.new(1, -30, 0, 4), Text = "✕", TextColor3 = T.dim, BackgroundColor3 = T.rowd, TextSize = 12, Font = Enum.Font.GothamBold, BorderSizePixel = 0 }, SearchFrame)
    addCorner(clear, 6)
    local function apply()
        local q = box.Text:lower()
        local firstTab, curHas
        for _, el in ipairs(elements) do
            local m = q == "" or el.name:lower():find(q, 1, true) ~= nil
            if el.obj.Parent then el.obj.Visible = m end
            if q ~= "" and m then
                firstTab = firstTab or el.tab
                if el.tab == activeTab then curHas = true end
            end
        end
        if q ~= "" and not curHas and firstTab then selectTab(firstTab) end
    end
    box:GetPropertyChangedSignal("Text"):Connect(apply)
    clear.MouseButton1Click:Connect(function() box.Text = "" end)
end

-- ========== FLIGHT ==========
local bodyVelocity, bodyGyro
local function stopFlight()
    if bodyVelocity then bodyVelocity:Destroy() bodyVelocity = nil end
    if bodyGyro then bodyGyro:Destroy() bodyGyro = nil end
    workspace.Gravity = S.savedGravity
    local _, _, hum = getChar()
    if hum then
        hum.PlatformStand = false
        pcall(function() hum:ChangeState(Enum.HumanoidStateType.GettingUp) end)
    end
end
local function startFlight()
    stopFlight()
    local _, root, hum = getChar()
    if not (root and hum) then return end
    S.savedGravity = workspace.Gravity
    workspace.Gravity = 0
    hum.PlatformStand = true
    bodyVelocity = new("BodyVelocity", { MaxForce = Vector3.new(1e6, 1e6, 1e6), Velocity = Vector3.zero }, root)
    bodyGyro = new("BodyGyro", { MaxTorque = Vector3.new(1e6, 1e6, 1e6), P = 9e4, CFrame = root.CFrame }, root)
end
local function flightStep()
    local _, root, hum = getChar()
    if not (root and hum) then return end
    if not bodyVelocity or not bodyVelocity.Parent or not bodyGyro or not bodyGyro.Parent then
        startFlight()
        if not bodyVelocity then return end
    end
    local md = hum.MoveDirection
    local look, right = Camera.CFrame.LookVector, Camera.CFrame.RightVector
    local move = Vector3.zero
    if md.Magnitude > 0.01 then
        local fl, fr = Vector3.new(look.X, 0, look.Z), Vector3.new(right.X, 0, right.Z)
        if fl.Magnitude > 0.01 and fr.Magnitude > 0.01 then move = look * md:Dot(fl.Unit) + right * md:Dot(fr.Unit) end
    end
    if S.flyUp or UserInputService:IsKeyDown(Enum.KeyCode.Space) then move += Vector3.yAxis end
    if S.flyDown or UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then move -= Vector3.yAxis end
    if move.Magnitude > 0.01 then
        bodyVelocity.Velocity = move.Unit * S.flySpeed
        bodyGyro.CFrame = CFrame.lookAt(root.Position, root.Position + move.Unit)
    else
        bodyVelocity.Velocity = Vector3.zero
    end
end

-- ========== TELEPORT TOOL ==========
local tpActive = false
local function giveTPTool()
    local char = LocalPlayer.Character
    local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
    if not (char and bp) then return end
    if bp:FindFirstChild("WIA_TP") or char:FindFirstChild("WIA_TP") then return end
    local tool = new("Tool", { Name = "WIA_TP", RequiresHandle = false, CanBeDropped = false })
    tool.Equipped:Connect(function() tpActive = true Mouse.Icon = "rbxasset://SystemCursors/Crosshair" end)
    tool.Unequipped:Connect(function() tpActive = false Mouse.Icon = "rbxasset://SystemCursors/Arrow" end)
    tool.Activated:Connect(function()
        if not tpActive then return end
        local _, root = getChar()
        if root and Mouse.Hit then root.CFrame = CFrame.new(Mouse.Hit.Position + Vector3.new(0, 3, 0)) end
    end)
    tool.Parent = bp
end
local function removeTPTool()
    local bp, char = LocalPlayer:FindFirstChildOfClass("Backpack"), LocalPlayer.Character
    if bp and bp:FindFirstChild("WIA_TP") then bp.WIA_TP:Destroy() end
    if char and char:FindFirstChild("WIA_TP") then char.WIA_TP:Destroy() end
end

-- ========== F3X ==========
local function loadF3X()
    if pcall(function() loadstring(game:HttpGet("https://raw.githubusercontent.com/RegularVynixu/Utilities/main/F3X%20Building%20Tools.lua"))() end) then return true end
    for _, id in ipairs({ 153181286, 144133059 }) do
        if pcall(function()
            local m = InsertService:LoadAsset(id)
            m.Parent = workspace
            local tool = m:FindFirstChildOfClass("Tool")
            if tool then tool.Parent = LocalPlayer.Backpack end
        end) then return true end
    end
    return false
end

-- ========== SILENT AIM HOOK (uses cached target, no per-call search) ==========
if hookmetamethod and getnamecallmethod then
    pcall(function()
        local old
        local handler = function(self, ...)
            if S.silent and S.curPart and not S.unloaded and (not S.wallcheck or S.curVisible) then
                local method = getnamecallmethod()
                if method == "FireServer" and not (checkcaller and checkcaller()) then
                    local args, mod = { ... }, false
                    for i = 1, #args do
                        if typeof(args[i]) == "CFrame" then
                            args[i] = CFrame.new(args[i].Position, S.curPart.Position)
                            mod = true
                        end
                    end
                    if mod then return old(self, table.unpack(args)) end
                elseif S.silentRay and method == "Raycast" and self == workspace and not (checkcaller and checkcaller()) then
                    local args = { ... }
                    if typeof(args[1]) == "Vector3" and typeof(args[2]) == "Vector3" then
                        args[2] = (S.curPart.Position - args[1]).Unit * args[2].Magnitude
                        return old(self, table.unpack(args))
                    end
                end
            end
            return old(self, ...)
        end
        old = hookmetamethod(game, "__namecall", newcclosure and newcclosure(handler) or handler)
    end)
end

-- ========== DASH ==========
local function doDash()
    local now = tick()
    if now - S.dashLast < S.dashCd then return end
    S.dashLast = now
    local _, root = getChar()
    if not root then return end
    local bv = new("BodyVelocity", { Velocity = Camera.CFrame.LookVector * S.dashPower, MaxForce = Vector3.new(1e5, 1e5, 1e5) }, root)
    Debris:AddItem(bv, 0.2)
end

-- ========== AIM / TARGETING ==========
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
pcall(function() rayParams.RespectCanCollide = true end)
local function aimOrigin()
    if UserInputService.TouchEnabled and not UserInputService.MouseEnabled then return Camera.ViewportSize / 2 end
    return UserInputService:GetMouseLocation()
end
local function isVisible(part, char)
    rayParams.FilterDescendantsInstances = { LocalPlayer.Character, char }
    local o = Camera.CFrame.Position
    return workspace:Raycast(o, part.Position - o, rayParams) == nil
end
local function pickPart(char)
    local name = S.aimPart == "Random" and S.randPart or S.aimPart
    return char:FindFirstChild(name) or char:FindFirstChild("Head")
end
local function getTarget(origin)
    local sel = S.selected
    if sel and sel.Parent and sel.Character then
        local p = pickPart(sel.Character)
        if p then return sel, p end
    end
    local best, bestPart, bestD = nil, nil, S.aimFov
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and enemy(plr) then
            local ch = plr.Character
            local hum = ch and ch:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 then
                local part = pickPart(ch)
                if part then
                    local sp, on = Camera:WorldToViewportPoint(part.Position)
                    if on and (part.Position - Camera.CFrame.Position).Magnitude <= S.maxDist then
                        local d = (Vector2.new(sp.X, sp.Y) - origin).Magnitude
                        if d < bestD then bestD, best, bestPart = d, plr, part end
                    end
                end
            end
        end
    end
    return best, bestPart
end

-- ========== SKELETON CACHE ==========
local skelCache = setmetatable({}, { __mode = "k" })
local function getJoints(char)
    local j = skelCache[char]
    if not j then
        j = {}
        for _, d in ipairs(char:GetDescendants()) do
            if d:IsA("Motor6D") and d.Part0 and d.Part1 then j[#j + 1] = d end
        end
        skelCache[char] = j
    end
    return j
end

-- ========== RENDER LOOP (single connection for everything visual) ==========
local frames, fps = 0, 0
local camOverride = false
local fcPos, fcYaw, fcPitch = Vector3.zero, 0, 0
local lastClick = 0
local PlayerListGui

local function renderESP(plrs)
    local vp = Camera.ViewportSize
    local camPos = Camera.CFrame.Position
    poolL.reset() poolS.reset() poolT.reset()
    local anyBox = S.espBox or S.espTracer or S.espName or S.espDist or S.espHealth or S.espTool
    if S.skeleton or anyBox then
        for _, plr in ipairs(plrs) do
            local isSelf = plr == LocalPlayer
            local ch = plr.Character
            if ch and ((not isSelf and enemy(plr)) or (isSelf and S.skeleton and S.skelSelf)) then
                local hum, root, head = ch:FindFirstChildOfClass("Humanoid"), ch:FindFirstChild("HumanoidRootPart"), ch:FindFirstChild("Head")
                if hum and hum.Health > 0 and root and head then
                    local rp = Camera:WorldToViewportPoint(root.Position)
                    if rp.Z > 0 and (isSelf or (root.Position - camPos).Magnitude <= S.espMax) then
                        if S.skeleton then
                            for _, j in ipairs(getJoints(ch)) do
                                local p0, p1 = j.Part0, j.Part1
                                if p0 and p1 and p0.Parent and p1.Parent then
                                    local a, b = Camera:WorldToViewportPoint(p0.Position), Camera:WorldToViewportPoint(p1.Position)
                                    if a.Z > 0 and b.Z > 0 then
                                        local line = poolL.get()
                                        line.From = Vector2.new(a.X, a.Y) line.To = Vector2.new(b.X, b.Y)
                                        line.Color = S.skelColor line.Thickness = 2 line.Transparency = 1
                                    end
                                end
                            end
                        end
                        if not isSelf and anyBox then
                            local top = Camera:WorldToViewportPoint(head.Position + Vector3.new(0, 0.7, 0))
                            local bot = Camera:WorldToViewportPoint(root.Position - Vector3.new(0, 3, 0))
                            local h = math.abs(bot.Y - top.Y)
                            local w = h * 0.55
                            local x, y = rp.X - w / 2, top.Y
                            if S.espBox then
                                local sq = poolS.get()
                                sq.Size = Vector2.new(w, h) sq.Position = Vector2.new(x, y)
                                sq.Color = S.espColor sq.Transparency = 1
                            end
                            if S.espTracer then
                                local l = poolL.get()
                                l.From = Vector2.new(vp.X / 2, vp.Y) l.To = Vector2.new(rp.X, bot.Y)
                                l.Color = S.espColor l.Thickness = 1 l.Transparency = 0.65
                            end
                            if S.espHealth and hum.MaxHealth > 0 then
                                local frac = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
                                local l = poolL.get()
                                l.From = Vector2.new(x - 4, y + h) l.To = Vector2.new(x - 4, y + h - h * frac)
                                l.Color = Color3.fromRGB(220, 60, 60):Lerp(Color3.fromRGB(70, 220, 100), frac)
                                l.Thickness = 2 l.Transparency = 1
                            end
                            if S.espName or S.espDist or S.espHealth or S.espTool then
                                local t = poolT.get()
                                local s = ""
                                if S.espName then s = plr.Name .. " " end
                                if S.espHealth then s = s .. "[" .. math.floor(hum.Health) .. "HP] " end
                                if S.espDist then s = s .. "(" .. math.floor((root.Position - camPos).Magnitude) .. "m) " end
                                if S.espTool then local tl = ch:FindFirstChildOfClass("Tool") if tl then s = s .. "<" .. tl.Name .. ">" end end
                                t.Text = s t.Position = Vector2.new(rp.X, y - 16) t.Color = S.espColor
                            end
                        end
                    end
                end
            end
        end
    end
    if S.itemEsp then
        local n = 0
        for _, tool in ipairs(S.itemCache) do
            if tool.Parent then
                local handle = tool:FindFirstChild("Handle")
                if handle then
                    local sp, on = Camera:WorldToViewportPoint(handle.Position)
                    if on then
                        n += 1
                        if n > 80 then break end
                        local t = poolT.get()
                        t.Position = Vector2.new(sp.X, sp.Y) t.Color = Color3.fromRGB(255, 215, 0) t.Text = tool.Name
                    end
                end
            end
        end
    end
    poolL.finish() poolS.finish() poolT.finish()
end

bind(RunService.RenderStepped, function(dt)
    if S.unloaded then return end
    frames += 1
    Camera = workspace.CurrentCamera

    -- camera control: freecam > spectate
    if S.freecam then
        local cam = Camera
        cam.CameraType = Enum.CameraType.Scriptable
        camOverride = true
        local move = Vector3.zero
        local cf = cam.CFrame
        local UIS = UserInputService
        if UIS:IsKeyDown(Enum.KeyCode.W) then move += cf.LookVector end
        if UIS:IsKeyDown(Enum.KeyCode.S) then move -= cf.LookVector end
        if UIS:IsKeyDown(Enum.KeyCode.A) then move -= cf.RightVector end
        if UIS:IsKeyDown(Enum.KeyCode.D) then move += cf.RightVector end
        if UIS:IsKeyDown(Enum.KeyCode.Space) or S.flyUp then move += Vector3.yAxis end
        if UIS:IsKeyDown(Enum.KeyCode.LeftShift) or S.flyDown then move -= Vector3.yAxis end
        if move.Magnitude > 0 then fcPos += move.Unit * S.fcSpeed * dt end
        local d = UIS:GetMouseDelta()
        fcYaw -= d.X * 0.003
        fcPitch = math.clamp(fcPitch - d.Y * 0.003, -math.pi / 2 + 0.01, math.pi / 2 - 0.01)
        cam.CFrame = CFrame.new(fcPos) * CFrame.Angles(0, fcYaw, 0) * CFrame.Angles(fcPitch, 0, 0)
    elseif S.spectate then
        local char = S.spectate.Character
        local head, root = char and char:FindFirstChild("Head"), char and char:FindFirstChild("HumanoidRootPart")
        if head and root then
            Camera.CameraType = Enum.CameraType.Scriptable
            camOverride = true
            local offset = root.CFrame.LookVector * -14 + Vector3.new(0, 6, 0)
            Camera.CFrame = CFrame.new(head.Position + offset, head.Position)
        end
    elseif camOverride then
        camOverride = false
        Camera.CameraType = Enum.CameraType.Custom
        local _, _, hum = getChar()
        if hum then Camera.CameraSubject = hum end
    end

    -- FOV changer / zoom
    local tgt = S.fovOn and S.fovVal or nil
    if S.zoom and UserInputService:IsKeyDown(S.zoomKey) then tgt = 20 end
    if tgt then
        S.fovTouched = true
        Camera.FieldOfView += (tgt - Camera.FieldOfView) * math.min(1, dt * 12)
    elseif S.fovTouched then
        Camera.FieldOfView += (S.fovDefault - Camera.FieldOfView) * math.min(1, dt * 12)
        if math.abs(Camera.FieldOfView - S.fovDefault) < 0.2 then Camera.FieldOfView = S.fovDefault S.fovTouched = false end
    end

    if S.trigger and mouse1click and tick() - lastClick > 0.08 then
        local t = Mouse.Target
        if t and t.Parent then
            local plr = Players:GetPlayerFromCharacter(t.Parent) or Players:GetPlayerFromCharacter(t.Parent.Parent)
            if plr and plr ~= LocalPlayer and enemy(plr) then lastClick = tick() pcall(mouse1click) end
        end
    end

    -- drawings
    if hasDrawing then
        fovCircle.Visible = (S.aimbot or S.silent) and S.fovCircle
        if fovCircle.Visible then
            fovCircle.Position = aimOrigin()
            fovCircle.Radius = S.aimFov
        end
        if S.crosshair then
            if not crossLines then
                crossLines = {}
                for i = 1, 4 do local l = Drawing.new("Line") l.Thickness = 2 crossLines[i] = l end
            end
            local c = Camera.ViewportSize / 2
            local g, len = 4, 9
            local offs = { { Vector2.new(g, 0), Vector2.new(g + len, 0) }, { Vector2.new(-g, 0), Vector2.new(-g - len, 0) }, { Vector2.new(0, g), Vector2.new(0, g + len) }, { Vector2.new(0, -g), Vector2.new(0, -g - len) } }
            for i, l in ipairs(crossLines) do
                l.From, l.To, l.Color, l.Visible = c + offs[i][1], c + offs[i][2], T.accent, true
            end
        elseif crossLines then
            for _, l in ipairs(crossLines) do l.Visible = false end
        end
        renderESP(Players:GetPlayers())
    end
end)

-- ========== AIM STEP (после камеры игры: BindToRenderStep Camera+1) ==========
local function aimStep()
    if S.unloaded then return end
    if not (S.aimbot or S.silent or S.autoShoot) then S.curTarget, S.curPart = nil, nil return end
    Camera = workspace.CurrentCamera
    local origin = aimOrigin()
    local plr, part = getTarget(origin)
    S.curTarget, S.curPart = plr, part
    local visible = false
    if part then visible = (not S.wallcheck) or isVisible(part, plr.Character) end
    S.curVisible = visible
    if not (part and visible) then return end
    local aimPos = part.Position
    if S.predict > 0 then aimPos += part.AssemblyLinearVelocity * (S.predict / 500) end
    if S.aimbot then
        local hold = not S.holdAim or UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
            or (UserInputService.TouchEnabled and not UserInputService.MouseEnabled)
        if hold then
            if S.aimMethod == "Mouse" and mousemoverel then
                local sp = Camera:WorldToViewportPoint(aimPos)
                local d = Vector2.new(sp.X, sp.Y) - origin
                pcall(mousemoverel, d.X / math.max(S.smooth, 1), d.Y / math.max(S.smooth, 1))
            else
                local cur = Camera.CFrame
                local nw = CFrame.lookAt(cur.Position, aimPos)
                Camera.CFrame = S.smooth > 1 and cur:Lerp(nw, 1 / S.smooth) or nw
            end
        end
    end
    if S.autoShoot and mouse1click and tick() - lastClick > 0.08 then
        lastClick = tick()
        pcall(mouse1click)
    end
end
RunService:BindToRenderStep("WiaAim", Enum.RenderPriority.Camera.Value + 1, aimStep)

-- ========== CHAMS / HITBOX / ITEM CACHE (event + timer based) ==========
local hbOrig = setmetatable({}, { __mode = "k" })
local function refreshChams()
    for _, plr in ipairs(Players:GetPlayers()) do
        local ch = plr.Character
        if plr ~= LocalPlayer and ch then
            local hl = ch:FindFirstChild("WIA_WH")
            if S.chams and enemy(plr) then
                if not hl then
                    hl = new("Highlight", { Name = "WIA_WH", OutlineColor = Color3.new(1, 1, 1), DepthMode = Enum.HighlightDepthMode.AlwaysOnTop }, ch)
                end
                hl.FillColor = S.espColor
                hl.FillTransparency = S.chamsOp
            elseif hl then
                hl:Destroy()
            end
        end
    end
end

local function restoreHitboxes()
    for hrp, o in pairs(hbOrig) do
        if hrp and hrp.Parent then
            hrp.Size, hrp.Transparency, hrp.CanCollide = o[1], o[2], o[3]
        end
        hbOrig[hrp] = nil
    end
end
local function applyHitboxes()
    for _, plr in ipairs(Players:GetPlayers()) do
        local ch = plr.Character
        local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
        if plr ~= LocalPlayer and hrp then
            if enemy(plr) then
                if not hbOrig[hrp] then hbOrig[hrp] = { hrp.Size, hrp.Transparency, hrp.CanCollide } end
                hrp.Size = Vector3.new(S.hitSize, S.hitSize, S.hitSize)
                hrp.Transparency = 0.7
                hrp.CanCollide = false
            elseif hbOrig[hrp] then
                local o = hbOrig[hrp]
                hrp.Size, hrp.Transparency, hrp.CanCollide = o[1], o[2], o[3]
                hbOrig[hrp] = nil
            end
        end
    end
end

local function refreshItemCache()
    task.spawn(function()
        local list, n = {}, 0
        local desc = workspace:GetDescendants()
        for i = 1, #desc do
            local o = desc[i]
            if o:IsA("Tool") and o:FindFirstChild("Handle") then list[#list + 1] = o end
            n += 1
            if n % 4000 == 0 then task.wait() end
        end
        S.itemCache = list
    end)
end

-- ========== LIGHTING ==========
local lightOrig = {
    Brightness = Lighting.Brightness, ClockTime = Lighting.ClockTime, FogEnd = Lighting.FogEnd, FogStart = Lighting.FogStart,
    GlobalShadows = Lighting.GlobalShadows, Ambient = Lighting.Ambient, OutdoorAmbient = Lighting.OutdoorAmbient,
}
local atmoOrig = {}
local function applyLighting()
    if S.fullbright then
        Lighting.Brightness = 2 Lighting.ClockTime = 14 Lighting.GlobalShadows = false
        Lighting.Ambient = Color3.new(1, 1, 1) Lighting.OutdoorAmbient = Color3.new(1, 1, 1)
    end
    if S.noFog then
        Lighting.FogEnd = 1e9 Lighting.FogStart = 1e9
        for _, a in ipairs(Lighting:GetChildren()) do
            if a:IsA("Atmosphere") then
                if atmoOrig[a] == nil then atmoOrig[a] = a.Density end
                a.Density = 0
            end
        end
    end
end
local function restoreLighting(which)
    if which == "fb" then
        for _, k in ipairs({ "Brightness", "ClockTime", "GlobalShadows", "Ambient", "OutdoorAmbient" }) do Lighting[k] = lightOrig[k] end
    else
        Lighting.FogEnd, Lighting.FogStart = lightOrig.FogEnd, lightOrig.FogStart
        for a, d in pairs(atmoOrig) do if a.Parent then a.Density = d end end
        atmoOrig = {}
    end
end

-- ========== HEARTBEAT / STEPPED ==========
local noclipParts, otherParts = {}, {}
local function rebuildNoclip()
    noclipParts = {}
    local char = LocalPlayer.Character
    if char then
        for _, p in ipairs(char:GetDescendants()) do if p:IsA("BasePart") then noclipParts[#noclipParts + 1] = p end end
    end
end
local function rebuildOthers()
    otherParts = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character then
            for _, p in ipairs(plr.Character:GetDescendants()) do
                if p:IsA("BasePart") then otherParts[#otherParts + 1] = p end
            end
        end
    end
end
local ragdollStates = { Enum.HumanoidStateType.Ragdoll, Enum.HumanoidStateType.FallingDown }
local function applyRagdoll(on)
    local _, _, hum = getChar()
    if not hum then return end
    for _, st in ipairs(ragdollStates) do pcall(function() hum:SetStateEnabled(st, not on) end) end
end

bind(RunService.Stepped, function()
    if S.noclip then
        for i = 1, #noclipParts do
            local p = noclipParts[i]
            if p.CanCollide then p.CanCollide = false end
        end
    end
    if S.antiFling then
        for i = 1, #otherParts do
            local p = otherParts[i]
            if p.CanCollide then p.CanCollide = false end
        end
    end
end)

local tAcc = { fast = 0, slow = 0, items = 0, rainbow = 0, ui = 0 }
local rainbowHue = 0
bind(RunService.Heartbeat, function(dt)
    if S.unloaded then return end
    local char, root, hum = getChar()

    if S.fly then flightStep() end
    if char and root and hum then
        if S.cfSpeed and not S.fly then
            local md = hum.MoveDirection
            if md.Magnitude > 0.01 then root.CFrame += md * hum.WalkSpeed * (S.cfMult - 1) * dt end
        end
        if S.bhop and UserInputService:IsKeyDown(Enum.KeyCode.Space) and hum.FloorMaterial ~= Enum.Material.Air then
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
        end
        if S.spin and not S.fly then root.CFrame *= CFrame.Angles(0, math.rad(S.spinSpeed), 0) end
        if S.god and hum.Health > 0 and hum.Health < hum.MaxHealth then hum.Health = hum.MaxHealth end
        if S.antiVoid then
            local fh = workspace.FallenPartsDestroyHeight
            if hum.FloorMaterial ~= Enum.Material.Air and root.Position.Y > fh + 100 then
                S.lastSafe = root.CFrame
            elseif S.lastSafe and root.Position.Y < fh + 60 then
                root.AssemblyLinearVelocity = Vector3.zero
                root.CFrame = S.lastSafe + Vector3.new(0, 4, 0)
            end
        end
        if S.antiFall and not S.fly then
            local v = root.AssemblyLinearVelocity
            if v.Y < -70 then root.AssemblyLinearVelocity = Vector3.new(v.X, -20, v.Z) end
        end
        if S.antiFling and not S.fly then
            local v = root.AssemblyLinearVelocity
            if v.Magnitude > 160 and S.dashLast + 1 < tick() then
                root.AssemblyLinearVelocity = Vector3.zero
                root.AssemblyAngularVelocity = Vector3.zero
            end
        end
        if S.antiRagdoll and hum.PlatformStand and not S.fly then hum.PlatformStand = false end
        if S.wallRun and hum.FloorMaterial == Enum.Material.Air and hum.MoveDirection.Magnitude > 0.01 then
            rayParams.FilterDescendantsInstances = { char }
            if workspace:Raycast(root.Position, hum.MoveDirection * 3, rayParams) then
                local v = root.AssemblyLinearVelocity
                root.AssemblyLinearVelocity = Vector3.new(v.X, math.max(v.Y, 18), v.Z)
            end
        end
    end

    if root and hum then
        if S.sprint and not S.fly and UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
            local md = hum.MoveDirection
            if md.Magnitude > 0.01 then root.CFrame += md * hum.WalkSpeed * (S.sprintMult - 1) * dt end
        end
        if S.airWalk then
            if not S.airPart or not S.airPart.Parent then
                S.airPart = new("Part", { Size = Vector3.new(7, 0.6, 7), Anchored = true, Transparency = 0.65, Material = Enum.Material.SmoothPlastic, Color = T.accent, CanQuery = false }, workspace)
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then S.airY += 22 * dt end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then S.airY -= 22 * dt end
            S.airPart.CFrame = CFrame.new(root.Position.X, S.airY, root.Position.Z)
        end
    end

    -- auto clicker
    if S.autoClick and mouse1click then
        S.clickAcc += dt
        if S.clickAcc >= 1 / S.cps then S.clickAcc = 0 pcall(mouse1click) end
    end

    -- rainbow accent
    if S.rainbow then
        tAcc.rainbow += dt
        if tAcc.rainbow >= 0.06 then
            tAcc.rainbow = 0
            rainbowHue = (rainbowHue + 0.01) % 1
            setAccent(Color3.fromHSV(rainbowHue, 0.65, 1))
        end
    end

    -- fast timer (0.2s): hitbox
    tAcc.fast += dt
    if tAcc.fast >= 0.2 then
        tAcc.fast = 0
        if S.hitbox then applyHitboxes() end
    end

    -- slow timer (0.6s): caches, chams, walkspeed enforce, lighting
    tAcc.slow += dt
    if tAcc.slow >= 0.6 then
        tAcc.slow = 0
        if S.noclip then rebuildNoclip() end
        if S.antiFling then rebuildOthers() end
        if S.chams then refreshChams() end
        if S.aimPart == "Random" then
            local names = { "Head", "HumanoidRootPart", "UpperTorso", "LowerTorso" }
            S.randPart = names[math.random(1, #names)]
        end
        if hum then
            if S.walk ~= 16 and not S.freecam and hum.WalkSpeed ~= S.walk then hum.WalkSpeed = S.walk end
            if S.antiRagdoll then applyRagdoll(true) end
        end
        if S.fullbright or S.noFog then applyLighting() end
    end

    -- watermark + item cache (0.5s / 2.5s)
    tAcc.ui += dt
    if tAcc.ui >= 0.5 then
        fps = math.floor(frames / tAcc.ui + 0.5)
        frames = 0
        tAcc.ui = 0
        local ok, ping = pcall(function() return math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue()) end)
        local txt = string.format("%d FPS  ·  %d ms  ·  %d/%d  ·  %s", fps, ok and ping or 0, #Players:GetPlayers(), Players.MaxPlayers, LocalPlayer.Name)
        if S.coords and root then local p = root.Position txt = string.format("%.0f, %.0f, %.0f  ·  ", p.X, p.Y, p.Z) .. txt end
        WmStats.Text = txt
        if S.aimbot or S.silent then
            StatusBar.Text = "Aim: " .. (S.curTarget and S.curTarget.Name or "нет цели") .. ((S.curTarget and not S.curVisible) and " (за стеной)" or "")
        else
            StatusBar.Text = "Ready · " .. S.menuKey.Name .. " — скрыть меню"
        end
    end
    if S.itemEsp then
        tAcc.items += dt
        if tAcc.items >= 2.5 then tAcc.items = 0 refreshItemCache() end
    end
end)

bind(UserInputService.JumpRequest, function()
    if not S.infJump then return end
    local _, _, hum = getChar()
    if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
end)

-- single input handler: capture / keybinds / dash / menu key / click TP
bind(UserInputService.InputBegan, function(input, gp)
    if capturing and input.UserInputType == Enum.UserInputType.Keyboard then
        local cb = capturing
        capturing = nil
        cb(input.KeyCode)
        return
    end
    if gp then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1 and S.clickTP and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
        local _, root = getChar()
        if root and Mouse.Hit then root.CFrame = CFrame.new(Mouse.Hit.Position + Vector3.new(0, 3, 0)) end
        return
    end
    if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
    local kc = input.KeyCode
    for _, b in ipairs(binds) do
        if b.key and b.key == kc then b.toggle() end
    end
    if S.dash and kc == S.dashKey then
        doDash()
    elseif kc == S.menuKey then
        sfx("flip")
        S.guiVisible = not S.guiVisible
        ScreenGui.Enabled = S.guiVisible
        if S.playerList then PlayerListGui.Enabled = S.guiVisible end
    end
end)

bind(LocalPlayer.Idled, function()
    if not S.antiAFK then return end
    pcall(function()
        local vu = game:GetService("VirtualUser")
        vu:CaptureController()
        vu:ClickButton2(Vector2.new())
    end)
end)

-- ========== PLAYER LIST ==========
local origGravity = workspace.Gravity
local playerListT
local updatePlayerList
local TargetStatus
PlayerListGui = new("ScreenGui", { Name = "WiaPlayerList", ResetOnSpawn = false, Enabled = false })
parentGui(PlayerListGui)
local PLScroll
do
    local vp = Camera.ViewportSize
    local plW, plH = math.clamp(vp.X * 0.5, 260, 340), math.clamp(vp.Y - 80, 200, 400)
    local PLMain = new("Frame", { Size = UDim2.new(0, plW, 0, plH), Position = UDim2.new(1, -plW - 70, 0, 70), BackgroundColor3 = T.bg, BackgroundTransparency = 0.08, BorderSizePixel = 0, ClipsDescendants = true }, PlayerListGui)
    addCorner(PLMain, 12) addStroke(PLMain)
    local title = new("TextLabel", { Size = UDim2.new(1, -56, 0, 36), Position = UDim2.new(0, 14, 0, 0), Text = "ИГРОКИ", TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, BackgroundTransparency = 1, Font = Enum.Font.GothamBold }, PLMain)
    ref(title, "TextColor3")
    local close = new("TextButton", { Size = UDim2.new(0, 30, 0, 26), Position = UDim2.new(1, -38, 0, 5), Text = "✕", TextColor3 = T.dim, TextSize = 14, Font = Enum.Font.GothamBold, BackgroundColor3 = T.row, BorderSizePixel = 0 }, PLMain)
    addCorner(close, 6)
    close.MouseButton1Click:Connect(function() if playerListT then playerListT.setState(false) else PlayerListGui.Enabled = false end end)
    PLScroll = new("ScrollingFrame", { Size = UDim2.new(1, -8, 1, -84), Position = UDim2.new(0, 4, 0, 38), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(0, 0, 0, 0) }, PLMain)
    ref(PLScroll, "ScrollBarImageColor3")
    new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, PLScroll)
    new("UIPadding", { PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 6), PaddingTop = UDim.new(0, 2), PaddingBottom = UDim.new(0, 6) }, PLScroll)
    TargetStatus = new("TextLabel", { Size = UDim2.new(1, -96, 0, 36), Position = UDim2.new(0, 14, 1, -42), BackgroundTransparency = 1, Text = "Цель: авто (ближайший)", TextColor3 = T.dim, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Font = Enum.Font.Gotham, TextSize = 12 }, PLMain)
    local reset = new("TextButton", { Size = UDim2.new(0, 66, 0, 30), Position = UDim2.new(1, -74, 1, -38), Text = "СБРОС", TextColor3 = T.text, TextSize = 11, Font = Enum.Font.GothamBold, BackgroundColor3 = T.row, BorderSizePixel = 0 }, PLMain)
    addCorner(reset, 8)
    reset.MouseButton1Click:Connect(function() S.selected = nil TargetStatus.Text = "Цель: авто (ближайший)" TargetStatus.TextColor3 = T.dim updatePlayerList() end)
    makeDraggable(PLMain, title)
end

local function setAimTarget(plr)
    S.selected = plr
    if plr then TargetStatus.Text = "Цель: " .. plr.Name TargetStatus.TextColor3 = T.ok
    else TargetStatus.Text = "Цель: авто (ближайший)" TargetStatus.TextColor3 = T.dim end
end

local function setFreecam(on)
    if S.freecam == on then return end
    S.freecam = on
    local _, _, hum = getChar()
    if on then
        S.spectate = nil
        local cf = Camera.CFrame
        fcPos = cf.Position
        fcPitch, fcYaw = cf:ToOrientation()
        if hum then S.fcWalk = hum.WalkSpeed hum.WalkSpeed = 0 end
        notify("Freecam ON", "success")
    else
        if hum and S.fcWalk then hum.WalkSpeed = S.fcWalk S.fcWalk = nil end
        notify("Freecam OFF")
    end
end
local freecamT

local function rowBtn(parent, text, xOff, color)
    local b = new("TextButton", { Size = UDim2.new(0, 44, 0, 30), Position = UDim2.new(1, xOff, 0.5, -15), Text = text, TextColor3 = T.text, TextSize = 11, Font = Enum.Font.GothamBold, BackgroundColor3 = color, BorderSizePixel = 0 }, parent)
    addCorner(b, 6)
    return b
end

updatePlayerList = function()
    for _, c in ipairs(PLScroll:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end
    local order = 0
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            order += 1
            local sel = S.selected == plr
            local row = new("Frame", { Size = UDim2.new(1, 0, 0, 42), BackgroundColor3 = sel and Color3.fromRGB(205, 230, 200) or T.row, BorderSizePixel = 0, LayoutOrder = order }, PLScroll)
            addCorner(row, 8)
            new("TextLabel", { Size = UDim2.new(1, -160, 1, 0), Position = UDim2.new(0, 10, 0, 0), BackgroundTransparency = 1, Text = plr.Name, TextColor3 = T.text, TextSize = 12, Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd }, row)
            local spec = S.spectate == plr
            local spBtn = rowBtn(row, spec and "STOP" or "SP", -142, spec and Color3.fromRGB(240, 200, 195) or T.rowd)
            local tpBtn = rowBtn(row, "TP", -96, T.rowd)
            local aimBtn = rowBtn(row, sel and "✓" or "AIM", -50, sel and Color3.fromRGB(160, 210, 170) or T.rowd)
            spBtn.MouseButton1Click:Connect(function()
                if S.spectate == plr then
                    S.spectate = nil
                    notify("Спектатор выключен")
                else
                    S.spectate = plr
                    if S.freecam and freecamT then freecamT.setState(false) end
                    notify("Спектатор: " .. plr.Name, "success")
                end
                updatePlayerList()
            end)
            tpBtn.MouseButton1Click:Connect(function()
                local _, myRoot = getChar()
                local their = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
                if myRoot and their then myRoot.CFrame = their.CFrame + Vector3.new(0, 3, 0) notify("TP к " .. plr.Name, "success") end
            end)
            aimBtn.MouseButton1Click:Connect(function()
                setAimTarget(S.selected == plr and nil or plr)
                updatePlayerList()
            end)
        end
    end
end
local plDirty = false
local function queuePL()
    if not S.playerList or plDirty then return end
    plDirty = true
    task.delay(0.2, function() plDirty = false if S.playerList then updatePlayerList() end end)
end

-- ========== TOGGLE BUTTON ==========
local function toggleMenu()
    sfx("flip")
    S.guiVisible = not S.guiVisible
    ScreenGui.Enabled = S.guiVisible
    if S.playerList then PlayerListGui.Enabled = S.guiVisible end
end
do
    local g = new("ScreenGui", { Name = "WiaToggle", ResetOnSpawn = false })
    parentGui(g)
    local btn = new("TextButton", { Size = UDim2.new(0, 42, 0, 42), Position = UDim2.new(1, -58, 0, 60), Text = "W", TextColor3 = T.onAccent, BackgroundTransparency = 0.1, BorderSizePixel = 0, Font = Enum.Font.GothamBold, TextSize = 18 }, g)
    ref(btn, "BackgroundColor3") addCorner(btn, 21, true) addStroke(btn, Color3.new(1, 1, 1), 1, 0.7)
    makeDraggable(btn)
    local pressPos
    btn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then pressPos = input.Position end
    end)
    btn.InputEnded:Connect(function(input)
        if pressPos and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1) then
            if (input.Position - pressPos).Magnitude < 8 then toggleMenu() end
            pressPos = nil
        end
    end)
end

-- ========== PLAYER / CHARACTER EVENTS ==========
bind(LocalPlayer.CharacterAdded, function(char)
    task.spawn(function()
        local hum = char:WaitForChild("Humanoid", 10)
        char:WaitForChild("HumanoidRootPart", 10)
        task.wait(0.4)
        if S.unloaded then return end
        if hum then
            if S.walk ~= 16 then hum.WalkSpeed = S.walk end
            if S.jump ~= 50 then hum.UseJumpPower = true hum.JumpPower = S.jump end
        end
        S.lastSafe = nil
        if S.fly then startFlight() end
        if S.tpTool then giveTPTool() end
        if S.headless then applyHeadless() end
        if S.korblox then applyKorblox() end
        if S.antiRagdoll then applyRagdoll(true) end
        rebuildNoclip()
        if S.lastPack and PACKS[S.lastPack] then task.wait(0.3) applyPack(S.lastPack, true) end
    end)
end)
local function hookPlayer(plr)
    bind(plr.CharacterAdded, function()
        task.wait(0.6)
        if S.unloaded then return end
        if S.chams then refreshChams() end
        if S.hitbox then applyHitboxes() end
    end)
end
for _, p in ipairs(Players:GetPlayers()) do if p ~= LocalPlayer then hookPlayer(p) end end
bind(Players.PlayerAdded, function(p) hookPlayer(p) queuePL() end)
bind(Players.PlayerRemoving, function(plr)
    if S.selected == plr then setAimTarget(nil) end
    if S.spectate == plr then S.spectate = nil end
    queuePL()
end)
rebuildNoclip()

local function removeChams()
    for _, p in ipairs(Players:GetPlayers()) do
        local hl = p.Character and p.Character:FindFirstChild("WIA_WH")
        if hl then hl:Destroy() end
    end
end

-- ========== TAB: COMBAT ==========
createTab("Combat")
createSection("Aimbot")
createTumbler("Aimbot", false).onToggle(function(st) S.aimbot = st notify(st and "Aimbot ON" or "Aimbot OFF", st and "success" or nil) end)
createTumbler("Silent Aim", false).onToggle(function(st) S.silent = st notify(st and "Silent Aim ON" or "Silent Aim OFF", st and "success" or nil) end)
createTumbler("Silent Raycast mode", false).onToggle(function(st) S.silentRay = st end)
createTumbler("Wallcheck", false).onToggle(function(st) S.wallcheck = st end)
createTumbler("Hold to Aim (RMB)", false).onToggle(function(st) S.holdAim = st end)
createTumbler("AutoShoot", false).onToggle(function(st) S.autoShoot = st end)
createTumbler("FOV Circle", false).onToggle(function(st) S.fovCircle = st end)
createSlider("Aimbot FOV", 10, 400, 90, function(v) S.aimFov = v end)
createSlider("Aimbot Smooth", 1, 20, 5, function(v) S.smooth = v end)
createSelector("Aim Method", { { "Camera", "Camera" }, { "Mouse (mousemoverel)", "Mouse" } }, 1, function(v) S.aimMethod = v end)
createSlider("Prediction", 0, 100, 0, function(v) S.predict = v end)
createSlider("Aim Max Distance", 50, 3000, 1000, function(v) S.maxDist = v end)
createSelector("Aim Part", { { "Head", "Head" }, { "Torso", "HumanoidRootPart" }, { "Random", "Random" } }, 1, function(v) S.aimPart = v end)
createTumbler("Triggerbot", false).onToggle(function(st) S.trigger = st end)
createSection("Hitbox")
createTumbler("Hitbox Expander", false).onToggle(function(st)
    S.hitbox = st
    if st then applyHitboxes() else restoreHitboxes() end
end)
createSlider("Hitbox Size", 2, 20, 5, function(v) S.hitSize = v end)

-- ========== TAB: VISUALS ==========
createTab("Visuals")
createSection("ESP")
createTumbler("ESP Boxes", false).onToggle(function(st) S.espBox = st end)
createTumbler("ESP Tracers", false).onToggle(function(st) S.espTracer = st end)
createTumbler("ESP Names", false).onToggle(function(st) S.espName = st end)
createTumbler("ESP Distance & HP", false).onToggle(function(st) S.espDist, S.espHealth = st, st end)
createTumbler("Skeleton ESP", false).onToggle(function(st) S.skeleton = st end)
createTumbler("Skeleton Self Test", false).onToggle(function(st) S.skelSelf = st end)
createTumbler("ESP Held Tool", false).onToggle(function(st) S.espTool = st end)
createSlider("ESP Max Distance", 50, 5000, 2000, function(v) S.espMax = v end)
createTumbler("Team Check", false).onToggle(function(st)
    S.team = st
    if S.chams then refreshChams() end
    if S.hitbox then applyHitboxes() end
end)
createTumbler("Item ESP", false).onToggle(function(st) S.itemEsp = st if st then refreshItemCache() end end)
createSection("Chams")
createTumbler("Chams (Wallhack)", false).onToggle(function(st)
    S.chams = st
    if st then refreshChams() else removeChams() end
end)
createSlider("Chams Opacity %", 0, 100, 35, function(v) S.chamsOp = v / 100 if S.chams then refreshChams() end end)
do
    local colors = {
        { "Purple", Color3.fromRGB(124, 92, 255) }, { "Red", Color3.fromRGB(220, 80, 80) }, { "Green", Color3.fromRGB(80, 200, 120) },
        { "Blue", Color3.fromRGB(80, 140, 220) }, { "Yellow", Color3.fromRGB(220, 200, 80) }, { "White", Color3.fromRGB(240, 240, 240) },
        { "Pink", Color3.fromRGB(240, 110, 190) }, { "Cyan", Color3.fromRGB(80, 220, 230) },
    }
    createSelector("ESP / Chams Color", colors, 1, function(c) S.espColor = c if S.chams then refreshChams() end end)
    createSelector("Skeleton Color", colors, 1, function(c) S.skelColor = c end)
end

-- ========== TAB: MOVE ==========
createTab("Move")
createSection("Flight")
createTumbler("Flight", false, { cfg = false }).onToggle(function(st)
    S.fly = st
    S.flyUp, S.flyDown = false, false
    FlyGui.Enabled = st
    if st then startFlight() notify("Flight ON", "success") else stopFlight() notify("Flight OFF") end
end)
createSlider("Fly Speed", 10, 300, 50, function(v) S.flySpeed = v end)
createTumbler("Noclip", false).onToggle(function(st) S.noclip = st if st then rebuildNoclip() end end)
createSection("Speed")
createTumbler("CFrame Speed", false).onToggle(function(st) S.cfSpeed = st end)
createSlider("Speed Multiplier", 1, 10, 2, function(v) S.cfMult = v end)
createSlider("Walk Speed", 16, 200, 16, function(v)
    S.walk = v
    local _, _, hum = getChar()
    if hum then hum.WalkSpeed = v end
end)
createSlider("Jump Power", 50, 200, 50, function(v)
    S.jump = v
    local _, _, hum = getChar()
    if hum then hum.UseJumpPower = true hum.JumpPower = v end
end)
createTumbler("Infinite Jump", false).onToggle(function(st) S.infJump = st end)
createTumbler("Bhop", false).onToggle(function(st) S.bhop = st end)
createTumbler("Sprint (Shift)", false).onToggle(function(st) S.sprint = st end)
createSlider("Sprint x%", 110, 400, 160, function(v) S.sprintMult = v / 100 end)
createTumbler("Air Walk (Space / Ctrl)", false).onToggle(function(st)
    S.airWalk = st
    local _, r = getChar()
    S.airY = r and (r.Position.Y - 3.2) or 0
    if not st and S.airPart then S.airPart:Destroy() S.airPart = nil end
end)
createTumbler("Low Gravity", false).onToggle(function(st)
    S.lowGrav = st
    S.savedGravity = st and 50 or origGravity
    if not S.fly then workspace.Gravity = S.savedGravity end
end)
createSection("Dash")
createTumbler("Dash", false).onToggle(function(st) S.dash = st end)
createSlider("Dash Power", 30, 300, 90, function(v) S.dashPower = v end)
createButton("Dash Key: " .. S.dashKey.Name, function(b)
    b.Text = "Нажми клавишу..."
    waitKey(function(kc)
        if kc ~= Enum.KeyCode.Escape then S.dashKey = kc notify("Dash = " .. kc.Name, "success") end
        b.Text = "Dash Key: " .. S.dashKey.Name
    end)
end)
createSection("Wall Run / Freecam / Spectate")
createTumbler("Wall Run", false).onToggle(function(st) S.wallRun = st end)
freecamT = createTumbler("Freecam", false, { cfg = false })
freecamT.onToggle(function(st) setFreecam(st) end)
createSlider("Freecam Speed", 10, 300, 50, function(v) S.fcSpeed = v end)
createButton("Спектатор: сброс", function()
    S.spectate = nil
    queuePL()
    notify("Спектатор сброшен")
end)
createSection("Spinbot")
createTumbler("Spinbot", false).onToggle(function(st) S.spin = st end)
createSlider("Spinbot Speed", 5, 50, 20, function(v) S.spinSpeed = v end)

-- ========== TAB: PLAYER ==========
createTab("Player")
createSection("Protection")
createTumbler("Godmode", false).onToggle(function(st)
    S.god = st
    local _, _, hum = getChar()
    if st and hum then hum.Health = hum.MaxHealth end
end)
createTumbler("Anti-Void", false).onToggle(function(st) S.antiVoid = st end)
createTumbler("Anti-Fall", false).onToggle(function(st) S.antiFall = st end)
createTumbler("Anti-Fling", false).onToggle(function(st) S.antiFling = st if st then rebuildOthers() end end)
createTumbler("Anti-Ragdoll", false).onToggle(function(st) S.antiRagdoll = st applyRagdoll(st) end)
createTumbler("Anti-AFK", false).onToggle(function(st) S.antiAFK = st end)
createSection("Камера и профиль")
createTumbler("Unlock Zoom / 3rd Person", false, { bindable = false }).onToggle(function(st)
    LocalPlayer.CameraMaxZoomDistance = st and 1000 or 128
    LocalPlayer.CameraMinZoomDistance = st and 0 or 0.5
    if st then LocalPlayer.CameraMode = Enum.CameraMode.Classic end
end)
createTumbler("No Camera Clip", false, { bindable = false }).onToggle(function(st)
    LocalPlayer.DevCameraOcclusionMode = st and Enum.DevCameraOcclusionMode.Invisicam or Enum.DevCameraOcclusionMode.Zoom
end)
createTumbler("Hide Nametag", false, { bindable = false }).onToggle(function(st)
    local _, _, h = getChar()
    if h then h.DisplayDistanceType = st and Enum.HumanoidDisplayDistanceType.None or Enum.HumanoidDisplayDistanceType.Viewer end
end)
createTumbler("Auto Rejoin (при кике)", false, { bindable = false }).onToggle(function(st) S.autoRejoin = st end)
bind(game:GetService("GuiService").ErrorMessageChanged, function()
    if S.autoRejoin and not S.unloaded then
        task.wait(1)
        pcall(function() TeleportService:Teleport(game.PlaceId, LocalPlayer) end)
    end
end)
createButton("Сесть / встать", function()
    local _, _, h = getChar()
    if h then h.Sit = not h.Sit end
end)
createSection("Players & Tools")
playerListT = createTumbler("Player List GUI", false, { cfg = false })
playerListT.onToggle(function(st)
    S.playerList = st
    PlayerListGui.Enabled = st and S.guiVisible
    if st then updatePlayerList() end
end)
createTumbler("Teleport Tool", false).onToggle(function(st)
    S.tpTool = st
    if st then giveTPTool() notify("TP Tool выдан (авто-выдача вкл)", "success")
    else removeTPTool() notify("TP Tool выкл") end
end)
createButton("Загрузить F3X Tools", function()
    notify("Загрузка F3X...")
    if loadF3X() then notify("F3X загружен", "success") else notify("F3X: не удалось", "error") end
end)

-- ========== TAB: MISC (новое) ==========
createTab("Misc")
createSection("Камера")
createTumbler("FOV Changer", false).onToggle(function(st) S.fovOn = st end)
createSlider("FOV", 30, 120, 70, function(v) S.fovVal = v end)
createTumbler("Zoom (удерживать)", false).onToggle(function(st) S.zoom = st end)
createButton("Zoom Key: " .. S.zoomKey.Name, function(b)
    b.Text = "Нажми клавишу..."
    waitKey(function(kc)
        if kc ~= Enum.KeyCode.Escape then S.zoomKey = kc end
        b.Text = "Zoom Key: " .. S.zoomKey.Name
    end)
end)
createTumbler("Crosshair", false).onToggle(function(st) S.crosshair = st end)
createSection("Мир")
createTumbler("Fullbright", false).onToggle(function(st)
    S.fullbright = st
    if st then applyLighting() else restoreLighting("fb") end
end)
createTumbler("No Fog", false).onToggle(function(st)
    S.noFog = st
    if st then applyLighting() else restoreLighting("fog") end
end)
createSlider("Время суток", 0, 24, 14, function(v) Lighting.ClockTime = v end)
createSlider("Гравитация", 20, 300, 196, function(v)
    S.savedGravity = v
    if not S.fly then workspace.Gravity = v end
end)
createButton("FPS Boost (убрать текстуры/частицы)", function()
    notify("FPS Boost...")
    task.spawn(function()
        pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Level01 end)
        Lighting.GlobalShadows = false
        local desc, n = workspace:GetDescendants(), 0
        for i = 1, #desc do
            local o = desc[i]
            if o:IsA("BasePart") then o.Material = Enum.Material.SmoothPlastic o.CastShadow = false
            elseif o:IsA("Decal") or o:IsA("Texture") then o.Transparency = 1
            elseif o:IsA("ParticleEmitter") or o:IsA("Trail") or o:IsA("Smoke") or o:IsA("Fire") then o.Enabled = false end
            n += 1
            if n % 1500 == 0 then task.wait() end
        end
        notify("FPS Boost готов", "success")
    end)
end)
createSection("Утилиты")
createTumbler("Click TP (Ctrl + клик)", false).onToggle(function(st) S.clickTP = st end)
createTumbler("Auto Clicker", false).onToggle(function(st) S.autoClick = st S.clickAcc = 0 end)
createSlider("Clicker CPS", 1, 50, 10, function(v) S.cps = v end)
createButton("Reset Character", function()
    local _, _, hum = getChar()
    if hum then hum.Health = 0 end
end)
createButton("Rejoin", function()
    notify("Реджойн...")
    pcall(function()
        if #Players:GetPlayers() <= 1 then TeleportService:Teleport(game.PlaceId, LocalPlayer)
        else TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer) end
    end)
end)
createButton("Server Hop", function()
    notify("Ищу другой сервер...")
    task.spawn(function()
        local ok, data = pcall(function()
            return HttpService:JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"))
        end)
        if ok and type(data) == "table" and data.data then
            local cands = {}
            for _, sv in ipairs(data.data) do
                if sv.id ~= game.JobId and sv.playing < sv.maxPlayers then cands[#cands + 1] = sv.id end
            end
            if #cands > 0 then
                pcall(function() TeleportService:TeleportToPlaceInstance(game.PlaceId, cands[math.random(#cands)], LocalPlayer) end)
                return
            end
        end
        notify("Сервер не найден", "error")
    end)
end)
createButton("Копировать JobId", function()
    if setclipboard then setclipboard(game.JobId) notify("JobId скопирован", "success") else notify("setclipboard недоступен", "error") end
end)

createSection("Позиции")
do
    local saved
    createButton("Сохранить позицию", function()
        local _, r = getChar()
        if r then saved = r.CFrame notify("Позиция сохранена", "success") end
    end)
    createButton("ТП на сохранённую", function()
        local _, r = getChar()
        if r and saved then r.CFrame = saved notify("ТП на точку", "success") else notify("Нет сохранённой позиции", "error") end
    end)
    createButton("Копировать координаты", function()
        local _, r = getChar()
        if r and setclipboard then
            local p = r.Position
            setclipboard(string.format("%.1f, %.1f, %.1f", p.X, p.Y, p.Z))
            notify("Координаты скопированы", "success")
        else notify("setclipboard недоступен", "error") end
    end)
    createButton("ТП к случайному игроку", function()
        local list = {}
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then list[#list + 1] = p end
        end
        local _, r = getChar()
        if r and #list > 0 then
            local p = list[math.random(#list)]
            r.CFrame = p.Character.HumanoidRootPart.CFrame + Vector3.new(0, 3, 0)
            notify("ТП к " .. p.Name, "success")
        else notify("Нет игроков", "error") end
    end)
end
createTumbler("Координаты в ватермарке", false, { bindable = false }).onToggle(function(st) S.coords = st end)
createSelector("FPS Cap", { { "Default", 0 }, { "30", 30 }, { "60", 60 }, { "120", 120 }, { "240", 240 }, { "Unlimited", 999 } }, 1, function(v)
    if v ~= 0 and setfpscap then pcall(setfpscap, v) end
end)

-- ========== TAB: COSMETICS ==========
createTab("Cosmetics")
createSection("Аксессуары")
createTumbler("Headless", false).onToggle(function(st)
    S.headless = st
    if st then applyHeadless() else removeCosmetics() end
end)
createTumbler("Korblox", false).onToggle(function(st)
    S.korblox = st
    if st then applyKorblox() else removeCosmetics() end
end)
createSection("Анимации")
do
    local AB
    AB = createBrowser({
        placeholder = "Поиск пака анимаций...",
        label = function(n) return n end,
        onClick = function(name) task.spawn(applyPack, name) end,
        onSearch = function(q)
            q = q:lower()
            local out = {}
            for name in pairs(PACKS) do
                if q == "" or name:lower():find(q, 1, true) then out[#out + 1] = name end
            end
            table.sort(out, function(a, b) return a:lower() < b:lower() end)
            AB.setItems(out)
            AB.status(#out .. " паков", T.ok)
        end,
    })
    AB.setItems((function()
        local out = {}
        for name in pairs(PACKS) do out[#out + 1] = name end
        table.sort(out, function(a, b) return a:lower() < b:lower() end)
        return out
    end)())
    AB.status("Нажми на пак, чтобы применить", T.dim)
end

-- ========== TAB: EMOTES ==========
local playWiaEmote, stopCurrentEmote
do
    createTab("Emotes")
    createSection("Emote Library")
    local emoteLibrary, emoteBusy = {}, false
    local emoteCurrentId, emoteCurrentTrack
    local ugcCache, ugcCursors, ugcIdx, ugcNext, ugcQuery, ugcHas = {}, { "" }, 1, "", "", false
    local fallbackJson = '[{"id":14353423348,"animationid":"http://www.roblox.com/asset/?id=14352343065","name":"BabyQueen-BouncyTwirl"},{"id":14353421343,"animationid":"http://www.roblox.com/asset/?id=14352340648","name":"BabyQueen-FaceFrame"},{"id":16553249658,"animationid":"http://www.roblox.com/asset/?id=16553163212","name":"MaeStephens-PianoHands"}]'
    local libUrl = "https://raw.githubusercontent.com/Joystickplays/AFEM/refs/heads/main/emotes.json"
    local EB

    local function norm(v)
        if v == nil then return nil end
        local s = tostring(v)
        local id = s:match("rbxassetid://(%d+)") or s:match("[?&]id=(%d+)") or s:match("(%d+)")
        return id and ("rbxassetid://" .. id) or nil
    end
    local function applyEmoteOpts()
        if emoteCurrentTrack then
            pcall(function()
                emoteCurrentTrack.Looped = S.emoteLoop
                emoteCurrentTrack:AdjustSpeed(S.emoteSpeed / 100)
            end)
        end
    end

    stopCurrentEmote = function()
        local stopped = false
        if emoteCurrentTrack then
            pcall(function() emoteCurrentTrack:Stop(0.15) end)
            pcall(function() emoteCurrentTrack:Destroy() end)
            emoteCurrentTrack = nil
            stopped = true
        end
        local _, _, hum = getChar()
        local animator = hum and hum:FindFirstChildOfClass("Animator")
        if animator then
            for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
                local anim = track.Animation
                if anim and (anim.Name == "WIAHubEmote" or anim.Name == "AFEMInvokedEmote" or (emoteCurrentId and norm(anim.AnimationId) == emoteCurrentId)) then
                    pcall(function() track:Stop(0.15) end)
                    stopped = true
                end
            end
        end
        emoteCurrentId = nil
        return stopped
    end

    playWiaEmote = function(rawId, emoteName)
        local animationId = norm(rawId)
        if not animationId then EB.status("Invalid animation ID", T.err) return false end
        local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum then EB.status("Humanoid not found", T.err) return false end
        stopCurrentEmote()
        local anim = Instance.new("Animation")
        anim.Name = "AFEMInvokedEmote"
        anim.AnimationId = animationId
        local animate = char:FindFirstChild("Animate")
        local playFunc = animate and animate:FindFirstChild("PlayEmote")
        if playFunc and playFunc:IsA("BindableFunction") and pcall(function() playFunc:Invoke(anim) end) then
            emoteCurrentId = animationId
            task.defer(function()
                task.wait(0.1)
                local _, _, h = getChar()
                local animator = h and h:FindFirstChildOfClass("Animator")
                if animator then
                    for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
                        if track.Animation and norm(track.Animation.AnimationId) == animationId then
                            emoteCurrentTrack = track
                            applyEmoteOpts()
                            break
                        end
                    end
                end
            end)
            EB.status("Playing: " .. tostring(emoteName or "Emote"), T.ok)
            return true
        end
        local animator = hum:FindFirstChildOfClass("Animator") or new("Animator", {}, hum)
        local direct = new("Animation", { Name = "WIAHubEmote", AnimationId = animationId })
        local ok, track = pcall(function() return animator:LoadAnimation(direct) end)
        if not ok or not track then
            direct:Destroy()
            EB.status("Can't load this animation", T.err)
            return false
        end
        emoteCurrentTrack, emoteCurrentId = track, animationId
        track.Priority = Enum.AnimationPriority.Action
        if not pcall(function() track:Play(0.15, 1, 1) end) then
            pcall(function() track:Destroy() end)
            emoteCurrentTrack = nil
            EB.status("Animation failed to play", T.err)
            return false
        end
        applyEmoteOpts()
        EB.status("Playing: " .. tostring(emoteName or "Emote"), T.ok)
        return true
    end

    local function renderAfem(q)
        q = (q or ""):lower()
        local out = {}
        for _, e in ipairs(emoteLibrary) do
            if q == "" or e._low:find(q, 1, true) then out[#out + 1] = e end
        end
        EB.remote = false
        EB.setItems(out)
        EB.status(#out > 0 and ("AFEM list · " .. #out .. " emotes") or "No matching emotes", #out > 0 and T.ok or T.dim)
    end

    local function ugcUrl(query, cursor)
        local url = query ~= "" and ("https://catalog.roblox.com/v1/search/items/details?Category=12&SortType=Relevance&IncludeNotForSale=true&Limit=30&Keyword=" .. HttpService:UrlEncode(query))
            or "https://catalog.roblox.com/v1/search/items/details?Category=12&SortType=Updated&IncludeNotForSale=true&Limit=30"
        if cursor and cursor ~= "" then url ..= "&cursor=" .. HttpService:UrlEncode(cursor) end
        return url
    end

    local function fetchUgc(reset, dir)
        if emoteBusy then return end
        if reset then
            ugcQuery = EB.query() ugcCursors = { "" } ugcIdx = 1 ugcNext = ""
        elseif dir == "next" then
            if not ugcHas or ugcNext == "" then return end
            ugcIdx += 1 ugcCursors[ugcIdx] = ugcNext
        elseif dir == "prev" then
            if ugcIdx <= 1 then return end
            ugcIdx -= 1
        end
        emoteBusy = true
        EB.remote = true
        EB.setItems({})
        EB.setNav(false, false)
        EB.status("Fetching Roblox UGC catalog...")
        local cursor = ugcCursors[ugcIdx] or ""
        task.spawn(function()
            local decoded
            local ok = pcall(function() decoded = HttpService:JSONDecode(game:HttpGet(ugcUrl(ugcQuery, cursor))) end)
            if not ok or type(decoded) ~= "table" then
                EB.status("Catalog request failed", T.err)
                emoteBusy = false
                return
            end
            local items = {}
            for _, e in ipairs(decoded.data or {}) do if e.id and e.name then items[#items + 1] = e end end
            ugcNext = decoded.nextPageCursor or ""
            ugcHas = ugcNext ~= ""
            EB.setItems(items)
            EB.setNav(ugcIdx > 1, ugcHas)
            EB.status(#items > 0 and ("UGC catalog · page " .. ugcIdx .. " · " .. #items .. " results") or "No emotes found", #items > 0 and T.ok or T.dim)
            emoteBusy = false
        end)
    end

    local function resolveUgc(entry)
        local assetId = tonumber(entry.id)
        if not assetId then EB.status("Invalid catalog asset", T.err) return end
        if ugcCache[assetId] then playWiaEmote(ugcCache[assetId], entry.name) return end
        if emoteBusy then return end
        emoteBusy = true
        EB.status("Resolving UGC animation: " .. entry.name .. "...")
        task.spawn(function()
            local animId
            pcall(function()
                local delivery = HttpService:JSONDecode(game:HttpGet("https://assetdelivery.roblox.com/v1/assetId/" .. assetId))
                if delivery and delivery.location then
                    local content = game:HttpGet(delivery.location)
                    local raw = content:match("rbxassetid://(%d+)") or content:match("[?&]id=(%d+)")
                    if raw then animId = "rbxassetid://" .. raw end
                end
            end)
            if animId then ugcCache[assetId] = animId playWiaEmote(animId, entry.name)
            else EB.status("Couldn't resolve animation. It may be unavailable.", T.err) end
            emoteBusy = false
        end)
    end

    EB = createBrowser({
        modes = { { "AFEM", "AFEM LIST" }, { "UGC", "UGC CATALOG" } },
        placeholder = "Search emotes...",
        label = function(e) return tostring(e.name or e.title or "Emote") .. "  ·  " .. tostring(e.id or "") end,
        onClick = function(e, mode)
            if mode == "UGC" then resolveUgc(e)
            else playWiaEmote(e.animationid or e.animationId or e.AnimationId or e.id, e.name) end
        end,
        onMode = function(m) if m == "UGC" then fetchUgc(true) else renderAfem(EB.query()) end end,
        onSearch = function(q, m) if m == "UGC" then fetchUgc(true) else renderAfem(q) end end,
        onPrev = function() fetchUgc(false, "prev") end,
        onNext = function() fetchUgc(false, "next") end,
    })
    EB.status("Loading AFEM list...")
    task.spawn(function()
        local decoded
        local ok = pcall(function() decoded = HttpService:JSONDecode(game:HttpGet(libUrl)) end)
        if not ok or type(decoded) ~= "table" then pcall(function() decoded = HttpService:JSONDecode(fallbackJson) end) end
        emoteLibrary = type(decoded) == "table" and decoded or {}
        for _, e in ipairs(emoteLibrary) do e._low = string.lower(tostring(e.name or e.title or "")) end
        if EB.mode == "AFEM" then renderAfem(EB.query()) end
    end)

    createButton("Стоп эмоут", function() if stopCurrentEmote() then notify("Эмоут остановлен") end end)
    createTumbler("Loop Emote", false, { bindable = false }).onToggle(function(st) S.emoteLoop = st applyEmoteOpts() end)
    createSlider("Скорость эмоута %", 10, 300, 100, function(v) S.emoteSpeed = v applyEmoteOpts() end)
    createButton("Копировать ID текущего эмоута", function()
        local id = emoteCurrentId and emoteCurrentId:match("%d+")
        if id and setclipboard then setclipboard(id) notify("ID скопирован: " .. id, "success") else notify("Нет активного эмоута", "error") end
    end)
    createSection("По ID")
    createInputRow("ID эмоута", "ID эмоута / анимации", "Play", function(txt)
        if txt == "" then notify("Введи ID", "error") return end
        playWiaEmote(txt, "ID " .. txt)
    end)
    createSelector("Слот анимации", { { "Walk", "WalkAnim" }, { "Run", "RunAnim" }, { "Jump", "JumpAnim" }, { "Fall", "FallAnim" }, { "Climb", "ClimbAnim" }, { "Idle", "Animation1" }, { "Idle 2", "Animation2" }, { "Swim", "Swim" }, { "Swim Idle", "SwimIdle" } }, 1, function(v) S.idSlot = v end)
    createInputRow("ID для слота", "ID анимации для слота", "Apply", function(txt)
        local id = txt:match("%d+")
        if not id then notify("Нужен числовой ID", "error") return end
        local pack = PACKS["Custom IDs"] or {}
        PACKS["Custom IDs"] = pack
        pack[S.idSlot or "WalkAnim"] = tonumber(id)
        task.spawn(applyPack, "Custom IDs")
    end)
end

-- ========== TAB: SNIPER (v15: новый дизайн, надёжная загрузка эмоций, избранное, история, эффекты) ==========
do
    createTab("Sniper")
    local page = currentPage
    local SNIPER_FILES = { emotes = "wia_emotes.txt", anims = "wia_anims.txt", offsale = "wia_anims_offsale.txt" }
    local FAV_FILE = "wia_sniper_fav.json"
    local AFEM_URL = "https://raw.githubusercontent.com/Joystickplays/AFEM/refs/heads/main/emotes.json"
    local ROWS = 30
    local sniperData, sniperBusy, animCache = {}, false, {}
    local SN = {
        mode = "emotes", items = {}, page = 1, remote = false,
        favs = {}, favSet = {}, hist = {},
        cursors = { "" }, cidx = 1, nextCur = "", liveQ = "",
        afem = nil, sort = 1, token = 0, partyIdx = 0, src = 1,
    }
    local ui = {}
    S.snpInterval = 8
    S.snpGhost = 0

    -- ---------- helpers ----------
    local function httpGet(url)
        local ok, r = pcall(function() return game:HttpGet(url) end)
        if ok and type(r) == "string" and #r > 0 then return r end
        local req = (syn and syn.request) or (http and http.request) or http_request or request
        if req then
            local ok2, res = pcall(req, { Url = url, Method = "GET" })
            if ok2 and type(res) == "table" and type(res.Body) == "string" and (res.StatusCode == nil or res.StatusCode == 200) then
                return res.Body
            end
        end
        return nil
    end
    local function digitsOf(s) return tostring(s or ""):match("(%d+)") end
    local function keyOf(e) return tostring(e.id) .. ":" .. tostring(e.kind or "emotes") end
    local function setStatus(msg, col)
        if ui.status then ui.status.Text = tostring(msg) ui.status.TextColor3 = col or T.dim end
        if ui.dot then ui.dot.BackgroundColor3 = col or T.dim end
    end

    -- ---------- favorites ----------
    local function saveFavs()
        if not writefile then return end
        pcall(function() writefile(FAV_FILE, HttpService:JSONEncode(SN.favs)) end)
    end
    local function loadFavs()
        if not (isfile and readfile) then return end
        pcall(function()
            if not isfile(FAV_FILE) then return end
            local d = HttpService:JSONDecode(readfile(FAV_FILE))
            if type(d) ~= "table" then return end
            for _, e in ipairs(d) do
                if type(e) == "table" and e.id and e.name then
                    e.low = string.lower(tostring(e.name))
                    SN.favs[#SN.favs + 1] = e
                    SN.favSet[keyOf(e)] = true
                end
            end
        end)
    end
    loadFavs()

    -- ---------- data files ----------
    local function parseSniper(mode, text)
        text = text:gsub("^\239\187\191", "")
        local list, n, i = {}, 0, 0
        local first = text:match("[^\n]+") or ""
        local sep = "\t"
        if not first:find("\t", 1, true) then
            sep = first:find("|", 1, true) and "|" or (first:find(";", 1, true) and ";" or ",")
        end
        for line in string.gmatch(text, "[^\n]+") do
            i += 1
            local f = string.split((line:gsub("\r", "")), sep)
            local id = f[1] and f[1]:match("%d+")
            if id and f[2] and f[2] ~= "" then
                local e = { id = id, name = f[2], low = string.lower(f[2]), kind = mode }
                if mode ~= "emotes" and #f >= 9 then e.items = { f[3], f[4], f[5], f[6], f[7], f[8], f[9] } end
                n += 1
                list[n] = e
            end
            if i % 3000 == 0 then task.wait() end
        end
        return list
    end
    local function ensureData(mode)
        if sniperData[mode] then return #sniperData[mode] > 0 end
        local file = SNIPER_FILES[mode]
        if not file then return false end
        setStatus("Загрузка " .. file .. "…", T.dim)
        local text = SNIPER_DATA[mode]
        if not text then
            local r = httpGet(BASE .. file)
            if r and #r > 100 then
                text = r
                if writefile then pcall(writefile, file, r) end
            end
        end
        if not text then return false end
        local list = parseSniper(mode, text)
        if #list == 0 then return false end
        sniperData[mode] = list
        return true
    end
    local function loadAfem()
        if SN.afem then return SN.afem end
        local body = httpGet(AFEM_URL)
        local list = {}
        pcall(function()
            local d = HttpService:JSONDecode(body or "[]")
            for _, e in ipairs(d) do
                local id = e.id and tostring(e.id):match("%d+")
                local nm = e.name or e.title
                if id and nm then
                    list[#list + 1] = {
                        id = id, name = tostring(nm), low = string.lower(tostring(nm)), kind = "emotes",
                        anim = digitsOf(e.animationid or e.animationId or e.AnimationId),
                    }
                end
            end
        end)
        SN.afem = list
        return list
    end

    -- ---------- animation resolving (несколько способов, чтобы эмоции грузились) ----------
    local function loadAssetObjects(assetId)
        local ok, objs = pcall(function() return game:GetObjects("rbxassetid://" .. tostring(assetId)) end)
        if ok and type(objs) == "table" and #objs > 0 then return objs end
    end
    local function collectAnimations(objs)
        local out = {}
        for _, o in ipairs(objs) do
            if o:IsA("Animation") then out[#out + 1] = o end
            for _, d in ipairs(o:GetDescendants()) do if d:IsA("Animation") then out[#out + 1] = d end end
        end
        return out
    end
    local function resolveCandidates(assetId)
        assetId = tostring(assetId)
        if animCache[assetId] then return animCache[assetId] end
        local out, seen = {}, {}
        local function add(id)
            if id and not seen[id] then seen[id] = true out[#out + 1] = "rbxassetid://" .. id end
        end
        -- 1) GetObjects
        local objs = loadAssetObjects(assetId)
        if objs then
            for _, a in ipairs(collectAnimations(objs)) do add(digitsOf(a.AnimationId)) end
            for _, o in ipairs(objs) do pcall(function() o:Destroy() end) end
        end
        -- 2) InsertService
        if #out == 0 then
            pcall(function()
                local m = InsertService:LoadAsset(tonumber(assetId))
                if m then
                    for _, a in ipairs(collectAnimations({ m })) do add(digitsOf(a.AnimationId)) end
                    m:Destroy()
                end
            end)
        end
        -- 3) assetdelivery v2 / v1
        if #out == 0 then
            for _, url in ipairs({
                "https://assetdelivery.roblox.com/v2/assetId/" .. assetId,
                "https://assetdelivery.roblox.com/v1/assetId/" .. assetId,
            }) do
                local body = httpGet(url)
                if body then
                    local loc
                    pcall(function()
                        local d = HttpService:JSONDecode(body)
                        loc = d.location or (d.locations and d.locations[1] and d.locations[1].location)
                    end)
                    if loc then
                        local content = httpGet(loc)
                        if content then
                            for id in content:gmatch("rbxassetid://(%d+)") do add(id) end
                            for id in content:gmatch("[?&]id=(%d+)") do add(id) end
                        end
                    end
                end
                if #out > 0 then break end
            end
        end
        -- 4) крайний случай: сам ID ассета как анимация
        add(assetId)
        animCache[assetId] = out
        return out
    end

    -- ---------- playback ----------
    local cur = { track = nil, name = nil, frozen = false }
    local function npUpdate()
        if not ui.npName then return end
        ui.npName.Text = cur.name and ("▶  " .. cur.name) or "Ничего не играет"
        ui.npName.TextColor3 = cur.name and T.text or T.dim
        if ui.loopBtn then
            ui.loopBtn.BackgroundColor3 = S.emoteLoop and T.accent or T.rowd
            ui.loopBtn.TextColor3 = S.emoteLoop and T.onAccent or T.text
        end
        if ui.spdLbl then ui.spdLbl.Text = tostring(S.emoteSpeed or 100) .. "%" end
    end
    local function applyMine()
        if cur.track then
            pcall(function()
                cur.track.Looped = S.emoteLoop and true or false
                cur.track:AdjustSpeed(cur.frozen and 0 or ((S.emoteSpeed or 100) / 100))
            end)
        end
        npUpdate()
    end
    local function stopMine()
        if cur.track then
            pcall(function() cur.track:Stop(0.15) end)
            pcall(function() cur.track:Destroy() end)
        end
        cur.track, cur.name, cur.frozen = nil, nil, false
        npUpdate()
    end
    local function tryPlay(animId, name)
        local _, _, hum = getChar()
        if not hum then return false end
        pcall(stopCurrentEmote)
        stopMine()
        local animator = hum:FindFirstChildOfClass("Animator") or new("Animator", {}, hum)
        local a = new("Animation", { Name = "WIASniper", AnimationId = animId })
        local ok, track = pcall(function() return animator:LoadAnimation(a) end)
        if not ok or not track then pcall(function() a:Destroy() end) return false end
        local t0 = os.clock()
        while track.Length <= 0 and os.clock() - t0 < 3 do task.wait(0.05) end
        if track.Length <= 0 then pcall(function() track:Destroy() end) return false end
        track.Priority = Enum.AnimationPriority.Action
        track.Looped = S.emoteLoop and true or false
        if not pcall(function() track:Play(0.15, 1, (S.emoteSpeed or 100) / 100) end) then
            pcall(function() track:Destroy() end)
            return false
        end
        cur.track, cur.name, cur.frozen = track, name, false
        track.Stopped:Connect(function()
            if cur.track == track then cur.track, cur.name, cur.frozen = nil, nil, false npUpdate() end
        end)
        npUpdate()
        return true
    end
    local function addHist(e)
        for i = #SN.hist, 1, -1 do if keyOf(SN.hist[i]) == keyOf(e) then table.remove(SN.hist, i) end end
        table.insert(SN.hist, 1, e)
        while #SN.hist > 60 do table.remove(SN.hist) end
    end
    local function playEmote(entry)
        if sniperBusy then return end
        sniperBusy = true
        setStatus("Загрузка: " .. entry.name .. "…", T.dim)
        task.spawn(function()
            local ok, err = pcall(function()
                local cands = {}
                if entry.anim then cands[1] = "rbxassetid://" .. entry.anim end
                for _, c in ipairs(resolveCandidates(entry.id)) do cands[#cands + 1] = c end
                local played = false
                for _, aid in ipairs(cands) do
                    if tryPlay(aid, entry.name) then played = true break end
                end
                if played then
                    addHist(entry)
                    setStatus("▶ " .. entry.name, T.ok)
                else
                    setStatus("Не удалось загрузить анимацию (недоступна / нет GetObjects)", T.err)
                    notify("Эмоут не загрузился", "error")
                end
            end)
            if not ok then setStatus("Ошибка: " .. tostring(err), T.err) end
            sniperBusy = false
        end)
    end

    -- ---------- bundles (анимации-паки) ----------
    local function slotByName(n)
        if n:find("swimidle", 1, true) then return "SwimIdle" end
        if n:find("swim", 1, true) then return "Swim" end
        if n:find("walk", 1, true) then return "WalkAnim" end
        if n:find("run", 1, true) then return "RunAnim" end
        if n:find("jump", 1, true) then return "JumpAnim" end
        if n:find("fall", 1, true) then return "FallAnim" end
        if n:find("climb", 1, true) then return "ClimbAnim" end
        local num = n:match("^animation(%d+)$")
        if num then return "Animation" .. num end
        if n:find("idle", 1, true) then return "IDLE" end
    end
    local function classifyAnim(inst)
        local slot = slotByName(string.lower(inst.Name))
        if not slot and inst.Parent then slot = slotByName(string.lower(inst.Parent.Name)) end
        return slot
    end
    local function applyBundle(entry)
        if sniperBusy or not entry.items then return end
        local key = "Sniper: " .. entry.name .. " #" .. entry.id
        if PACKS[key] then
            task.spawn(applyPack, key)
            addHist(entry)
            setStatus("Анимация: " .. entry.name, T.ok)
            return
        end
        sniperBusy = true
        setStatus("Загрузка пака: " .. entry.name .. "…", T.dim)
        task.spawn(function()
            local ok, err = pcall(function()
                local pack, found, idleN = {}, 0, 0
                for _, assetId in ipairs(entry.items) do
                    local objs = loadAssetObjects(assetId)
                    if objs then
                        for _, a in ipairs(collectAnimations(objs)) do
                            local id = digitsOf(a.AnimationId)
                            if id then
                                local slot = classifyAnim(a)
                                if slot == "IDLE" then idleN += 1 slot = "Animation" .. math.min(idleN, 2) end
                                if slot and not pack[slot] then pack[slot] = id found += 1 end
                            end
                        end
                        for _, o in ipairs(objs) do pcall(function() o:Destroy() end) end
                    end
                    task.wait()
                end
                if found > 0 then
                    PACKS[key] = pack
                    applyPack(key)
                    addHist(entry)
                    setStatus("Анимация: " .. entry.name .. " (" .. found .. " слотов)", T.ok)
                else
                    setStatus("Пак не загрузился (оффсейл / нет GetObjects)", T.err)
                    notify("Пак не загрузился", "error")
                end
            end)
            if not ok then setStatus("Ошибка: " .. tostring(err), T.err) end
            sniperBusy = false
        end)
    end
    local function activate(e)
        if e.items then applyBundle(e) else playEmote(e) end
    end

    -- ---------- results rendering ----------
    local rows, handlers = {}, {}
    local render
    local function toggleFav(e)
        local k = keyOf(e)
        if SN.favSet[k] then
            SN.favSet[k] = nil
            for i = #SN.favs, 1, -1 do if keyOf(SN.favs[i]) == k then table.remove(SN.favs, i) end end
            setStatus("Убрано из избранного", T.dim)
        else
            SN.favSet[k] = true
            SN.favs[#SN.favs + 1] = { id = e.id, name = e.name, low = e.low, kind = e.kind or "emotes", items = e.items, anim = e.anim }
            setStatus("♥ В избранном: " .. e.name, T.ok)
        end
        saveFavs()
        render()
    end
    local function smallBtn(parent, text, xOff, accent)
        local b = new("TextButton", {
            Size = UDim2.new(0, 28, 0, 28), Position = UDim2.new(1, xOff, 0.5, -14), Text = text,
            TextColor3 = accent and T.onAccent or T.dim, TextSize = 13, Font = Enum.Font.GothamBold,
            BackgroundColor3 = accent and T.accent or T.rowd, BorderSizePixel = 0, ZIndex = 3,
        }, parent)
        if accent then ref(b, "BackgroundColor3") end
        addCorner(b, 7)
        return b
    end
    local function getRow(i)
        local r = rows[i]
        if r then return r end
        local f = new("Frame", { Size = UDim2.new(1, -2, 0, 40), BackgroundColor3 = T.row, BorderSizePixel = 0, LayoutOrder = i, Visible = false }, ui.results)
        addCorner(f, 8) hover(f)
        addStroke(f, T.stroke, 1, 0.6)
        local bar = new("Frame", { Size = UDim2.new(0, 3, 1, -14), Position = UDim2.new(0, 6, 0, 7), BorderSizePixel = 0 }, f)
        ref(bar, "BackgroundColor3") addCorner(bar, 2, true)
        local name = new("TextLabel", { Size = UDim2.new(1, -124, 0, 18), Position = UDim2.new(0, 17, 0, 4), BackgroundTransparency = 1, Text = "", TextColor3 = T.text, TextSize = 12, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd }, f)
        local sub = new("TextLabel", { Size = UDim2.new(1, -124, 0, 14), Position = UDim2.new(0, 17, 0, 22), BackgroundTransparency = 1, Text = "", TextColor3 = T.dim, TextSize = 10, Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd }, f)
        local body = new("TextButton", { Size = UDim2.new(1, -108, 1, 0), BackgroundTransparency = 1, Text = "", ZIndex = 2 }, f)
        local playB = smallBtn(f, "▶", -36, true)
        local favB = smallBtn(f, "♡", -68)
        local copyB = smallBtn(f, "⧉", -100)
        local function click() local it = handlers[i] if it then sfx("tap") activate(it) end end
        body.MouseButton1Click:Connect(click)
        playB.MouseButton1Click:Connect(click)
        favB.MouseButton1Click:Connect(function() local it = handlers[i] if it then sfx("tap") toggleFav(it) end end)
        copyB.MouseButton1Click:Connect(function()
            local it = handlers[i]
            if it and setclipboard then setclipboard(tostring(it.id)) notify("ID скопирован: " .. it.id, "success") end
        end)
        r = { f = f, name = name, sub = sub, fav = favB }
        rows[i] = r
        return r
    end
    render = function()
        local total = #SN.items
        local pages = math.max(1, math.ceil(total / ROWS))
        SN.page = math.clamp(SN.page, 1, pages)
        local from = (SN.page - 1) * ROWS
        for i = 1, ROWS do
            local it = SN.items[from + i]
            local r = getRow(i)
            if it then
                local isFav = SN.favSet[keyOf(it)]
                handlers[i] = it
                r.name.Text = tostring(it.name)
                r.sub.Text = "#" .. tostring(it.id) .. (it.items and "  ·  пак анимаций" or "  ·  эмоут")
                r.fav.Text = isFav and "♥" or "♡"
                r.fav.TextColor3 = isFav and T.err or T.dim
                r.f.Visible = true
            else
                handlers[i] = nil
                r.f.Visible = false
            end
        end
        ui.results.CanvasPosition = Vector2.zero
        ui.empty.Visible = total == 0
        ui.count.Text = tostring(total)
        if SN.remote then
            ui.prev.Visible = SN.cidx > 1
            ui.next.Visible = SN.nextCur ~= ""
            ui.pageLbl.Text = "стр. " .. SN.cidx
        else
            ui.prev.Visible = SN.page > 1
            ui.next.Visible = SN.page < pages
            ui.pageLbl.Text = total > 0 and (SN.page .. " / " .. pages) or ""
        end
    end
    local function sortItems(list)
        if SN.sort == 2 then table.sort(list, function(a, b) return a.low < b.low end)
        elseif SN.sort == 3 then table.sort(list, function(a, b) return a.low > b.low end)
        elseif SN.sort == 4 then table.sort(list, function(a, b) return (tonumber(a.id) or 0) > (tonumber(b.id) or 0) end) end
    end

    -- ---------- live catalog ----------
    local function liveUrl(q, cursor)
        local url = q ~= "" and ("https://catalog.roblox.com/v1/search/items/details?Category=12&SortType=Relevance&IncludeNotForSale=true&Limit=30&Keyword=" .. HttpService:UrlEncode(q))
            or "https://catalog.roblox.com/v1/search/items/details?Category=12&SortType=Updated&IncludeNotForSale=true&Limit=30"
        if cursor and cursor ~= "" then url ..= "&cursor=" .. HttpService:UrlEncode(cursor) end
        return url
    end
    local function fetchLive(reset, dir)
        if sniperBusy then return end
        if reset then
            SN.liveQ = trim(ui.search.Text) SN.cursors = { "" } SN.cidx = 1 SN.nextCur = ""
        elseif dir == "next" then
            if SN.nextCur == "" then return end
            SN.cidx += 1 SN.cursors[SN.cidx] = SN.nextCur
        elseif dir == "prev" then
            if SN.cidx <= 1 then return end
            SN.cidx -= 1
        end
        sniperBusy = true
        SN.remote = true
        setStatus("Запрос каталога Roblox…", T.dim)
        task.spawn(function()
            local ok = pcall(function()
                local body = httpGet(liveUrl(SN.liveQ, SN.cursors[SN.cidx] or ""))
                local d = body and HttpService:JSONDecode(body)
                if type(d) ~= "table" then setStatus("Каталог не ответил — попробуй ещё раз", T.err) return end
                local items = {}
                for _, e in ipairs(d.data or {}) do
                    if e.id and e.name then
                        items[#items + 1] = { id = tostring(e.id), name = tostring(e.name), low = string.lower(tostring(e.name)), kind = "emotes" }
                    end
                end
                SN.nextCur = d.nextPageCursor or ""
                SN.items, SN.page = items, 1
                render()
                setStatus(#items > 0 and ("LIVE · стр. " .. SN.cidx .. " · " .. #items .. " шт.") or "Ничего не найдено", #items > 0 and T.ok or T.dim)
            end)
            if not ok then setStatus("Ошибка запроса каталога", T.err) end
            sniperBusy = false
        end)
    end

    local setMode
    local function runSearch(q, mode)
        mode = mode or SN.mode
        if mode == "live" then fetchLive(true) return end
        if sniperBusy then return end
        sniperBusy = true
        SN.remote = false
        local fallback = false
        task.spawn(function()
            local ok, err = pcall(function()
                local list
                if mode == "afem" then setStatus("Загрузка AFEM…", T.dim) list = loadAfem()
                elseif mode == "fav" then list = SN.favs
                elseif mode == "hist" then list = SN.hist
                elseif ensureData(mode) then list = sniperData[mode] end
                if (not list or #list == 0) and (mode == "emotes" or mode == "anims" or mode == "offsale" or mode == "afem") then
                    fallback = true
                    return
                end
                q = string.lower(q or "")
                local out, n = {}, 0
                for i = 1, #(list or {}) do
                    local e = list[i]
                    if q == "" or e.id == q or string.find(e.low or "", q, 1, true) then n += 1 out[n] = e end
                    if i % 30000 == 0 then task.wait() end
                end
                sortItems(out)
                SN.items, SN.page = out, 1
                render()
                setStatus(n > 0 and (string.upper(mode) .. " · " .. n .. " найдено") or "Ничего не найдено", n > 0 and T.ok or T.dim)
            end)
            sniperBusy = false
            if not ok then setStatus("Ошибка: " .. tostring(err), T.err) end
            if fallback then
                setStatus("Файл данных не найден — открываю LIVE-каталог", T.err)
                setMode("live", true)
            end
        end)
    end
    setMode = function(m, fire)
        SN.mode = m
        for k, b in pairs(ui.modeBtns) do
            local on = k == m
            TweenService:Create(b, TweenInfo.new(0.12), { BackgroundColor3 = on and T.accent or T.row, TextColor3 = on and T.onAccent or T.text }):Play()
        end
        if fire then runSearch(trim(ui.search.Text), m) end
    end

    -- ---------- UI: header ----------
    do
        local head = new("Frame", { Size = UDim2.new(1, 0, 0, 62), BackgroundColor3 = T.row, BorderSizePixel = 0 }, page)
        addCorner(head, 10) addStroke(head, T.stroke, 1, 0.3)
        local stripe = new("Frame", { Size = UDim2.new(0, 5, 1, -16), Position = UDim2.new(0, 8, 0, 8), BorderSizePixel = 0 }, head)
        ref(stripe, "BackgroundColor3") addCorner(stripe, 3, true)
        new("TextLabel", { Size = UDim2.new(1, -120, 0, 24), Position = UDim2.new(0, 22, 0, 8), BackgroundTransparency = 1, Text = "🎯  Catalog Sniper", TextColor3 = T.text, TextSize = 16, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left }, head)
        new("TextLabel", { Size = UDim2.new(1, -120, 0, 24), Position = UDim2.new(0, 22, 0, 32), BackgroundTransparency = 1, Text = "Эмоции и анимации · ▶ сыграть · ♡ в избранное · ⧉ копировать ID", TextColor3 = T.dim, TextSize = 10, Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd }, head)
        local chip = new("Frame", { Size = UDim2.new(0, 70, 0, 38), Position = UDim2.new(1, -80, 0.5, -19), BorderSizePixel = 0 }, head)
        ref(chip, "BackgroundColor3") addCorner(chip, 10)
        ui.count = new("TextLabel", { Size = UDim2.new(1, 0, 0, 22), Position = UDim2.new(0, 0, 0, 2), BackgroundTransparency = 1, Text = "0", TextColor3 = T.onAccent, TextSize = 16, Font = Enum.Font.GothamBold }, chip)
        new("TextLabel", { Size = UDim2.new(1, 0, 0, 12), Position = UDim2.new(0, 0, 0, 22), BackgroundTransparency = 1, Text = "найдено", TextColor3 = T.onAccent, TextTransparency = 0.2, TextSize = 9, Font = Enum.Font.Gotham }, chip)
    end

    -- ---------- UI: search ----------
    do
        local row = new("Frame", { Size = UDim2.new(1, 0, 0, 36), BackgroundTransparency = 1 }, page)
        local boxBg = new("Frame", { Size = UDim2.new(1, -78, 1, 0), BackgroundColor3 = T.row, BorderSizePixel = 0 }, row)
        addCorner(boxBg, 9) addStroke(boxBg, T.stroke, 1, 0.3)
        ui.search = new("TextBox", { Size = UDim2.new(1, -40, 1, 0), Position = UDim2.new(0, 12, 0, 0), BackgroundTransparency = 1, Text = "", PlaceholderText = "🔍  Название или ID…", PlaceholderColor3 = T.dim, TextColor3 = T.text, TextSize = 12, Font = Enum.Font.Gotham, ClearTextOnFocus = false, TextXAlignment = Enum.TextXAlignment.Left }, boxBg)
        local clear = new("TextButton", { Size = UDim2.new(0, 24, 0, 24), Position = UDim2.new(1, -30, 0.5, -12), Text = "✕", TextColor3 = T.dim, BackgroundColor3 = T.rowd, TextSize = 11, Font = Enum.Font.GothamBold, BorderSizePixel = 0 }, boxBg)
        addCorner(clear, 6)
        local go = new("TextButton", { Size = UDim2.new(0, 70, 1, 0), Position = UDim2.new(1, -70, 0, 0), Text = "Search", TextColor3 = T.onAccent, TextSize = 12, Font = Enum.Font.GothamBold, BorderSizePixel = 0 }, row)
        ref(go, "BackgroundColor3") addCorner(go, 9)
        go.MouseButton1Click:Connect(function() sfx("tap") runSearch(trim(ui.search.Text), SN.mode) end)
        ui.search.FocusLost:Connect(function(enter) if enter then runSearch(trim(ui.search.Text), SN.mode) end end)
        clear.MouseButton1Click:Connect(function() ui.search.Text = "" runSearch("", SN.mode) end)
    end

    -- ---------- UI: mode pills ----------
    do
        local scroller = new("ScrollingFrame", { Size = UDim2.new(1, 0, 0, 32), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 0, AutomaticCanvasSize = Enum.AutomaticSize.X, CanvasSize = UDim2.new(0, 0, 0, 0), ScrollingDirection = Enum.ScrollingDirection.X }, page)
        new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Center }, scroller)
        ui.modeBtns = {}
        local modes = {
            { "emotes", "😀 EMOTES" }, { "anims", "🏃 ANIMS" }, { "offsale", "🚫 OFFSALE" }, { "live", "🌐 LIVE" },
            { "afem", "💃 AFEM" }, { "fav", "♥ ИЗБРАННОЕ" }, { "hist", "🕘 ИСТОРИЯ" },
        }
        for i, m in ipairs(modes) do
            local b = new("TextButton", { Size = UDim2.new(0, (utf8.len(m[2]) or #m[2]) * 8 + 22, 0, 28), Text = m[2], TextColor3 = T.text, TextSize = 11, Font = Enum.Font.GothamBold, BackgroundColor3 = T.row, BorderSizePixel = 0, AutoButtonColor = false, LayoutOrder = i }, scroller)
            addCorner(b, 14, true) addStroke(b, T.stroke, 1, 0.5)
            b.MouseButton1Click:Connect(function() sfx("flip") setMode(m[1], true) end)
            ui.modeBtns[m[1]] = b
        end
    end

    -- ---------- UI: results ----------
    do
        ui.results = new("ScrollingFrame", { Size = UDim2.new(1, 0, 0, 300), BackgroundColor3 = T.panel, BackgroundTransparency = 0.1, BorderSizePixel = 0, ScrollBarThickness = 3, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(0, 0, 0, 0) }, page)
        ref(ui.results, "ScrollBarImageColor3") addCorner(ui.results, 10) addStroke(ui.results, T.stroke, 1, 0.3)
        new("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6), PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }, ui.results)
        new("UIListLayout", { Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder }, ui.results)
        ui.empty = new("TextLabel", { Size = UDim2.new(1, 0, 0, 60), BackgroundTransparency = 1, Text = "Пусто 🍃\nВыбери режим или нажми Search", TextColor3 = T.dim, TextSize = 12, Font = Enum.Font.Gotham, LayoutOrder = -1 }, ui.results)

        local pager = new("Frame", { Size = UDim2.new(1, 0, 0, 28), BackgroundTransparency = 1 }, page)
        local function nav(text, pos)
            local b = new("TextButton", { Size = UDim2.new(0, 90, 1, 0), Position = pos, Text = text, TextColor3 = T.text, TextSize = 11, Font = Enum.Font.GothamBold, BackgroundColor3 = T.row, BorderSizePixel = 0, Visible = false }, pager)
            addCorner(b, 8) addStroke(b, T.stroke, 1, 0.5)
            return b
        end
        ui.prev, ui.next = nav("‹  Назад", UDim2.new(0, 0, 0, 0)), nav("Далее  ›", UDim2.new(1, -90, 0, 0))
        ui.pageLbl = new("TextLabel", { Size = UDim2.new(1, -190, 1, 0), Position = UDim2.new(0, 95, 0, 0), BackgroundTransparency = 1, Text = "", TextColor3 = T.dim, TextSize = 11, Font = Enum.Font.GothamBold }, pager)
        ui.prev.MouseButton1Click:Connect(function()
            sfx("flip")
            if SN.remote then fetchLive(false, "prev") else SN.page -= 1 render() end
        end)
        ui.next.MouseButton1Click:Connect(function()
            sfx("flip")
            if SN.remote then fetchLive(false, "next") else SN.page += 1 render() end
        end)

        local st = new("Frame", { Size = UDim2.new(1, 0, 0, 20), BackgroundTransparency = 1 }, page)
        ui.dot = new("Frame", { Size = UDim2.new(0, 8, 0, 8), Position = UDim2.new(0, 4, 0.5, -4), BackgroundColor3 = T.dim, BorderSizePixel = 0 }, st)
        addCorner(ui.dot, 4, true)
        ui.status = new("TextLabel", { Size = UDim2.new(1, -20, 1, 0), Position = UDim2.new(0, 18, 0, 0), BackgroundTransparency = 1, Text = "Загрузка…", TextColor3 = T.dim, TextSize = 10, Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd }, st)
    end

    -- ---------- UI: now playing ----------
    do
        local np = new("Frame", { Size = UDim2.new(1, 0, 0, 78), BackgroundColor3 = T.row, BorderSizePixel = 0 }, page)
        addCorner(np, 10) addStroke(np, T.stroke, 1, 0.3)
        ui.npName = new("TextLabel", { Size = UDim2.new(1, -20, 0, 26), Position = UDim2.new(0, 12, 0, 6), BackgroundTransparency = 1, Text = "Ничего не играет", TextColor3 = T.dim, TextSize = 13, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd }, np)
        local function pill(text, x, w)
            local b = new("TextButton", { Size = UDim2.new(0, w, 0, 30), Position = UDim2.new(0, x, 0, 40), Text = text, TextColor3 = T.text, TextSize = 11, Font = Enum.Font.GothamBold, BackgroundColor3 = T.rowd, BorderSizePixel = 0 }, np)
            addCorner(b, 8)
            return b
        end
        local stopB = pill("⏹ Стоп", 10, 78)
        ui.loopBtn = pill("🔁 Loop", 94, 78)
        local minus = pill("−", 190, 30)
        ui.spdLbl = new("TextLabel", { Size = UDim2.new(0, 54, 0, 30), Position = UDim2.new(0, 222, 0, 40), BackgroundTransparency = 1, Text = "100%", TextColor3 = T.text, TextSize = 12, Font = Enum.Font.GothamBold }, np)
        local plus = pill("+", 278, 30)
        stopB.MouseButton1Click:Connect(function() sfx("tap") pcall(stopCurrentEmote) stopMine() setStatus("Остановлено", T.dim) end)
        ui.loopBtn.MouseButton1Click:Connect(function() sfx("tap") S.emoteLoop = not S.emoteLoop applyMine() end)
        minus.MouseButton1Click:Connect(function() sfx("tap") S.emoteSpeed = math.max(10, (S.emoteSpeed or 100) - 10) applyMine() end)
        plus.MouseButton1Click:Connect(function() sfx("tap") S.emoteSpeed = math.min(300, (S.emoteSpeed or 100) + 10) applyMine() end)
        npUpdate()
    end

    -- ---------- старые кнопки (сохранены) ----------
    createButton("Стоп эмоут", function() pcall(stopMine) if stopCurrentEmote() then notify("Эмоут остановлен") end end)
    createButton("Сбросить анимацию (респавн)", function()
        local _, _, hum = getChar()
        if hum then hum.Health = 0 end
    end)

    -- ---------- новые функции ----------
    createSection("Список и порядок")
    createSelector("Сортировка", { { "Как в файле", 1 }, { "A → Z", 2 }, { "Z → A", 3 }, { "Новые (ID ↓)", 4 } }, 1, function(v)
        SN.sort = v
        if not SN.remote then sortItems(SN.items) SN.page = 1 render() end
    end)
    createSelector("Источник для рандома", { { "Текущий список", 1 }, { "Избранное", 2 }, { "Все эмоуты", 3 } }, 1, function(v) SN.src = v end)

    local function pickRandom(sequential)
        local list
        if SN.src == 2 then list = SN.favs
        elseif SN.src == 3 then if ensureData("emotes") then list = sniperData.emotes end
        else list = SN.items end
        if (not list or #list == 0) and ensureData("emotes") then list = sniperData.emotes end
        if not list or #list == 0 then return nil end
        if sequential then
            SN.partyIdx = (SN.partyIdx % #list) + 1
            return list[SN.partyIdx]
        end
        return list[math.random(#list)]
    end

    createSection("Фан")
    createButton("🎲 Случайный эмоут", function()
        task.spawn(function()
            local e = pickRandom(false)
            if e then activate(e) else notify("Нет данных — открой LIVE или положи файлы", "error") end
        end)
    end)
    createButton("🧊 Заморозить позу (вкл/выкл)", function()
        if not cur.track then notify("Сначала включи эмоут", "error") return end
        cur.frozen = not cur.frozen
        applyMine()
        notify(cur.frozen and "Поза заморожена" or "Поза разморожена")
    end)
    createSlider("Интервал авто-смены, сек", 3, 30, 8, function(v) S.snpInterval = v end)
    createTumbler("🔀 Авто-смена эмоутов", false).onToggle(function(st)
        S.snpAuto = st
        SN.token += 1
        local my = SN.token
        if not st then return end
        task.spawn(function()
            while S.snpAuto and SN.token == my and not S.unloaded do
                local e = pickRandom(false)
                if e then
                    while sniperBusy and S.snpAuto and SN.token == my do task.wait(0.1) end
                    activate(e)
                end
                local t0 = os.clock()
                while os.clock() - t0 < (S.snpInterval or 8) and S.snpAuto and SN.token == my and not S.unloaded do task.wait(0.2) end
            end
        end)
    end)
    createTumbler("💃 Танцевальная вечеринка (по очереди)", false).onToggle(function(st)
        S.snpParty = st
        SN.token += 1
        local my = SN.token
        if not st then return end
        task.spawn(function()
            while S.snpParty and SN.token == my and not S.unloaded do
                local e = pickRandom(true)
                if e then
                    while sniperBusy and S.snpParty and SN.token == my do task.wait(0.1) end
                    activate(e)
                end
                local t0 = os.clock()
                while os.clock() - t0 < (S.snpInterval or 8) and S.snpParty and SN.token == my and not S.unloaded do task.wait(0.2) end
            end
        end)
    end)

    createSection("Избранное и история")
    createButton("📋 Копировать ID текущего эмоута", function()
        local id
        if cur.track and cur.track.Animation then id = digitsOf(cur.track.Animation.AnimationId) end
        if id and setclipboard then setclipboard(id) notify("ID скопирован: " .. id, "success") else notify("Нет активного эмоута", "error") end
    end)
    createButton("📤 Экспорт избранного в буфер", function()
        if not setclipboard then notify("setclipboard недоступен", "error") return end
        local lines = {}
        for _, e in ipairs(SN.favs) do lines[#lines + 1] = e.id .. "\t" .. e.name end
        setclipboard(table.concat(lines, "\n"))
        notify("Скопировано: " .. #lines .. " шт.", "success")
    end)
    createButton("🧹 Очистить историю", function() SN.hist = {} if SN.mode == "hist" then SN.items = {} render() end notify("История очищена") end)
    createButton("💔 Очистить избранное", function()
        SN.favs, SN.favSet = {}, {}
        saveFavs()
        if SN.mode == "fav" then SN.items = {} end
        render()
        notify("Избранное очищено")
    end)

    -- ---------- эффекты (локальные: видны только тебе) ----------
    createSection("Эффекты (виден только тебе)")
    local ghostOrig = setmetatable({}, { __mode = "k" })
    local colorOrig = setmetatable({}, { __mode = "k" })
    local function applyGhost()
        local char = LocalPlayer.Character
        if not char then return end
        local a = (S.snpGhost or 0) / 100
        for _, d in ipairs(char:GetDescendants()) do
            if (d:IsA("BasePart") and d.Name ~= "HumanoidRootPart") or d:IsA("Decal") then
                if ghostOrig[d] == nil then ghostOrig[d] = d.Transparency end
                d.Transparency = a > 0 and math.max(ghostOrig[d], a) or ghostOrig[d]
            end
        end
    end
    local function setAura(on)
        local _, root = getChar()
        if not root then return end
        local old = root:FindFirstChild("WIAAura")
        if old then old:Destroy() end
        if not on then return end
        new("ParticleEmitter", {
            Name = "WIAAura", Rate = 35, Lifetime = NumberRange.new(0.8, 1.6), Speed = NumberRange.new(1, 4),
            SpreadAngle = Vector2.new(180, 180), LightEmission = 0.7,
            Color = ColorSequence.new(T.accent, Color3.fromRGB(255, 255, 255)),
            Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) }),
            Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) }),
            Texture = "rbxasset://textures/particles/sparkles_main.dds",
        }, root)
    end
    local function setTrail(on)
        local _, root = getChar()
        if not root then return end
        for _, n in ipairs({ "WIATrail", "WIATrailA0", "WIATrailA1" }) do
            local o = root:FindFirstChild(n)
            if o then o:Destroy() end
        end
        if not on then return end
        local a0 = new("Attachment", { Name = "WIATrailA0", Position = Vector3.new(0, 1, 0) }, root)
        local a1 = new("Attachment", { Name = "WIATrailA1", Position = Vector3.new(0, -1, 0) }, root)
        new("Trail", {
            Name = "WIATrail", Attachment0 = a0, Attachment1 = a1, Lifetime = 0.7, LightEmission = 0.8,
            Color = ColorSequence.new(T.accent, Color3.fromRGB(255, 255, 255)), Transparency = NumberSequence.new(0.1, 1),
        }, root)
    end
    local function restoreColors()
        for k, v in pairs(colorOrig) do if k.Parent then k.Color = v end end
        table.clear(colorOrig)
    end

    createSlider("👻 Призрак (прозрачность тела), %", 0, 90, 0, function(v) S.snpGhost = v applyGhost() end)
    createTumbler("🌈 Радужное тело", false).onToggle(function(st)
        S.snpRB = st
        if not st then restoreColors() end
    end)
    createTumbler("✨ Аура частиц", false).onToggle(function(st) S.snpAura = st setAura(st) end)
    createTumbler("☄️ Светящийся след", false).onToggle(function(st) S.snpTrail = st setTrail(st) end)
    createSlider("Дистанция кино-камеры", 4, 25, 9, function(v) S.snpOrbitDist = v end)
    createTumbler("🎥 Кино-камера (облёт вокруг тебя)", false).onToggle(function(st)
        S.snpOrbit = st
        if not st then
            pcall(function()
                Camera.CameraType = Enum.CameraType.Custom
                local _, _, hum = getChar()
                if hum then Camera.CameraSubject = hum end
            end)
        else
            pcall(function() Camera.CameraType = Enum.CameraType.Scriptable end)
        end
    end)

    local tick = 0
    bind(RunService.RenderStepped, function()
        if S.unloaded then return end
        tick += 1
        if S.snpRB and tick % 3 == 0 then
            local char = LocalPlayer.Character
            if char then
                local c = Color3.fromHSV((os.clock() * 0.25) % 1, 0.8, 1)
                for _, d in ipairs(char:GetDescendants()) do
                    if d:IsA("BasePart") then
                        if colorOrig[d] == nil then colorOrig[d] = d.Color end
                        d.Color = c
                    end
                end
            end
        end
        if S.snpOrbit then
            local _, root = getChar()
            if root then
                local ang = os.clock() * 0.6
                local dist = S.snpOrbitDist or 9
                local pos = root.Position + Vector3.new(math.cos(ang) * dist, 3, math.sin(ang) * dist)
                Camera.CFrame = CFrame.new(pos, root.Position + Vector3.new(0, 1.5, 0))
            end
        end
    end)
    bind(LocalPlayer.CharacterAdded, function()
        task.wait(1)
        if S.unloaded then return end
        cur.track, cur.name, cur.frozen = nil, nil, false
        npUpdate()
        applyGhost()
        if S.snpAura then setAura(true) end
        if S.snpTrail then setTrail(true) end
    end)

    S.sniperCleanup = function()
        S.snpAuto, S.snpParty, S.snpRB, S.snpGhost = false, false, false, 0
        if S.snpOrbit then
            S.snpOrbit = false
            pcall(function() Camera.CameraType = Enum.CameraType.Custom end)
        end
        pcall(applyGhost)
        pcall(setAura, false)
        pcall(setTrail, false)
        pcall(restoreColors)
        pcall(stopMine)
    end

    -- ---------- старт: сразу показываем список ----------
    setMode("emotes", false)
    setStatus("Загрузка списка эмоций…", T.dim)
    render()
    task.spawn(function() runSearch("", "emotes") end)
end

-- ========== UNLOAD ==========
local function unload()
    S.unloaded = true
    S.fly, S.freecam, S.spectate, S.silent = false, false, nil, false
    pcall(function() RunService:UnbindFromRenderStep("WiaAim") end)
    if S.airPart then pcall(function() S.airPart:Destroy() end) end
    pcall(function() if SND.folder then SND.folder:Destroy() end end)
    pcall(function() LocalPlayer.CameraMaxZoomDistance = 128 LocalPlayer.CameraMinZoomDistance = 0.5 end)
    pcall(stopFlight)
    if S.sniperCleanup then pcall(S.sniperCleanup) end
    pcall(restoreHitboxes)
    pcall(removeChams)
    pcall(removeTPTool)
    pcall(applyRagdoll, false)
    pcall(restoreLighting, "fb")
    pcall(restoreLighting, "fog")
    workspace.Gravity = origGravity
    pcall(function()
        Camera.FieldOfView = S.fovDefault
        Camera.CameraType = Enum.CameraType.Custom
        local _, _, hum = getChar()
        if hum then Camera.CameraSubject = hum end
    end)
    for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
    if hasDrawing then
        pcall(function() poolL.destroy() poolS.destroy() poolT.destroy() fovCircle:Remove() end)
        if crossLines then for _, l in ipairs(crossLines) do pcall(function() l:Remove() end) end end
    end
    for _, g in ipairs(guis) do pcall(function() g:Destroy() end) end
end

-- ========== TAB: SETTINGS ==========
createTab("Settings")
createSection("Интерфейс")
createTumbler("Watermark", true, { bindable = true }).onToggle(function(st) WmGui.Enabled = st end)
createButton("Клавиша меню: " .. S.menuKey.Name, function(b)
    b.Text = "Нажми клавишу..."
    waitKey(function(kc)
        if kc ~= Enum.KeyCode.Escape then S.menuKey = kc notify("Меню = " .. kc.Name, "success") end
        b.Text = "Клавиша меню: " .. S.menuKey.Name
        StatusBar.Text = "Ready · " .. S.menuKey.Name .. " — скрыть меню"
    end)
end)
createSlider("Размер меню %", 60, 140, 100, function(v) MainScale.Scale = v / 100 end)
do
    local accents = {
        { "Синие чернила", Color3.fromRGB(52, 98, 190) }, { "Красная ручка", Color3.fromRGB(200, 60, 60) }, { "Зелёный маркер", Color3.fromRGB(60, 150, 90) },
        { "Фиолетовый", Color3.fromRGB(124, 92, 255) }, { "Оранжевый", Color3.fromRGB(225, 130, 40) }, { "Розовый", Color3.fromRGB(220, 90, 160) },
        { "Графит", Color3.fromRGB(70, 66, 62) }, { "Бирюза", Color3.fromRGB(40, 160, 175) },
    }
    createSelector("Цвет акцента", accents, 1, function(c) if not S.rainbow then setAccent(c) end end)
end
createTumbler("Rainbow акцент", false, { bindable = false }).onToggle(function(st) S.rainbow = st end)
createSection("Бумага и звук")
createTumbler("Звуки бумаги", true, { bindable = false }).onToggle(function(st) SND.enabled = st if st then sfx("flip") end end)
createSlider("Громкость звуков %", 0, 100, 60, function(v) SND.vol = v / 100 sfx("tap") end)
createSelector("Шрифт", { { "Рукописный", "hand" }, { "Печатная машинка", "type" }, { "Антиква", "serif" }, { "Чистый", "clean" } }, 1, function(k) applyFont(k) end)
createTumbler("Тень, поля и скотч", true, { bindable = false }).onToggle(function(st)
    for _, d in ipairs(S.decor) do d.Visible = st end
end)
createButton("Скрыть меню", function()
    S.guiVisible = false
    ScreenGui.Enabled = false
    PlayerListGui.Enabled = false
    notify("Меню скрыто (кнопка W или " .. S.menuKey.Name .. ")")
end)
createSection("Конфиг")
do
    local FILE = "wia_hub_config.json"
    createButton("Сохранить конфиг", function()
        if not writefile then notify("writefile недоступен", "error") return end
        local out = {}
        for k, e in pairs(cfgReg) do out[k] = e.get() end
        local ok = pcall(function() writefile(FILE, HttpService:JSONEncode(out)) end)
        notify(ok and "Конфиг сохранён" or "Ошибка сохранения", ok and "success" or "error")
    end)
    createButton("Загрузить конфиг", function()
        if not (isfile and readfile and isfile(FILE)) then notify("Конфиг не найден", "error") return end
        local ok, data = pcall(function() return HttpService:JSONDecode(readfile(FILE)) end)
        if not ok or type(data) ~= "table" then notify("Конфиг повреждён", "error") return end
        for k, v in pairs(data) do
            local e = cfgReg[k]
            if e then pcall(e.set, v) end
        end
        notify("Конфиг загружен", "success")
    end)
end
createSection("Опасная зона")
createButton("Выгрузить хаб (Unload)", function()
    notify("Выгрузка...")
    task.delay(0.4, unload)
end)

notify("WIA HUB v15 PAPER загружен · звуки: " .. (SND.custom and "бумага" or "загрузка…"), "success")
sfx("flip")

end

local ok, err = pcall(main)
if not ok then
    warn("[WIA HUB] " .. tostring(err))
end