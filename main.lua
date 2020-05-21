local lg = love.graphics
local winW, winH = lg.getDimensions()

local bullider = require("bullider")
local MovingAverage = require("movingaverage")

local frameAdvance = false
local currentFrame = 0
local targetFrame = 0

local player = {
    x = 0, y = 0,
    speed = 120,
    hit = 0
}

local bulletSpeeds = {100, 1000, 2000, 2500}
local bulletIntervals = {0.01, 0.2, 0.5, 1.0}
local bulletSpawner = {
    x = 0, y = 0,
    amount = 20,
    time = 0,
    spawnTimer = 0,
    interval = bulletIntervals[1],
    angle = 0.25,
    angleRange = 0.3,
    bulletRadius = 5,
    bulletSpeed = bulletSpeeds[3],
    bulletColor = {1, 0, 0},
    bulletLifetime = nil,
}

local bullets = {}

local collisionDetectionDuration = MovingAverage(1000)

local playerGroup = bullider.group()
local bulletGroup = bullider.group()

function love.load()
    player.x = winW/2
    player.y = winH - 150

    --bullider.init(2000)
    bullider.init(20000)
    player.collider = bullider.spawn(player.x, player.y, 5, playerGroup)

    bulletSpawner.x = winW/2
    bulletSpawner.y = 50
end

local function spawnBullet(x, y, radius, vx, vy, color, lifetime, group)
    table.insert(bullets, {
        x = x, y = y,
        vx = vx, vy = vy,
        radius = radius,
        color = color,
        lifetime = lifetime,
        collider = group and bullider.spawn(x, y, radius, group),
    })
end

local function updateSpawner(spawner, dt)
    spawner.time = spawner.time + dt
    local cosArg = spawner.time * 2.0
    -- cosArg = cosArg / 300 * spawner.bulletSpeed
    spawner.x = math.sin(cosArg) * 400 + winW/2
    spawner.spawnTimer = spawner.spawnTimer + dt
    if spawner.spawnTimer > spawner.interval then
        local angle = (spawner.angle - spawner.angleRange / 2) * 2 * math.pi
        for i = 1, spawner.amount do
            local vx = math.cos(angle) * spawner.bulletSpeed
            local vy = math.sin(angle) * spawner.bulletSpeed
            spawnBullet(spawner.x, spawner.y, spawner.bulletRadius, vx, vy,
                spawner.bulletColor, spawner.bulletLifetime, bulletGroup)
            angle = angle + spawner.angleRange / (spawner.amount - 1) * 2 * math.pi
        end
        spawner.spawnTimer = 0
    end
end

local function updatePlayer(player, dt)
    local lk = love.keyboard
    local moveX = (lk.isDown("right") and 1 or 0) - (lk.isDown("left") and 1 or 0)
    local moveY = (lk.isDown("down") and 1 or 0) - (lk.isDown("up") and 1 or 0)
    local moveLen = math.sqrt(moveX*moveX + moveY*moveY)
    if moveLen > 0 then
        player.x = player.x + moveX / moveLen * player.speed * dt
        player.y = player.y + moveY / moveLen * player.speed * dt
    end
    bullider.update(player.collider, player.x, player.y)
end

local function spark(x, y)
    local angle = love.math.random() * 2 * math.pi
    local speed = 200
    local vx = math.cos(angle) * speed
    local vy = math.sin(angle) * speed
    spawnBullet(x, y, 2, vx, vy, {1, 1, 0}, 0.5)
end

local function getNextValue(valueList, value)
    for i, v in ipairs(valueList) do
        if value == v then
            if i == #valueList then
                return valueList[1]
            end
            return valueList[i + 1]
        end
    end
    error("No matching value")
end

function love.keypressed(key)
    if key == "c" then
        bullider.continuous = not bullider.continuous
    end

    if key == "m" then
        bullider.midphase = not bullider.midphase
    end

    if key == "i" then
        bulletSpawner.interval = getNextValue(bulletIntervals, bulletSpawner.interval)
    end

    if key == "s" then
        bulletSpawner.bulletSpeed = getNextValue(bulletSpeeds, bulletSpawner.bulletSpeed)
    end

    if key == "return" then
        frameAdvance = not frameAdvance
    end

    if frameAdvance and key == "space" then
        targetFrame = targetFrame + 1
    end
end

function love.update(dt)
    if not frameAdvance then
        targetFrame = targetFrame + 1
    end
    if currentFrame >= targetFrame then
        return
    end
    currentFrame = currentFrame + 1

    updateSpawner(bulletSpawner, dt)

    for i = #bullets, 1, -1 do
        local bullet = bullets[i]
        bullet.x = bullet.x + bullet.vx * dt
        bullet.y = bullet.y + bullet.vy * dt
        local dead = bullet.x < 0 or bullet.y < 0 or bullet.x > winW or bullet.y > winH
        if bullet.lifetime then
            bullet.lifetime = bullet.lifetime - dt
            if bullet.lifetime <= 0 then
                dead = true
            end
        end
        if dead then
            table.remove(bullets, i)
            bullider.despawn(bullet.collider)
        else
            bullider.update(bullet.collider, bullet.x, bullet.y)
        end
    end

    updatePlayer(player, dt)

    local start = love.timer.getTime()
    local collisions = bullider.getCollisions(player.collider, bulletGroup)
    if #collisions > 0 then
        print("collisions: ", unpack(collisions))
        player.hit = 1.0
    end
    collisionDetectionDuration(love.timer.getTime() - start)
end

local function lerp(a, b, t)
    return a + (b - a) * t
end

local function lerpArray(a, b, t)
    local ret = {}
    assert(#a == #b)
    for i = 1, #a do
        ret[i] = lerp(a[i], b[i], t)
    end
    return ret
end

local function drawPill(lastX, lastY, x, y, radius)
    local relX, relY = x - lastX, y - lastY
    local len = math.sqrt(relX*relX + relY*relY)
    local orthoX = -relY / len * radius
    local orthoY = relX / len * radius
    lg.polygon("fill",
        lastX - orthoX,
        lastY - orthoY,
        lastX + orthoX,
        lastY + orthoY,
        x + orthoX,
        y + orthoY,
        x - orthoX,
        y - orthoY)
    lg.circle("fill", lastX, lastY, radius)
    lg.circle("fill", x, y, radius)
end

local function drawColliderDebug(collider)
    lg.setColor(0.0, 0.2, 0.0)
    lg.circle("fill", collider.sweptBoundsX, collider.sweptBoundsY, collider.sweptBoundsRadius)
    lg.setColor(0.1, 0.1, 0.1)
    drawPill(collider.lastX, collider.lastY, collider.x, collider.y, collider.radius)
end

function love.draw()
    lg.setColor(0.5, 0.5, 0.5)
    lg.circle("fill", bulletSpawner.x, bulletSpawner.y, 5)

    for _, bullet in ipairs(bullets) do
        if frameAdvance and bullet.collider then
            drawColliderDebug(bullet.collider)
        end
        lg.setColor(bullet.color)
        lg.circle("fill", bullet.x, bullet.y, bullet.radius)
    end

    if frameAdvance then
        drawColliderDebug(player.collider)
    end

    -- I put this here, because of frame advance
    local hitDecayTime = 0.5
    player.hit = math.max(0, player.hit - love.timer.getDelta() / hitDecayTime)

    local px = player.x
    local py = player.y
    if not frameAdvance then
        local hitJiggleAmplitude = player.hit * 2
        local lmr = function() return love.math.random() * 2.0 - 1.0 end
        px = px + lmr() * hitJiggleAmplitude
        py = py + lmr() * hitJiggleAmplitude
    end
    lg.setColor(lerpArray({0, 0, 1}, {1, 1, 1}, player.hit))
    lg.circle("fill", px, py, player.collider.radius)

    lg.setColor(1, 1, 1)
    local lines = {
        ("Bullets: %d"):format(#bullets),
        ("FPS: %d"):format(love.timer.getFPS()),
        ("Collision Detection: %02fms"):format(collisionDetectionDuration() * 1000),
        "",
        ("Bullet Interval (I): %f"):format(bulletSpawner.interval),
        ("Bullet Speed (S): %f"):format(bulletSpawner.bulletSpeed),
        "",
        ("Frame Advance + Debug Draw (return, step = space): %s"):format(tostring(frameAdvance)),
        ("Continuous (C): %s"):format(tostring(bullider.continuous)),
        ("Midphase (M): %s"):format(tostring(bullider.midphase)),
    }
    for i, line in ipairs(lines) do
        lg.print(line, 5, 5 + (i - 1) * 20)
    end
end