--
-- lua-periphery by vsergeev
-- https://github.com/vsergeev/lua-periphery
-- License: MIT
--

require('test')
local periphery = require('periphery')
local SPI = periphery.SPI

--------------------------------------------------------------------------------

local device = nil

--------------------------------------------------------------------------------

function test_arguments()
    local spi = nil

    ptest()

    -- Invalid mode
    passert_periphery_error("invalid mode", function () spi = SPI(device, 4, 1e6) end, "SPI_ERROR_ARG")
    -- Invalid bit order
    passert_periphery_error("invalid bit order", function () spi = SPI{device=device, mode=3, max_speed=1e6, bit_order="blah"} end, "SPI_ERROR_ARG")
end

function test_open_config_close()
    local spi = nil

    ptest()

    -- Normal open
    passert_periphery_success("spi open", function () spi = SPI(device, 1, 100000) end)

    -- Confirm fd, bit_order="msb", bits_per_word=8
    passert("fd > 0", spi.fd > 0)
    passert("mode is 1", spi.mode == 1)
    passert("max speed is 100000", spi.max_speed == 100000)
    passert("default bit_order is msb", spi.bit_order == "msb")
    passert("default bits_per_word is 8", spi.bits_per_word == 8)
    io.write(string.format("spi: %s\n", spi:__tostring()))

    -- Not going to try different bit order or bits per word, because not all
    -- SPI controllers support them

    -- Try modes 1,2,3,0
    passert_periphery_success("spi set mode 1", function () spi.mode = 1 end)
    passert("spi mode is 1", spi.mode == 1)
    passert_periphery_success("spi set mode 2", function () spi.mode = 2 end)
    passert("spi mode is 2", spi.mode == 2)
    passert_periphery_success("spi set mode 3", function () spi.mode = 3 end)
    passert("spi mode is 3", spi.mode == 3)
    passert_periphery_success("spi set mode 0", function () spi.mode = 0 end)
    passert("spi mode is 0", spi.mode == 0)

    -- Try max speeds 100KHz, 500KHz, 1MHz
    passert_periphery_success("spi set max speed 100KHz", function () spi.max_speed = 100000 end)
    passert("spi max speed is 100KHz", spi.max_speed == 100000)
    passert_periphery_success("spi set max speed 500KHz", function () spi.max_speed = 500000 end)
    passert("spi max speed is 500KHz", spi.max_speed == 500000)
    passert_periphery_success("spi set max speed 1MHz", function () spi.max_speed = 1000000 end)
    passert("spi max speed is 1MHz", spi.max_speed == 1000000)

    passert_periphery_success("spi close", function () spi:close() end)

    -- Try table open
    passert_periphery_success("spi table open", function () spi = SPI{["device"]=device, mode=3, max_speed=500000, bit_order="msb", bits_per_word=8, extra_flags=0} end)
    passert("fd > 0", spi.fd > 0)
    passert("mode is 3", spi.mode == 3)
    passert("max speed is 500000", spi.max_speed == 500000)
    passert("bit_order is msb", spi.bit_order == "msb")
    passert("bits_per_word is 8", spi.bits_per_word == 8)
    passert_periphery_success("spi close", function () spi:close() end)
end

function test_loopback()
    local spi = nil
    local buf_in = {}
    local buf_out = {}

    ptest()

    passert_periphery_success("spi open", function () spi = SPI(device, 0, 100000) end)

    -- Generate sequential bytes as table
    for i = 0, 31 do
        buf_in[i + 1] = i
    end

    -- Transfer table
    passert_periphery_success("spi transfer table", function () buf_out = spi:transfer(buf_in) end)

    -- Verify bytes
    for i = 0, 31 do
        if buf_out[i + 1] ~= i then
            pfail(string.format("mismatch on index %d. expected 0x%02x, got 0x%02x", i, i, buf_out[i]))
            os.exit(1)
        end
    end

    -- Generate sequential bytes as string
    buf_in = ""
    for i = 0, 31 do
        buf_in = buf_in .. string.char(i)
    end

    -- Transfer string
    passert_periphery_success("spi transfer string", function () buf_out = spi:transfer(buf_in) end)

    -- Verify bytes
    passert("verify bytes", buf_out == buf_in)

    -- Generate two messages with deselect, one with table data, one with string data
    msgs = {{deselect=true}, {""}}
    for i = 0, 31 do
        msgs[1][i + 1] = i
        msgs[2][1] = msgs[2][1] .. string.char(i)
    end

    -- Transfer messages
    passert_periphery_success("spi transfer advanced with deselect", function () spi:transfer_advanced(msgs) end)

    -- Verify bytes
    for i = 0, 31 do
        if msgs[1][i + 1] ~= i then
            pfail(string.format("mismatch on index %d. expected 0x%02x, got 0x%02x", i, i, msgs[1][i + 1]))
            os.exit(1)
        end
    end

    -- Verify bytes
    passert("verify bytes", msgs[2][1] == buf_in)

    passert_periphery_success("spi close", function () spi:close() end)
end

function test_interactive()
    local spi = nil
    local buf = nil

    ptest()

    passert_periphery_success("spi open", function () spi = SPI(device, 0, 100000) end)

    print("Starting interactive test. Get out your logic analyzer, buddy!")
    print("Press enter to continue...")
    io.read()

    -- Check tostring
    io.write(string.format("SPI description: %s\n", spi:__tostring()))
    print("SPI description looks OK? y/n")
    passert("interactive success", io.read() == "y")

    -- Mode 0 transfer
    print("Press enter to start transfer...")
    io.read()
    passert_periphery_success("spi transfer", function () spi:transfer({0x55, 0xaa, 0x0f, 0xf0}) end)
    print("SPI data 0x55, 0xaa, 0x0f, 0xf0")
    print("SPI transfer speed <= 100KHz, mode 0 occurred? y/n")
    passert("interactive success", io.read() == "y")

    -- Mode 1 transfer
    passert_periphery_success("spi set mode 1", function () spi.mode = 1 end)
    print("Press enter to start transfer...")
    io.read()
    passert_periphery_success("spi transfer", function () spi:transfer({0x55, 0xaa, 0x0f, 0xf0}) end)
    print("SPI data 0x55, 0xaa, 0x0f, 0xf0")
    print("SPI transfer speed <= 100KHz, mode 1 occurred? y/n")
    passert("interactive success", io.read() == "y")

    -- Mode 2 transfer
    passert_periphery_success("spi set mode 2", function () spi.mode = 2 end)
    print("Press enter to start transfer...")
    io.read()
    passert_periphery_success("spi transfer", function () spi:transfer({0x55, 0xaa, 0x0f, 0xf0}) end)
    print("SPI data 0x55, 0xaa, 0x0f, 0xf0")
    print("SPI transfer speed <= 100KHz, mode 2 occurred? y/n")
    passert("interactive success", io.read() == "y")

    -- Mode 3 transfer
    passert_periphery_success("spi set mode 3", function () spi.mode = 3 end)
    print("Press enter to start transfer...")
    io.read()
    passert_periphery_success("spi transfer", function () spi:transfer({0x55, 0xaa, 0x0f, 0xf0}) end)
    print("SPI data 0x55, 0xaa, 0x0f, 0xf0")
    print("SPI transfer speed <= 100KHz, mode 3 occurred? y/n")
    passert("interactive success", io.read() == "y")

    passert_periphery_success("spi set mode 0", function () spi.mode = 0 end)

    -- Multiple transfer
    print("Press enter to start transfer...")
    io.read()
    passert_periphery_success("spi transfer advanced", function () spi:transfer_advanced({{0x55, 0xaa, 0x0f, 0xf0, deselect = true}, {"\x55\xaa\x0f\xf0"}, {0x55, 0xaa, 0x0f, 0xf0}}) end)
    print("SPI data 0x55, 0xaa, 0x0f, 0xf0")
    print("SPI transfer speed <= 100KHz, mode 3 occurred? y/n")
    print("SPI transfer of three messages, with deselect after first message occurred? y/n")
    passert("interactive success", io.read() == "y")

    -- 500KHz transfer
    passert_periphery_success("spi set max_speed 500000", function () spi.max_speed = 500000 end)
    print("Press enter to start transfer...")
    io.read()
    passert_periphery_success("spi transfer", function () spi:transfer({0x55, 0xaa, 0x0f, 0xf0}) end)
    print("SPI data 0x55, 0xaa, 0x0f, 0xf0")
    print("SPI transfer speed <= 500KHz, mode 0 occurred? y/n")
    passert("interactive success", io.read() == "y")

    -- 1MHz transfer
    passert_periphery_success("spi set max_speed 1000000", function () spi.max_speed = 1000000 end)
    print("Press enter to start transfer...")
    io.read()
    passert_periphery_success("spi transfer", function () spi:transfer({0x55, 0xaa, 0x0f, 0xf0}) end)
    print("SPI data 0x55, 0xaa, 0x0f, 0xf0")
    print("SPI transfer speed <= 1MHz, mode 0 occurred? y/n")
    passert("interactive success", io.read() == "y")

    passert_periphery_success("spi close", function () spi:close() end)
end

if #arg < 1 then
    io.stderr:write(string.format("Usage: lua %s <SPI device>\n\n", arg[0]))
    io.stderr:write("[1/4] Arguments test: No requirements.\n")
    io.stderr:write("[2/4] Open/close test: SPI device should be real.\n")
    io.stderr:write("[3/4] Loopback test: SPI MISO and MOSI should be connected with a wire.\n")
    io.stderr:write("[4/4] Interactive test: SPI MOSI, CLK, CS should be observed with an oscilloscope or logic analyzer.\n\n")
    io.stderr:write("Hint: for Raspberry Pi 3, enable SPI0 with:\n")
    io.stderr:write("   $ echo \"dtparam=spi=on\" | sudo tee -a /boot/firmware/config.txt\n")
    io.stderr:write("   $ sudo reboot\n")
    io.stderr:write("Use pins SPI0 MOSI (header pin 19), SPI0 MISO (header pin 21), SPI0 SCLK (header pin 23),\n")
    io.stderr:write("connect a loopback between MOSI and MISO, and run this test with:\n")
    io.stderr:write(string.format("    lua %s /dev/spidev0.0\n\n", arg[0]))
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

