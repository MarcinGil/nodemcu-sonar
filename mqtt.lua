-- Simple MQTT client

-- Copyright 2019, Marcin Gil <marcin.gil--gmail.com>

-- This program is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.

-- keep alive timer in seconds
KEEP_ALIVE = 180

function MqttClient(host, port, user, password, topic, clientId)
    local self = {}

    -- private fields
    local h = host
    local p = port
    local t = topic
    local connected = false

    -- setup MQTT client
    print("MQTT setup for topic="..t.." clientid="..clientId.." at "..h..":"..p)
    local m = mqtt.Client(clientId, KEEP_ALIVE, user, password)
    m:on("connect", function(client)
        connected = true
        print ("MQTT Connected")
    end)
    m:on("offline", function(client)
        connected = false
        print ("MQTT Offline")
    end)

    function self.publish(message)
        -- print("MQTT publishing -"..message.."@"..t)
        if not connected then
            print("MQTT connecting...")
            -- connect and mark connection established
            -- publish upon connection
            m:connect(h, p, 0, function(client)
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

        if not m:close() then
            connected = false
            print ("MQTT unable to close connection")
        end
    end

    return self
end