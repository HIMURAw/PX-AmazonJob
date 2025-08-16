local QBCore = exports['qb-core']:GetCoreObject()

RegisterServerEvent('px-amazonjob:server:Payment', function(jobsDone)
    local src = source
    local payment = Config.Payment * jobsDone
    local Player = QBCore.Functions.GetPlayer(source)
    jobsDone = tonumber(jobsDone)
    if jobsDone > 0 then
        Player.Functions.AddMoney("cash", payment)
        TriggerClientEvent("QBCore:Notify", source, "Ücret teslim edildi $" .. payment, "success")
    end
end)
