--
-- lua-periphery by vsergeev
-- https://github.com/vsergeev/lua-periphery
-- License: MIT
--

require('test')
local periphery = require('periphery')
local I2C = periphery.I2C

--------------------------------------------------------------------------------

local I2C_EEPROM_ADDRESS    = 0x51

local device = nil

--------------------------------------------------------------------------------

function test_arguments()
    local i2c = nil

    ptest()

    -- Open with invalid type
    passert_periphery_error("open invalid type", function () i2c = I2C(123) end, "I2C_ERROR_ARG")
end

function test_open_config_close()
    local i2c = nil

    ptest()

    -- Open non-existent i2c device
    passert_periphery_error("non-existent device", function () i2c = I2C("/foo/bar") end, "I2C_ERROR_OPEN")

    -- Open legitimate i2c device
    passert_periphery_success("open i2c", function () i2c = I2C(device) end)
    passert("fd > 0", i2c.fd > 0)
    io.write(string.format("i2c: %s\n", i2c:__tostring()))

    -- Close i2c
    passert_periphery_success("close i2c", function () i2c:close() end)
end

function test_loopback()
    local i2c = nil

    ptest()

    -- Open i2c device
    passert_periphery_success("open i2c", function () i2c = I2C(device) end)

    -- Generate random byte vector
    local vector_table = {}
    local vector_str = ""
    math.randomseed(1234)
    for i=1, 32 do
        local b = math.random(0, 255)
        vector_table[i] = b
        vector_str = vector_str .. string.char(b)
    end

    -- Write bytes to 0x100 with table
    -- S [ 0x51 W ] [ 0x01 ] [ 0x00 ] [ Data... ] P
    local msgs = { { 0x01, 0x00 } }
    for i=1, #vector_table do msgs[1][2 + i] = vector_table[i] end
    passert_periphery_success("write bytes to 0x100", function () i2c:transfer(I2C_EEPROM_ADDRESS, msgs) end)

    -- Wait for Write Cycle
    periphery.sleep_ms(10)

    -- Read bytes from 0x100 with table
    -- S [ 0x51 W ] [ 0x01 ] [ 0x00 ] S [ 0x51 R ] [ Data... ] P
    local msgs = { { 0x01, 0x00 }, { flags = I2C.I2C_M_RD } }
    for i=1, #vector_table do msgs[2][i] = 0x00 end
    passert_periphery_success("read bytes from 0x100", function () i2c:transfer(I2C_EEPROM_ADDRESS, msgs) end)

    -- Verify bytes
    for i=1, #vector_table do
        if msgs[2][i] ~= vector_table[i] then
            pfail(string.format("mismatch on index %d. expected 0x%02x, got 0x%02x", i, vector_table[i], msgs[2][i]))
            os.exit(1)
        end
    end

    -- Write bytes to 0x200 with string
    -- S [ 0x51 W ] [ 0x02 ] [ 0x00 ] [ Data... ] P
    local msgs = { { string.char(0x02) .. string.char(0x00) .. vector_str } }
    passert_periphery_success("write bytes to 0x200", function () i2c:transfer(I2C_EEPROM_ADDRESS, msgs) end)

    -- Wait for Write Cycle
    periphery.sleep_ms(10)

    -- Read bytes from 0x200 with string
    -- S [ 0x51 W ] [ 0x02 ] [ 0x00 ] S [ 0x51 R ] [ Data... ] P
    local msgs = { { string.char(0x02) .. string.char(0x00) }, { string.rep(string.char(0x00), #vector_str), flags = I2C.I2C_M_RD } }
    passert_periphery_success("read bytes from 0x200", function () i2c:transfer(I2C_EEPROM_ADDRESS, msgs) end)

    -- Verify bytes
    passert("verify bytes", msgs[2][1] == vector_str)

    -- Close i2c device
    passert_periphery_success("close i2c", function () i2c:close() end)
end

function test_interactive()
    local i2c = nil

    ptest()

    passert_periphery_success("open i2c", function () i2c = I2C(device) end)

    print("Starting interactive test. Get out your logic analyzer, buddy!")
    print("Press enter to continue...")
    io.read()

    -- Check tostring
    io.write(string.format("I2C description: %s\n", i2c:__tostring()))
    print("I2C description looks OK? y/n")
    passert("interactive success", io.read() == "y")

    -- There isn't much we can do without assuming a device on the other end,
    -- because I2C needs an acknowledgement bit on each transferred byte.
    --
    -- But we can send a transaction and expect it to time out.

    -- S [ 0x7a W ] [0xaa] [0xbb] [0xcc] [0xdd] NA
    local msgs = { { 0xaa, 0xbb, 0xcc, 0xdd } }

    print("Press enter to start transfer...")
    io.read()
    passert_periphery_error("transfer to non-existent device", function () i2c:transfer(0x7a, msgs) end, "I2C_ERROR_TRANSFER", 121)
    passert_periphery_success("close i2c", function () i2c:close() end)

    print("I2C transfer occurred? y/n")
    passert("interactive success", io.read() == "y")
end

if #arg < 1 then
    io.stderr:write(string.format("Usage: lua %s <I2C device>\n\n", arg[0]))
    io.stderr:write("[1/4] Arguments test: No requirements.\n")
    io.stderr:write("[2/4] Open/close test: I2C device should be real.\n")
    io.stderr:write("[3/4] Loopback test: Expects 24XX32 EEPROM (or similar) at address 0x51.\n")
    io.stderr:write("[4/4] Interactive test: I2C bus should be observed with an oscilloscope or logic analyzer.\n\n")
    io.stderr:write("Hint: for Raspberry Pi 3, enable I2C1 with:\n")
    io.stderr:write("   $ echo \"dtparam=i2c_arm=on\" | sudo tee -a /boot/config.txt\n")
    io.stderr:write("   $ sudo reboot\n")
    io.stderr:write("Use pins I2C1 SDA (header pin 2) and I2C1 SCL (header pin 3),\n")
    io.stderr:write("and run this test with:\n")
    io.stderr:write(string.format("    lua %s /dev/i2c-1\n\n", arg[0]))
    os.exit(1)
end

device = arg[1]

test_arguments()
pokay("Arguments test passed.")
test_open_config_close()
pokay("Open/close test passed.")
test_loopback()
pokay("Loopback test passed.")
test_interactive()
pokay("Interactive test passed.")

pokay("All tests passed!")

