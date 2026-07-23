RegisterCommand("intro:start", function(source)
    TriggerClientEvent("introCinematic:start", source)
end, false)

RegisterCommand("intro:male", function(source)
    TriggerClientEvent("introCinematic:start", source, true)
end, false)

RegisterCommand("intro:female", function(source)
    TriggerClientEvent("introCinematic:start", source, false)
end, false)
