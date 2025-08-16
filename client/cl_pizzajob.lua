local QBCore = exports['qb-core']:GetCoreObject()
local Hired = false
local Hascargo = false
local DeliveriesCount = 0
local Delivered = false
local cargoDelivered = false
local ownsVan = false
local activeOrder = false

CreateThread(function()
    local cargojobBlip = AddBlipForCoord(vector3(Config.BossCoords.x, Config.BossCoords.y, Config.BossCoords.z))
    SetBlipSprite(cargojobBlip, 267)
    SetBlipAsShortRange(cargojobBlip, true)
    SetBlipScale(cargojobBlip, 0.4)
    SetBlipColour(cargojobBlip, 2)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("cargo Teslimatı")
    EndTextCommandSetBlipName(cargojobBlip)
end)

function ClockInPed()
    if not DoesEntityExist(cargoBoss) then
        RequestModel(Config.BossModel)
        while not HasModelLoaded(Config.BossModel) do Wait(0) end

        cargoBoss = CreatePed(0, Config.BossModel, Config.BossCoords, false, false)

        SetEntityAsMissionEntity(cargoBoss)
        SetPedFleeAttributes(cargoBoss, 0, 0)
        SetBlockingOfNonTemporaryEvents(cargoBoss, true)
        SetEntityInvincible(cargoBoss, true)
        FreezeEntityPosition(cargoBoss, true)
        loadAnimDict("amb@world_human_leaning@female@wall@back@holding_elbow@idle_a")
        TaskPlayAnim(cargoBoss, "amb@world_human_leaning@female@wall@back@holding_elbow@idle_a", "idle_a", 8.0, 1.0, -1,
            01, 0, 0, 0, 0)

        exports['qb-target']:AddTargetEntity(cargoBoss, {
            options = {
                {
                    type = "client",
                    event = "px-amazonjob:client:startJob",
                    icon = "fa-solid fa-cargo-slice",
                    label = "İşe Başla",
                    canInteract = function()
                        return not Hired
                    end,
                },
                {
                    type = "client",
                    event = "px-amazonjob:client:finishWork",
                    icon = "fa-solid fa-cargo-slice",
                    label = "İşi Bitir Ve Paranı Al",
                    canInteract = function()
                        return Hired
                    end,
                },
            },
            distance = 1.5,
        })
    end
end

AddEventHandler('onResourceStart', function(resource)
    if GetCurrentResourceName() == resource then
        PlayerJob = QBCore.Functions.GetPlayerData().job
        ClockInPed()
    end
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    ClockInPed()
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    exports['qb-target']:RemoveZone("deliverZone")
    RemoveBlip(JobBlip)
    Hired = false
    Hascargo = false
    DeliveriesCount = 0
    Delivered = false
    cargoDelivered = false
    ownsVan = false
    activeOrder = false
    DeletePed(cargoBoss)
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        exports['qb-target']:RemoveZone("deliverZone")
        RemoveBlip(JobBlip)
        Hired = false
        Hascargo = false
        DeliveriesCount = 0
        Delivered = false
        cargoDelivered = false
        ownsVan = false
        activeOrder = false
        DeletePed(cargoBoss)
    end
end)

CreateThread(function()
    DecorRegister("cargo_job", 1)
end)

function PullOutVehicle()
    if ownsVan then
        QBCore.Functions.Notify("Zaten bir iş aracınız var! Git ve topla ya da işini bitir.", "error")
    else
        local coords = Config.VehicleSpawn
        QBCore.Functions.SpawnVehicle(Config.Vehicle, function(cargoCar)
            SetVehicleNumberPlateText(cargoCar, "cargo" .. tostring(math.random(1000, 9999)))
            SetVehicleColours(cargoCar, 111, 111)
            SetVehicleDirtLevel(cargoCar, 1)
            DecorSetFloat(cargoCar, "cargo_job", 1)
            TaskWarpPedIntoVehicle(PlayerPedId(), cargoCar, -1)
            TriggerEvent("vehiclekeys:client:SetOwner", GetVehicleNumberPlateText(cargoCar))
            SetVehicleEngineOn(cargoCar, true, true)
            exports[Config.FuelScript]:SetFuel(cargoCar, 100.0)
            exports['qb-target']:AddTargetEntity(cargoCar, {
                options = {
                    {
                        icon = "fa-solid fa-cargo-slice",
                        label = "cargoyı Al",
                        action = function(entity) Takecargo() end,
                        canInteract = function()
                            return Hired and activeOrder and not Hascargo
                        end,

                    },
                },
                distance = 2.5
            })
        end, coords, true)
        Hired = true
        ownsVan = true
        NextDelivery()
    end
end

RegisterNetEvent('px-amazonjob:client:startJob', function()
    if not Hired then
        PullOutVehicle()
    end
end)


RegisterNetEvent('px-amazonjob:client:delivercargo', function()
    if Hascargo and Hired and not cargoDelivered then
        TriggerEvent('animations:client:EmoteCommandStart', { "knock" })
        cargoDelivered = true
        QBCore.Functions.Progressbar("knock", "kargoyu teslim ediyorsun...", 7000, false, false, {
            disableMovement = true,
            disableCarMovement = true,
            disableMouse = false,
            disableCombat = true,
        }, {}, {}, {}, function()
            DeliveriesCount = DeliveriesCount + 1
            RemoveBlip(JobBlip)
            exports['qb-target']:RemoveZone("deliverZone")
            Hascargo = false
            activeOrder = false
            cargoDelivered = false
            DetachEntity(prop, 1, 1)
            DeleteObject(prop)
            Wait(1000)
            ClearPedSecondaryTask(PlayerPedId())
            QBCore.Functions.Notify("Kargoyu teslim ettin, birazdan yeni siparişin gelecek!", "success")
            SetTimeout(5000, function()
                NextDelivery()
            end)
        end)
    else
        QBCore.Functions.Notify("Elinde Kargo yok adamlar seni mi kullanzın?", "error")
    end
end)


function loadAnimDict(dict)
    while not HasAnimDictLoaded(dict) do
        RequestAnimDict(dict)
        Wait(0)
    end
end

function Takecargo()
    local player = PlayerPedId()
    local pos = GetEntityCoords(player)
    if not IsPedInAnyVehicle(player, false) then
        local ad = "anim@heists@box_carry@"
        local prop_name = 'prop_cs_cardbox_01'
        if DoesEntityExist(player) and not IsEntityDead(player) then
            if not Hascargo then
                if #(pos - vector3(newDelivery.x, newDelivery.y, newDelivery.z)) < 30.0 then
                    loadAnimDict(ad)
                    local x, y, z = table.unpack(GetEntityCoords(player))
                    prop = CreateObject(GetHashKey(prop_name), x, y, z + 0.2, true, true, true)
                    AttachEntityToEntity(prop, player, GetPedBoneIndex(player, 60309), 0.2, 0.08, 0.2, -45.0, 290.0, 0.0,
                        true, true, false, true, 1, true)
                    TaskPlayAnim(player, ad, "idle", 3.0, -8, -1, 63, 0, 0, 0, 0)
                    Hascargo = true
                else
                    QBCore.Functions.Notify("Eve yeterince yakın değilsin!", "error")
                end
            end
        end
    end
end

function NextDelivery()
    if not activeOrder then
        newDelivery = Config.JobLocs[math.random(1, #Config.JobLocs)]

        JobBlip = AddBlipForCoord(newDelivery.x, newDelivery.y, newDelivery.z)
        SetBlipSprite(JobBlip, 1)
        SetBlipDisplay(JobBlip, 4)
        SetBlipScale(JobBlip, 0.8)
        SetBlipFlashes(JobBlip, true)
        SetBlipAsShortRange(JobBlip, true)
        SetBlipColour(JobBlip, 2)
        SetBlipRoute(JobBlip, true)
        SetBlipRouteColour(JobBlip, 2)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentSubstringPlayerName("Next Customer")
        EndTextCommandSetBlipName(JobBlip)
        exports['qb-target']:AddCircleZone("deliverZone", vector3(newDelivery.x, newDelivery.y, newDelivery.z), 1.3,
            { name = "deliverZone", debugPoly = false, useZ = true, },
            { options = { { type = "client", event = "px-amazonjob:client:delivercargo", icon = "fa-solid fa-cargo-slice", label = "cargoyi Teslim Et" }, }, distance = 1.5 })
        activeOrder = true
        QBCore.Functions.Notify("İşte yeni siparişin!", "success")
    end
end

RegisterNetEvent('px-amazonjob:client:finishWork', function()
    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped)
    local veh = QBCore.Functions.GetClosestVehicle()
    local finishspot = vector3(Config.BossCoords.x, Config.BossCoords.y, Config.BossCoords.z)
    if #(pos - finishspot) < 10.0 then
        if Hired then
            if DecorExistOn((veh), "cargo_job") then
                QBCore.Functions.DeleteVehicle(veh)
                RemoveBlip(JobBlip)
                Hired = false
                Hascargo = false
                ownsVan = false
                activeOrder = false
                if DeliveriesCount > 0 then
                    TriggerServerEvent('px-amazonjob:server:Payment', DeliveriesCount)
                else
                    QBCore.Functions.Notify("Herhangi bir teslimat yapmadınız, bu yüzden size ödeme yapılmadı.", "error")
                end
                DeliveriesCount = 0
            else
                QBCore.Functions.Notify("Ödeme almak için iş aracınızı iade etmelisiniz.", "error")
                return
            end
        end
    end
end)
