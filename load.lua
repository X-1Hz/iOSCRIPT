-- 1. ตรวจสอบ PlaceId (Game ID) ของผู้เล่นปัจจุบัน
local currentGameId = game.PlaceId

-- 2. รายชื่อแมพที่รองรับและลิงก์ไฟล์โค้ดจริง (ลิงก์ Raw จาก GitHub)
local gameScripts = {
    [106484206883664] = "https://raw.githubusercontent.com/ชื่อยูสเซอร์ของคุณ/ชื่อเรโป/main/games/game_1.lua", -- เปลี่ยนเป็น ID และลิงก์จริงของแมพที่ 1
}

-- 3. ทำการโหลดสคริปต์เฉพาะแมพที่ตรงกัน
local targetScriptUrl = gameScripts[currentGameId]

if targetScriptUrl then
    local success, err = pcall(function()
        loadstring(game:HttpGet(targetScriptUrl))()
    end)
    
    if not success then
        warn("เกิดข้อผิดพลาดในการโหลดสคริปต์: " .. tostring(err))
    end
else
    warn("สคริปต์นี้ไม่รองรับเกมที่คุณกำลังเล่นอยู่!")
end
