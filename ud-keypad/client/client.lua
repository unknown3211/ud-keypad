local QBCore = exports['qb-core']:GetCoreObject()
local currentLocation = nil

local function toggleNuiFrame(shouldShow, location)
  SetNuiFocus(shouldShow, shouldShow)
  SendReactMessage('setVisible', shouldShow)
  if shouldShow and location then
    SendData(location)
    currentLocation = location
  end
end

Citizen.CreateThread(function()
  while true do
    Citizen.Wait(0)
    local playerCoords = GetEntityCoords(PlayerPedId())
    local closestDistance = math.huge
    local closestLocation = nil

    for name, location in pairs(Config.Locations) do
      local distance = #(playerCoords - location.coords)
      if distance < closestDistance then
        closestDistance = distance
        closestLocation = location
        closestLocation.name = name
      end
    end

    if closestLocation and closestDistance < 1.5 then
      DrawText3D(closestLocation.coords.x, closestLocation.coords.y, closestLocation.coords.z, 'Press [~g~E~w~] to open keypad')
      if IsControlJustPressed(0, 38) then
        toggleNuiFrame(true, closestLocation)
      end
    end
  end
end)

RegisterNUICallback('hideFrame', function(_, cb)
  toggleNuiFrame(false)
  cb({})
end)

RegisterNUICallback('passwordsucessful', function(_, cb)
  toggleNuiFrame(false)
  QBCore.Functions.Notify('Password correct', 1)

  if currentLocation and currentLocation.name then
    local stashName = currentLocation.name
    TriggerServerEvent('inventory:server:OpenInventory', 'stash', stashName, {
      maxweight = 600000,
      slots = 30,
    })
    TriggerEvent('inventory:client:SetCurrentStash', stashName)
  else
    print("Password Sucessful But Still Damn Error")
  end

  cb({})
end)

RegisterNUICallback('passwordincorrect', function(_, cb)
  QBCore.Functions.Notify('Password incorrect', 2)
  toggleNuiFrame(false)
  cb({})
end)

function SendData(location)
  SendNUIMessage({
    action = 'SendPasswordData',
    data = location.password
  })
end

function DrawText3D(x, y, z, text)
  local onScreen, _x, _y = World3dToScreen2d(x, y, z)
  local px, py, pz = table.unpack(GetGameplayCamCoords())
  local scale = 0.35

  if onScreen then
    SetTextScale(scale, scale)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, 215)
    SetTextEntry("STRING")
    SetTextCentre(1)
    AddTextComponentString(text)
    DrawText(_x, _y)
    local factor = (string.len(text)) / 370
    DrawRect(_x, _y + 0.0125, 0.015 + factor, 0.03, 41, 11, 41, 100)
  end
end