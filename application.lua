-- Simple HC-SR04 application

-- Copyright 2019, Marcin Gil <marcin.gil--gmail.com>

-- This program is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.

-- Derived work from Vinícius Serafim <vinicius@serafim.eti.br>
-- see: https://github.com/vsserafim/hcsr04-nodemcu/blob/master/hcsr04-simple.lua

PIN_TRIG = 4
PIN_ECHO = 3


-- trig interval in microseconds (minimun is 10, see HC-SR04 documentation)
TRIG_INTERVAL = 15
-- maximum distance in meters
MAXIMUM_DISTANCE = 10
-- minimum reading interval with 20% of margin
READING_INTERVAL = math.ceil(((MAXIMUM_DISTANCE * 2 / 340 * 1000) + TRIG_INTERVAL) * 1.2)
-- number of readings to average
AVG_READINGS = 3
-- CONTINUOUS MEASURING
CONTINUOUS = true
-- interval between scheduling continous reading; 30 seconds
CONTINUOUS_INTERVAL = 30 * 1000

-- notify to MQTT
PUBLISH = true
MQTT_TOPIC = "/coal"
MQTT_CLIENTID = "coalo"

-- initialize global variables
time_start = 0
time_stop = 0
distance = 0
readings = {}
trig_timer = {}
cont_timer = {}
mqtt_client = {}

-- start a measure cycle
function measure()
	print("Measuring starts")
	readings = {}
	trig_timer:start()
end

-- called when measure is done
function done_measuring()
	print("Distance: "..string.format("%.3f", distance).." Readings: "..#readings)
	if CONTINUOUS then
		print("Scheduling next measure")
		if not cont_timer:start() then
			print("WARN: unable to start continuous measure!")
		end
    end
	if PUBLISH then
		print("Scheduling measure publishing")
        node.task.post(publish)
    end
end

-- distance calculation, called by the echo_callback function on falling edge.
function calculate()
	print("Calculate")

	-- echo time (or high level time) in microseconds
	local echo_time = (time_stop - time_start)

	-- got a valid reading
	if echo_time > 0 then
		-- distance = echo time (or high level time) in microseconds * velocity of sound (340M/S) / 2
		local distance = echo_time * 0.034 / 2
		table.insert(readings, distance)
	end

	-- got all readings
	if #readings >= AVG_READINGS then
		print("Calculate: enough readings")
		trig_timer:stop()

		-- calculate the average of the readings
		distance = 0
		for k,v in pairs(readings) do
			distance = distance + v
		end
		distance = math.floor(distance / #readings)

		node.task.post(done_measuring)
	end

	print("Calculate exit")
end

-- publish measurement to the MQTT
function publish()
	print("Publishing "..distance)
	mqtt_client.publish(tostring(distance))
end

-- echo callback function called on both rising and falling edges
function echo_callback(level, timestamp)
	print("Callback at LVL="..level.." with T="..timestamp)

	if level == 1 then
		print("Echo start")
		-- rising edge (low to high)
        -- time_start = tmr.now()
        time_start = timestamp
	else
		print("Echo stop")
		-- falling edge (high to low)
        -- time_stop = tmr.now()
        time_stop = timestamp
		calculate()
	end
end

-- send trigger signal
function trigger()
	print("Triggering")
	gpio.write(PIN_TRIG, gpio.HIGH)
	tmr.delay(TRIG_INTERVAL)
	gpio.write(PIN_TRIG, gpio.LOW)
end

print("Setup")

-- configure pins
gpio.mode(PIN_TRIG, gpio.OUTPUT)
gpio.mode(PIN_ECHO, gpio.INT)

-- trigger timer
trig_timer = tmr.create()
trig_timer:register(READING_INTERVAL, tmr.ALARM_AUTO, trigger)

-- set callback function to be called both on rising and falling edges
gpio.trig(PIN_ECHO, "both", echo_callback)

-- configure CONTINUOUS timers
if CONTINUOUS then
	cont_timer = tmr.create()
	cont_timer:register(CONTINUOUS_INTERVAL, tmr.ALARM_SEMI, measure)
end

-- configure MQTT if enabled
if PUBLISH then
	dofile("mqtt.lua")
	-- MQTT host, port, user and password should be defined in the `credentials.lua`; see init.lua
	mqtt_client = MqttClient(MQTT_HOST, MQTT_PORT, MQTT_USER, MQTT_PASSWORD, MQTT_TOPIC, MQTT_CLIENTID)
end

print("Setup finished")