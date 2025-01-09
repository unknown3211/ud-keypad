local QBCore = exports['qb-core']:GetCoreObject()
local locations = {}
local ownedLocations = {}
local ox_inventory = exports.ox_inventory
local debugEnabled = false -- Set to true to enable debug messages, false to disable

-- Debug function
local function Debug(message)
    if debugEnabled then
        print('^3[ud-keypad:client]^0: ' .. message)
    end
end

-- Function to load locations from database
local function CreateStash(name)
    if not name then return end
    
    local stashId = name
    Debug('Creating stash: ' .. stashId)
    
    -- Register the stash with ox_inventory
    ox_inventory:RegisterStash(stashId, 'Storage Locker', 50, 100000)
    Debug('Stash registered: ' .. stashId)
end

-- Function to load locations from database
local function LoadLocations()
    Debug('Loading locations from database')
    local query = "SELECT * FROM `ud-keypad`"
    exports.oxmysql:execute(query, {}, function(results)
        if not results then
            Debug('No locations found in database')
            return
        end

        Debug('Found ' .. #results .. ' locations')
        locations = {}
        
        for _, result in ipairs(results) do
            local coordsTable = json.decode(result.coords)
            local location = {
                name = result.name,
                price = result.price,
                coords = vector3(coordsTable.x, coordsTable.y, coordsTable.z),
                owner = result.owner,
                password = result.password
            }
            table.insert(locations, location)
            -- Create stash for this location
            CreateStash(location.name)
            Debug(('Loaded location: %s at coords: %s'):format(location.name, json.encode(coordsTable)))
        end
        
        -- Sync to all clients
        TriggerClientEvent('ud-keypad:syncLocations', -1, locations)
    end)
end

-- Function to load owned locations from database
local function LoadOwnedLocations()
    Debug('Loading owned locations')
    local query = "SELECT * FROM `ud-keypad` WHERE owner IS NOT NULL"
    exports.oxmysql:execute(query, {}, function(results)
        if results then
            ownedLocations = {}
            for _, result in ipairs(results) do
                ownedLocations[result.name] = {
                    owner = result.owner,
                    price = result.price
                }
                Debug(('Loaded owned location: %s by %s'):format(result.name, result.owner))
            end
            -- Sync to all clients
            TriggerClientEvent('ud-keypad:syncOwnedLocations', -1, ownedLocations)
        end
    end)
end

-- Request sync event
RegisterNetEvent('ud-keypad:requestSync', function()
    local src = source
    Debug('Sync requested by ' .. src)
    TriggerClientEvent('ud-keypad:syncLocations', src, locations)
    TriggerClientEvent('ud-keypad:syncOwnedLocations', src, ownedLocations)
end)

-- Call this when resource starts
AddEventHandler('onResourceStart', function(resourceName)
    if (GetCurrentResourceName() ~= resourceName) then return end
    Debug('Resource started, loading data')
    LoadLocations()
    LoadOwnedLocations()
end)

-- Call this when a player joins to sync current state
RegisterNetEvent('QBCore:Server:PlayerLoaded', function()
    local src = source
    Debug('Player ' .. src .. ' loaded, syncing data')
    TriggerClientEvent('ud-keypad:syncLocations', src, locations)
    TriggerClientEvent('ud-keypad:syncOwnedLocations', src, ownedLocations)
end)

RegisterNetEvent('ud-keypad:buyLocation', function(locationData)
    local src = source
    local player = QBCore.Functions.GetPlayer(src)
    local citizenId = player.PlayerData.citizenid
    local playerMoney = player.Functions.GetMoney('cash')
    
    -- Update existing location instead of creating new one
    local query = "UPDATE `ud-keypad` SET owner = ? WHERE name = ?"
    exports.oxmysql:execute(query, {citizenId, locationData.name}, function(result)
        if result and result.affectedRows > 0 then
            -- Update owned locations table
            ownedLocations[locationData.name] = {
                owner = citizenId,
                price = locationData.price
            }
            
            -- Sync to clients and remove money
            TriggerClientEvent('ud-keypad:syncOwnedLocations', -1, ownedLocations)
            player.Functions.RemoveMoney('cash', locationData.price)
        end
    end)
end)

-- Add this function at the top with other utility functions
local function IsLocationOwner(source, locationName)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return false end
    
    local citizenId = Player.PlayerData.citizenid
    return ownedLocations[locationName] and ownedLocations[locationName].owner == citizenId
end

-- Update the password update event handler to check ownership
RegisterNetEvent('ud-keypad:updatePassword', function(data)
    local src = source
    Debug('Password update requested for location: ' .. data.name)
    
    -- Get player info
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    
    local citizenId = Player.PlayerData.citizenid
    
    -- Verify ownership
    if not ownedLocations[data.name] or ownedLocations[data.name].owner ~= citizenId then
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = 'You do not own this location'
        })
        return
    end
    
    -- Update password in database
    local query = "UPDATE `ud-keypad` SET password = ? WHERE name = ? AND owner = ?"
    
    exports.oxmysql:execute(query, {data.password, data.name, citizenId}, function(result)
        if result and result.affectedRows and result.affectedRows > 0 then
            -- Update the password in the locations table
            for i, location in ipairs(locations) do
                if location.name == data.name then
                    location.password = data.password
                    Debug('Password updated for location: ' .. data.name)
                    break
                end
            end
            
            -- Notify success
            TriggerClientEvent('ox_lib:notify', src, {
                type = 'success',
                description = 'Password updated successfully'
            })
            
            -- Sync the updated locations to all clients
            TriggerClientEvent('ud-keypad:syncLocations', -1, locations)
        else
            Debug('Failed to update password for location: ' .. data.name)
            TriggerClientEvent('ox_lib:notify', src, {
                type = 'error',
                description = 'Failed to update password'
            })
        end
    end)
end)

-- Update the sell location event handler to check ownership
RegisterNetEvent('ud-keypad:sellLocation', function(data)
    local src = source
    local locationData = data.locationData
    
    -- Verify ownership
    if not IsLocationOwner(src, locationData.name) then
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = 'You do not own this location'
        })
        return
    end
    
    -- Rest of the selling logic remains the same
    local query = "UPDATE `ud-keypad` SET owner = NULL, password = NULL WHERE name = ?"
    exports.oxmysql:execute(query, {locationData.name}, function(result)
        if result and result.affectedRows > 0 then
            ownedLocations[locationData.name] = nil
            exports.ox_inventory:AddItem(src, 'money', locationData.price * 0.8)
            
            TriggerClientEvent('ox_lib:notify', src, {
                type = 'success',
                description = ('You sold %s for $%s'):format(locationData.name, locationData.price * 0.8)
            })
            
            TriggerClientEvent('ud-keypad:syncOwnedLocations', -1, ownedLocations)
        else
            TriggerClientEvent('ox_lib:notify', src, {
                type = 'error',
                description = 'Failed to sell location'
            })
        end
    end)
end)

-- Add this near the top with other command registrations
QBCore.Commands.Add('createvault', 'Create a new vault location (Realtors Only)', {
    {name = 'name', help = 'Name of the vault'},
    {name = 'price', help = 'Price of the vault'},
}, true, function(source, args)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    -- Check if player is a realtor
    if Player.PlayerData.job.name ~= "realtor" then
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = 'You must be a realtor to use this command'
        })
        return
    end

    -- Validate inputs
    local name = args[1]
    local price = tonumber(args[2])
    
    if not name or not price then
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = 'Invalid parameters. Usage: /createvault [name] [price]'
        })
        return
    end

    -- Get player's current coordinates
    local ped = GetPlayerPed(src)
    local coords = GetEntityCoords(ped)

    -- Insert into database
    local query = [[
        INSERT INTO `ud-keypad` (name, price, coords) 
        VALUES (?, ?, ?)
    ]]

    local coordsJson = json.encode({
        x = coords.x,
        y = coords.y,
        z = coords.z
    })

    exports.oxmysql:execute(query, {name, price, coordsJson}, function(result)
        if result and result.affectedRows > 0 then
            -- Create the stash
            CreateStash(name)
            
            -- Add to locations table
            local newLocation = {
                name = name,
                price = price,
                coords = coords,
                owner = nil,
                password = nil
            }
            table.insert(locations, newLocation)

            -- Notify success
            TriggerClientEvent('ox_lib:notify', src, {
                type = 'success',
                description = 'Vault location created successfully'
            })

            -- Sync to all clients
            TriggerClientEvent('ud-keypad:syncLocations', -1, locations)
        else
            TriggerClientEvent('ox_lib:notify', src, {
                type = 'error',
                description = 'Failed to create vault location'
            })
        end
    end)
end)

QBCore.Commands.Add('deletevault', 'Delete a vault location (Realtors Only)', {
    {name = 'name', help = 'Name of the vault to delete'},
}, true, function(source, args)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    -- Check if player is a realtor
    if Player.PlayerData.job.name ~= "realtor" then
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = 'You must be a realtor to use this command'
        })
        return
    end

    local name = args[1]
    if not name then
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = 'Invalid parameters. Usage: /deletevault [name]'
        })
        return
    end

    -- Delete from database
    local query = "DELETE FROM `ud-keypad` WHERE name = ?"
    exports.oxmysql:execute(query, {name}, function(result)
        if result and result.affectedRows > 0 then
            -- Remove from locations table
            for i, location in ipairs(locations) do
                if location.name == name then
                    table.remove(locations, i)
                    break
                end
            end

            -- Remove from owned locations if applicable
            if ownedLocations[name] then
                ownedLocations[name] = nil
            end

            -- Trigger target removal on all clients
            TriggerClientEvent('ud-keypad:removeVaultTarget', -1, name)

            -- Notify success
            TriggerClientEvent('ox_lib:notify', src, {
                type = 'success',
                description = 'Vault location deleted successfully'
            })

            -- Sync to all clients
            TriggerClientEvent('ud-keypad:syncLocations', -1, locations)
            TriggerClientEvent('ud-keypad:syncOwnedLocations', -1, ownedLocations)
        else
            TriggerClientEvent('ox_lib:notify', src, {
                type = 'error',
                description = 'Failed to delete vault location'
            })
        end
    end)
end)

RegisterNetEvent('ud-keypad:checkRealtorJob', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if Player.PlayerData.job.name == "realtor" then
        TriggerClientEvent('ud-keypad:startVaultCreation', src)
    else
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = 'You must be a realtor to use this command'
        })
    end
end)

RegisterNetEvent('ud-keypad:createVault', function(data)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    -- Double check they're still a realtor
    if Player.PlayerData.job.name ~= "realtor" then
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = 'You must be a realtor to create vaults'
        })
        return
    end

    -- Insert into database
    local query = [[
        INSERT INTO `ud-keypad` (name, price, coords) 
        VALUES (?, ?, ?)
    ]]

    local coordsJson = json.encode({
        x = data.coords.x,
        y = data.coords.y,
        z = data.coords.z
    })

    exports.oxmysql:execute(query, {data.name, data.price, coordsJson}, function(result)
        if result and result.affectedRows > 0 then
            -- Create the stash
            CreateStash(data.name)
            
            -- Add to locations table
            local newLocation = {
                name = data.name,
                price = data.price,
                coords = data.coords,
                owner = nil,
                password = nil
            }
            table.insert(locations, newLocation)

            -- Notify success
            TriggerClientEvent('ox_lib:notify', src, {
                type = 'success',
                description = 'Vault location created successfully'
            })

            -- Sync to all clients
            TriggerClientEvent('ud-keypad:syncLocations', -1, locations)
        else
            TriggerClientEvent('ox_lib:notify', src, {
                type = 'error',
                description = 'Failed to create vault location'
            })
        end
    end)
end)