loadstring(game:HttpGet("https://raw.githubusercontent.com/X-1Hz/iOSCRIPT/refs/heads/main/gamelist.lua"))()
local gameFound = false
for PlaceID, Execute in pairs(Games) do
    if PlaceID == game.PlaceId then
        gameFound = true
        loadstring(game:HttpGet(Execute))()
        break
    end
end

if not gameFound then
    game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = "By iOSCRIPT",
        Text = "We’re sorry, but this game is not supported. Please check our Discord for a list of supported games",
        Duration = 10
    })
end
