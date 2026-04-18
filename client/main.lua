---@diagnostic disable: undefined-global
-- cam keyframer, i lowkey just wanted to make cinematics. but got carried away so here you go lol

local math = lib.math

local active      = false
local cam         = nil
local camPos      = vector3(0.0, 0.0, 0.0)
local camRot      = vector3(0.0, 0.0, 0.0)
local camFov      = 50.0

local keyframes   = {}
local nextId      = 1

local isPlaying   = false
local playCam     = nil

local MOVE_SPEED  = 0.22
local TURN_SPEED  = 1.6
local ROLL_SPEED  = 1.4
local FOV_SPEED   = 0.6
local BOOST_MULT  = 4.0
local SLOW_MULT   = 0.15

---------------------------------------------------------------- helpers

local function dirFromRot(rot)
    local rz = math.rad(rot.z)
    local rx = math.rad(rot.x)
    local cx = math.abs(math.cos(rx))
    return vector3(-math.sin(rz) * cx, math.cos(rz) * cx, math.sin(rx))
end

local function rightFromRot(rot)
    local rz = math.rad(rot.z)
    return vector3(math.cos(rz), math.sin(rz), 0.0)
end

local function vlen(v) return math.sqrt(v.x*v.x + v.y*v.y + v.z*v.z) end

local function normalize(v)
    local l = vlen(v)
    if l < 1e-4 then return vector3(0.0, 0.0, 0.0) end
    return vector3(v.x/l, v.y/l, v.z/l)
end

local function sendUI(data) SendNUIMessage(data) end

local function serialize() return lib.table.deepclone(keyframes) end

local function refreshList()
    sendUI({ action = 'keyframes', keyframes = serialize() })
end

---------------------------------------------------------------- keyframe ops

local function addKeyframe()
    keyframes[#keyframes + 1] = {
        id       = nextId,
        pos      = { x = math.round(camPos.x, 3), y = math.round(camPos.y, 3), z = math.round(camPos.z, 3) },
        rot      = { x = math.round(camRot.x, 2), y = math.round(camRot.y, 2), z = math.round(camRot.z, 2) },
        fov      = math.round(camFov, 1),
        duration = 2000,
    }
    nextId = nextId + 1
    refreshList()
end

local function deleteKeyframe(id)
    for i, k in ipairs(keyframes) do
        if k.id == id then table.remove(keyframes, i); break end
    end
    refreshList()
end

local function setDuration(id, ms)
    for _, k in ipairs(keyframes) do
        if k.id == id then
            k.duration = math.clamp(math.floor(ms), 100, 60000)
            break
        end
    end
    refreshList()
end

local function gotoKeyframe(id)
    for _, k in ipairs(keyframes) do
        if k.id == id then
            camPos = vector3(k.pos.x, k.pos.y, k.pos.z)
            camRot = vector3(k.rot.x, k.rot.y, k.rot.z)
            camFov = k.fov
            if cam then
                SetCamCoord(cam, camPos.x, camPos.y, camPos.z)
                SetCamRot(cam, camRot.x, camRot.y, camRot.z, 2)
                SetCamFov(cam, camFov)
            end
            break
        end
    end
end

local function moveKeyframe(id, dir)
    for i, k in ipairs(keyframes) do
        if k.id == id then
            local j = i + dir
            if j >= 1 and j <= #keyframes then
                keyframes[i], keyframes[j] = keyframes[j], keyframes[i]
            end
            break
        end
    end
    refreshList()
end

local function clearKeyframes()
    keyframes = {}
    refreshList()
end

---------------------------------------------------------------- playback

local function stopPlayback()
    if playCam then DestroyCam(playCam, false); playCam = nil end
    isPlaying = false
    if active and cam then
        SetCamActive(cam, true)
        RenderScriptCams(true, false, 0, true, false)
    end
    sendUI({ action = 'playing', state = false })
end

local function playKeyframes()
    if isPlaying then return end
    if #keyframes < 2 then
        sendUI({ action = 'toast', text = 'Need at least 2 keyframes to play.' })
        return
    end
    isPlaying = true
    playCam = CreateCam('DEFAULT_SPLINE_CAMERA', false)
    for _, k in ipairs(keyframes) do
        AddCamSplineNode(playCam,
            k.pos.x, k.pos.y, k.pos.z,
            k.rot.x, k.rot.y, k.rot.z,
            k.duration, 0, 2)
    end
    SetCamActive(playCam, true)
    RenderScriptCams(true, false, 0, true, false)
    sendUI({ action = 'playing', state = true })

    CreateThread(function()
        Wait(50)
        while isPlaying and playCam do
            local phase = GetCamSplinePhase(playCam)
            sendUI({ action = 'phase', phase = phase })
            if phase >= 0.999 then break end
            Wait(50)
        end
        if isPlaying then stopPlayback() end
    end)
end

---------------------------------------------------------------- open / close

local CONTROLS = {
    1, 2, 24, 25, 257, 140, 141, 142, 143,
    16, 17, 32, 33, 34, 35, 22, 36, 44, 38,
    21, 19, 172, 173, 174, 175, 241, 242,
    15, 14, 20, 26,
}

local function openKeyframer()
    if active then return end
    active = true

    local ped     = PlayerPedId()
    local pos     = GetEntityCoords(ped) + vector3(0.0, 0.0, 0.8)
    local heading = GetEntityHeading(ped)

    camPos = pos
    camRot = vector3(0.0, 0.0, heading)
    camFov = 50.0

    cam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA',
        camPos.x, camPos.y, camPos.z,
        camRot.x, camRot.y, camRot.z,
        camFov, false, 2)
    SetCamActive(cam, true)
    RenderScriptCams(true, false, 0, true, false)

    lib.disableControls:Add(CONTROLS)

    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(true)
    sendUI({ action = 'setVisible', visible = true })
    refreshList()
end

local function closeKeyframer()
    if not active then return end
    if isPlaying then stopPlayback() end
    active = false

    RenderScriptCams(false, false, 0, true, false)
    if cam then DestroyCam(cam, false); cam = nil end

    lib.disableControls:Remove(CONTROLS)

    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    sendUI({ action = 'setVisible', visible = false })
end

---------------------------------------------------------------- input loop

CreateThread(function()
    while true do
        if active then
            lib.disableControls()

            if not isPlaying and cam then
                local dt    = GetFrameTime() * 60.0
                local speed = MOVE_SPEED * dt
                if IsDisabledControlPressed(0, 21) then speed = speed * BOOST_MULT end
                if IsDisabledControlPressed(0, 19) then speed = speed * SLOW_MULT  end

                local fwd   = dirFromRot(camRot)
                local right = rightFromRot(camRot)
                local move  = vector3(0.0, 0.0, 0.0)

                if IsDisabledControlPressed(0, 32) then move = move + fwd   end  -- W
                if IsDisabledControlPressed(0, 33) then move = move - fwd   end  -- S
                if IsDisabledControlPressed(0, 34) then move = move - right end  -- A
                if IsDisabledControlPressed(0, 35) then move = move + right end  -- D
                if IsDisabledControlPressed(0, 22) then move = move + vector3(0, 0, 1) end -- Space
                if IsDisabledControlPressed(0, 36) then move = move - vector3(0, 0, 1) end -- Ctrl

                if vlen(move) > 0.0 then
                    local n = normalize(move)
                    camPos = vector3(camPos.x + n.x * speed, camPos.y + n.y * speed, camPos.z + n.z * speed)
                end

                local turn = TURN_SPEED * dt
                if IsDisabledControlPressed(0, 44) then camRot = vector3(camRot.x, camRot.y, camRot.z + turn) end -- Q
                if IsDisabledControlPressed(0, 38) then camRot = vector3(camRot.x, camRot.y, camRot.z - turn) end -- E

                if IsDisabledControlPressed(0, 172) then camRot = vector3(math.clamp(camRot.x + turn, -89.0, 89.0), camRot.y, camRot.z) end -- up
                if IsDisabledControlPressed(0, 173) then camRot = vector3(math.clamp(camRot.x - turn, -89.0, 89.0), camRot.y, camRot.z) end -- down
                if IsDisabledControlPressed(0, 174) then camRot = vector3(camRot.x, camRot.y, camRot.z + turn) end -- left
                if IsDisabledControlPressed(0, 175) then camRot = vector3(camRot.x, camRot.y, camRot.z - turn) end -- right

                -- Roll: Z (ctrl 20 = MULTIPLAYER_INFO) / C (ctrl 26 = LOOK_BEHIND) -- fuck me in the ass 
                if IsDisabledControlPressed(0, 20) then camRot = vector3(camRot.x, camRot.y - ROLL_SPEED * dt, camRot.z) end
                if IsDisabledControlPressed(0, 26) then camRot = vector3(camRot.x, camRot.y + ROLL_SPEED * dt, camRot.z) end

                -- Mouse wheel: FOV
                if IsDisabledControlJustPressed(0, 241) then camFov = math.clamp(camFov - FOV_SPEED * 5.0, 5.0, 120.0) end
                if IsDisabledControlJustPressed(0, 242) then camFov = math.clamp(camFov + FOV_SPEED * 5.0, 5.0, 120.0) end

                SetCamCoord(cam, camPos.x, camPos.y, camPos.z)
                SetCamRot(cam, camRot.x, camRot.y, camRot.z, 2)
                SetCamFov(cam, camFov)

                sendUI({
                    action = 'cam',
                    pos = { x = math.round(camPos.x, 2), y = math.round(camPos.y, 2), z = math.round(camPos.z, 2) },
                    rot = { x = math.round(camRot.x, 1), y = math.round(camRot.y, 1), z = math.round(camRot.z, 1) },
                    fov = math.round(camFov, 1),
                })
            end
        end
        Wait(0)
    end
end)

---------------------------------------------------------------- commands & keymaps

RegisterCommand('camkf', function()
    if active then closeKeyframer() else openKeyframer() end
end, false)

lib.addKeybind({
    name        = 'camkf_add',
    description = 'Camera KF: Add keyframe',
    defaultKey  = 'RETURN',
    onPressed   = function()
        if active and not isPlaying then addKeyframe() end
    end,
})

lib.addKeybind({
    name        = 'camkf_play',
    description = 'Camera KF: Play',
    defaultKey  = 'P',
    onPressed   = function()
        if active and not isPlaying then playKeyframes() end
    end,
})

lib.addKeybind({
    name        = 'camkf_stop',
    description = 'Camera KF: Stop',
    defaultKey  = 'O',
    onPressed   = function()
        if active and isPlaying then stopPlayback() end
    end,
})

lib.addKeybind({
    name        = 'camkf_close',
    description = 'Camera KF: Close',
    defaultKey  = 'BACK',
    onPressed   = function()
        if active then closeKeyframer() end
    end,
})

---------------------------------------------------------------- nui callbacks

RegisterNUICallback('addKeyframe',   function(_, cb) if active then addKeyframe() end; cb({}) end)
RegisterNUICallback('deleteKeyframe',function(d, cb) deleteKeyframe(d.id); cb({}) end)
RegisterNUICallback('setDuration',   function(d, cb) setDuration(d.id, d.duration); cb({}) end)
RegisterNUICallback('gotoKeyframe',  function(d, cb) gotoKeyframe(d.id); cb({}) end)
RegisterNUICallback('moveKeyframe',  function(d, cb) moveKeyframe(d.id, d.dir); cb({}) end)
RegisterNUICallback('clearKeyframes',function(_, cb) clearKeyframes(); cb({}) end)
RegisterNUICallback('play',          function(_, cb) playKeyframes(); cb({}) end)
RegisterNUICallback('stop',          function(_, cb) stopPlayback(); cb({}) end)
RegisterNUICallback('close',         function(_, cb) closeKeyframer(); cb({}) end)

RegisterNUICallback('export', function(_, cb)
    local data = {}
    for i, k in ipairs(keyframes) do
        data[i] = { pos = k.pos, rot = k.rot, fov = k.fov, duration = k.duration }
    end
    cb({ json = json.encode(data) })
end)

---------------------------------------------------------------- cleanup

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if playCam then DestroyCam(playCam, false) end
    if cam     then DestroyCam(cam, false)     end
    RenderScriptCams(false, false, 0, true, false)
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
end)
