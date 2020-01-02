-- Simple MQTT client

-- Copyright 2019, Marcin Gil <marcin.gil--gmail.com>

-- This program is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.

-- keep alive timer in seconds
KEEP_ALIVE = 180

function MqttClient(host, port, user, password, topic, clientId, cmd_callback)
    local self = {}

    -- private fields
    local h = host
    local p = port
    local t = topic
    local connected = false
    local callback = cmd_callback
    local m = nil

    local function self_register()
        if callback == nil then
            return
        end

        if not m:subscribe(clientId, 0, function(conn)
            print("MQTT subscribe successful")
        end) then
            print("MQTT unable to subscribe")
        end
    end

    local function on_connected(client)
        connected = true
        print ("MQTT Connected")

        self_register()
    end

    local function on_disconnected(client, reason)
        connected = false
        print ("MQTT Offline")
        tmr.create():alarm(10 * 1000, tmr.ALARM_SINGLE, self.connect)
    end

    local function on_message(client, topic, message)
        if callback ~= nil then
            callback(message)
        end
    end

    -- setup MQTT client

    print("MQTT setup for topic="..t.." clientid="..clientId.." at "..h..":"..p)
    m = mqtt.Client(clientId, KEEP_ALIVE, user, password)
    m:on("connect", on_connected)
    m:on("offline", on_disconnected)
    m:on("message", on_message)

    function self.connect()
        m:connect(h, p, false)
    end

    function self.publish(message)
        -- print("MQTT publishing -"..message.."@"..t)
        if not connected then
            print("MQTT connecting...")
            -- connect and mark connection established
            -- publish upon connection
            m:connect(h, p, false, function(client)
                connected = true
                client:publish(t, message, 0, 0, function(client)
                    print ("MQTT message sent")
                end, function(client, reason)
                    connected = false
                    print("MQTT unable to connect due to "..reason)
                end)
            end)
        else
            print("MQTT reusing connection")
            if not m:publish(t, message, 0, 0, function(client)
                print("MQTT message sent")
            end) then
                print ("MQTT unable to publish message")
            end
        end

        -- if not m:close() then
        --     connected = false
        --     print ("MQTT unable to close connection")
        -- end
    end

    return self
end