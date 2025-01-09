local locations = {}
local ownedLocations = {}
local currentLocation = nil  -- Add this line
local QBCore = exports['qb-core']:GetCoreObject()
local creationLaser = false
local debugEnabled = false -- Set to true to enable debug messages, false to disable

-- Debug function
local function Debug(message)
    if debugEnabled then
        print('^3[ud-keypad:client]^0: ' .. message)
    end
end

local function buyLocation(locationData)
    TriggerServerEvent('ud-keypad:buyLocation', locationData)
end

-- Add this function to handle the breaching process
local function BreachStash(stashId)
    if not stashId then return end

    local hasItem = exports.ox_inventory:Search('count', {'police_stormram'})
    if hasItem > 0 then
        lib.progressBar({
            duration = 60000,
            label = 'Breaching Stash...',
            useWhileDead = false,
            canCancel = false,
            disable = {
                move = true,
                car = true,
                combat = true,
            },
            anim = {
                dict = 'missheistfbi3b_ig7',
                clip = 'lift_fibagent_loop'
            },
        })

        local success = exports.ox_inventory:openInventory('stash', stashId)
        if success then
            print('^2[SUCCESS]^7 Stash breached successfully:', stashId)
        else
            print('^1[ERROR]^7 Failed to breach stash:', stashId)
        end
    else
        lib.notify({
            title = 'Missing Item',
            description = 'You need a police stormram to breach this stash',
            type = 'error'
        })
    end
end

-- Modify the `openManagementMenu` function to include the breach option for cops
local function openManagementMenu(locationData)
    Debug('Location Owner Info: ' .. json.encode(ownedLocations[locationData.name]))
    local owner = ownedLocations[locationData.name].owner
    if not ownedLocations[locationData.name] then
        lib.notify({
            title = 'Access Denied',
            description = 'You do not own this location',
            type = 'error'
        })
        return
    end
    if owner == QBCore.Functions.GetPlayerData().citizenid then
        lib.registerContext({
            id = 'location_management',
            title = locationData.name .. ' Management',
            options = {
                {
                    title = 'Open Keypad',
                    description = 'Access the keypad for this location',
                    icon = 'fa-solid fa-keyboard',
                    onSelect = function()
                        TriggerEvent('ud-keypad:openKeypad', locationData)
                    end
                },
                {
                    title = 'Change Password',
                    description = 'Set a new password for this location',
                    icon = 'fa-solid fa-key',
                    onSelect = function()
                        TriggerEvent('ud-keypad:changePassword', locationData)
                    end
                },
                {
                    title = 'Sell Location',
                    description = ('Sell for $%s'):format(math.floor(locationData.price * 0.8 + 0.5)),
                    icon = 'fa-solid fa-dollar-sign',
                    serverEvent = 'ud-keypad:sellLocation',
                    args = { locationData = locationData }
                }
            }
        })
    else
        local options = {
            {
                title = 'Open Keypad',
                description = 'Access the keypad for this location',
                icon = 'fa-solid fa-keyboard',
                onSelect = function()
                    TriggerEvent('ud-keypad:openKeypad', locationData)
                end
            },
            {
                title = 'Change Password',
                description = 'Set a new password for this location',
                icon = 'fa-solid fa-key',
                onSelect = function()
                    TriggerEvent('ud-keypad:changePassword', locationData)
                end,
                disabled = true
            },
            {
                title = 'Sell Location',
                description = ('Sell for $%s'):format(math.floor(locationData.price * 0.8 + 0.5)),
                icon = 'fa-solid fa-dollar-sign',
                serverEvent = 'ud-keypad:sellLocation',
                args = { locationData = locationData },
                disabled = true
            }
        }

        -- Add the breach option for cops
        if QBCore.Functions.GetPlayerData().job.name == 'police' then
            table.insert(options, {
                title = 'Breach Stash',
                description = 'Use a police stormram to breach the stash',
                icon = 'fa-solid fa-door-open',
                onSelect = function()
                    BreachStash(locationData.name)
                end
            })
        end

        lib.registerContext({
            id = 'location_management',
            title = locationData.name .. ' Management',
            options = options
        })
    end
    lib.showContext('location_management')
end

local function RefreshTargetZones()
    Debug('Starting RefreshTargetZones')
    
    if not locations or #locations == 0 then 
        Debug('No locations available')
        return
    end
    
    Debug('Refreshing target zones for ' .. #locations .. ' locations')

    -- Remove all existing zones first
    for _, location in ipairs(locations) do
        Debug('Removing existing zones for: ' .. location.name)
        exports.ox_target:removeZone('location_' .. location.name)
        exports.ox_target:removeZone('owned_' .. location.name)
    end

    -- Create new zones
    for _, location in ipairs(locations) do
        if not location.coords then
            Debug('Missing coords for location: ' .. location.name)
            goto continue
        end

        local isOwned = ownedLocations[location.name] ~= nil
        Debug('Processing location: ' .. location.name .. ' (Owned: ' .. tostring(isOwned) .. ')')
        
        local coords = vector3(location.coords.x, location.coords.y, location.coords.z)
        Debug('Creating zone at coords: ' .. json.encode(coords))
        
        if isOwned then
            exports.ox_target:addSphereZone({
                coords = coords,
                name = 'owned_' .. location.name,
                radius = 0.5,
                debug = false,
                options = {
                    {
                        name = 'openLocation_' .. location.name,
                        onSelect = function()
                            openManagementMenu(location)
                        end,
                        icon = 'fa-solid fa-door-open',
                        label = 'Manage ' .. location.name
                    }
                }
            })
            Debug('Created owned zone for: ' .. location.name)
        else
            exports.ox_target:addSphereZone({
                coords = coords,
                name = 'location_' .. location.name,
                radius = 0.5,
                debug = false,
                options = {
                    {
                        name = 'buyLocation_' .. location.name,
                        onSelect = function()
                            buyLocation(location)
                        end,
                        icon = 'fa-solid fa-hand-holding-dollar',
                        label = ('Buy %s for $%s'):format(location.name, location.price)
                    }
                }
            })
            Debug('Created buy zone for: ' .. location.name)
        end
        
        ::continue::
    end
    Debug('Finished refreshing target zones')
end

-- Sync events
RegisterNetEvent('ud-keypad:syncLocations', function(serverLocations)
    Debug('Received locations from server: ' .. json.encode(serverLocations))
    locations = serverLocations
    RefreshTargetZones()
end)

RegisterNetEvent('ud-keypad:syncOwnedLocations', function(serverOwnedLocations)
    Debug('Received owned locations from server: ' .. json.encode(serverOwnedLocations))
    ownedLocations = serverOwnedLocations
    RefreshTargetZones()
end)

-- Request initial sync
CreateThread(function()
    Wait(2000) -- Increased wait time to ensure everything is loaded
    Debug('Requesting initial sync from server')
    TriggerServerEvent('ud-keypad:requestSync')
end)

RegisterNetEvent('ud-keypad:openKeypad', function(locationData)
    currentLocation = locationData  -- Store in the top-level variable
    
    SetNuiFocus(true, true)
    SendReactMessage('setVisible', { visible = true, isChangingPassword = false })
    
    if locationData and locationData.password then
        SendReactMessage('setPassword', { password = locationData.password })
    else
        print("^1[ERROR]^7 No password provided for location")
    end
end)

RegisterNetEvent('ud-keypad:changePassword', function(locationData)
    -- Check if player owns this location
    if not ownedLocations[locationData.name] then
        lib.notify({
            title = 'Access Denied',
            description = 'You do not own this location',
            type = 'error'
        })
        return
    end
    
    currentLocation = locationData
    SetNuiFocus(true, true)
    SendReactMessage('setVisible', { visible = true, isChangingPassword = true })
end)

-- Register NUI callbacks
RegisterNUICallback('passwordSuccessful', function(data, cb)
    SetNuiFocus(false, false)
    SendReactMessage('setVisible', { visible = false, isChangingPassword = false })
    
    if currentLocation then
        local stashId = currentLocation.name
        print('^2[DEBUG]^7 Current Location:', json.encode(currentLocation))
        print('^2[DEBUG]^7 Attempting to open stash:', stashId)
        
        Wait(100)
        
        local success = exports.ox_inventory:openInventory('stash', stashId)
        
        if success then
            print('^2[SUCCESS]^7 Stash opened successfully:', stashId)
        else
            print('^1[ERROR]^7 Failed to open stash:', stashId)
        end
    else
        print('^1[ERROR]^7 No current location found')
    end
    
    cb({})
end)

RegisterNUICallback('passwordIncorrect', function(data, cb)
    SetNuiFocus(false, false)
    SendReactMessage('setVisible', { visible = false, isChangingPassword = false })
    -- Add your failure logic here
    cb({})
end)

RegisterNUICallback('passwordChanged', function(data, cb)
    SetNuiFocus(false, false)
    SendReactMessage('setVisible', { visible = false, isChangingPassword = false })
    
    -- Send new password to server
    TriggerServerEvent('ud-keypad:updatePassword', {
        name = currentLocation.name,
        password = data.password
    })
    
    cb({})
end)

RegisterNUICallback('hideFrame', function(_, cb)
    SetNuiFocus(false, false)
    SendReactMessage('setVisible', { visible = false, isChangingPassword = false })
    currentLocation = nil  -- Clear the current location
    cb({})
end)

RegisterNetEvent('ud-keypad:removeVaultTarget', function(name)
    -- Remove both possible target zones for this vault
    exports.ox_target:removeZone('location_' .. name)
    exports.ox_target:removeZone('owned_' .. name)
end)

-- Command to start vault creation mode
RegisterCommand('createvault', function()
    -- Check job server-side instead
    TriggerServerEvent('ud-keypad:checkRealtorJob')
end)

RegisterNetEvent('ud-keypad:startVaultCreation', function()
    ToggleCreationLaser()
end)

function ToggleCreationLaser()
    creationLaser = not creationLaser

    if creationLaser then
        CreateThread(function()
            while creationLaser do
                local hit, coords = DrawLaser('PRESS ~g~E~w~ TO CREATE VAULT', {r = 2, g = 241, b = 181, a = 200})

                if IsControlJustReleased(0, 38) then -- E key
                    creationLaser = false
                    if hit then
                        OpenVaultCreationDialog(coords)
                    else
                        lib.notify({
                            title = 'Error',
                            description = 'Invalid location',
                            type = 'error'
                        })
                    end
                end
                Wait(0)
            end
        end)
    end
end

function OpenVaultCreationDialog(coords)
    local input = lib.inputDialog('Create Vault', {
        {
            type = 'input',
            label = 'Vault Name',
            placeholder = 'Enter vault name',
            required = true
        },
        {
            type = 'number',
            label = 'Price',
            placeholder = 'Enter price',
            required = true,
            min = 1
        }
    })

    if not input then return end -- Dialog was cancelled

    local name = input[1]
    local price = input[2]

    if name and price then
        TriggerServerEvent('ud-keypad:createVault', {
            name = name,
            price = price,
            coords = coords
        })
    end
end

function DrawLaser(message, color)
    local hit, coords = RayCastGamePlayCamera(100)
    local position = GetEntityCoords(PlayerPedId())

    if hit then
        DrawLine(position.x, position.y, position.z, coords.x, coords.y, coords.z, color.r, color.g, color.b, color.a)
        DrawMarker(28, coords.x, coords.y, coords.z, 0.0, 0.0, 0.0, 0.0, 180.0, 0.0, 0.1, 0.1, 0.1, color.r, color.g, color.b, color.a, false, true, 2, nil, nil, false)
        Draw3DText(coords.x, coords.y, coords.z, message)
    end

    return hit, coords
end

function RayCastGamePlayCamera(distance)
    local cameraRotation = GetGameplayCamRot()
    local cameraCoord = GetGameplayCamCoord()
    local direction = RotationToDirection(cameraRotation)
    local destination = {
        x = cameraCoord.x + direction.x * distance,
        y = cameraCoord.y + direction.y * distance,
        z = cameraCoord.z + direction.z * distance
    }
    local _, hit, endCoords, _, _ = GetShapeTestResult(StartShapeTestRay(cameraCoord.x, cameraCoord.y, cameraCoord.z, destination.x, destination.y, destination.z, -1, PlayerPedId(), 0))

    return hit == 1, endCoords
end

function RotationToDirection(rotation)
    local adjustedRotation = {
        x = (math.pi / 180) * rotation.x,
        y = (math.pi / 180) * rotation.y,
        z = (math.pi / 180) * rotation.z
    }
    local direction = {
        x = -math.sin(adjustedRotation.z) * math.abs(math.cos(adjustedRotation.x)),
        y = math.cos(adjustedRotation.z) * math.abs(math.cos(adjustedRotation.x)),
        z = math.sin(adjustedRotation.x)
    }
    return direction
end

function Draw3DText(x, y, z, text)
    local onScreen, _x, _y = World3dToScreen2d(x, y, z)
    local px, py, pz = table.unpack(GetGameplayCamCoords())
    SetTextScale(0.35, 0.35)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, 215)
    SetTextEntry("STRING")
    SetTextCentre(1)
    AddTextComponentString(text)
    DrawText(_x, _y)
    local factor = (string.len(text)) / 370
    DrawRect(_x, _y + 0.0125, 0.015 + factor, 0.03, 41, 11, 41, 68)
end 