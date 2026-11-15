-- Eén scenario: nagebootste WoW-API laden, dan het scenario.
ADDON_DIR = "."
FLAVOR = arg[2] ~= "" and arg[2] or nil
dofile("tests/mock.lua")
dofile(arg[1])
