-- Draait alle testscenario's, elk in een eigen, schone Lua-omgeving.
-- Gebruik (vanuit de repo):  lua5.1 tests/run.lua
local lua = os.getenv("LUA") or "lua5.1"
local files = {}
local p = io.popen('ls tests/scenarios/*.lua')
for f in p:lines() do files[#files + 1] = f end
p:close()
local failed = 0
for _, f in ipairs(files) do
  local head = io.open(f):read("*l") or ""
  local flavors = { "" }
  local list = head:match("^%-%- flavors: (.+)$")
  if list then flavors = {}; for fl in list:gmatch("%S+") do flavors[#flavors + 1] = fl end end
  for _, fl in ipairs(flavors) do
    local out = io.popen(lua .. " tests/run_one.lua " .. f .. " " .. fl .. " 2>&1")
    local text = out:read("*a")
    local ok = out:close()
    local bad = text:find("MISLUKT") or text:find("stack traceback")
    local label = f:match("([^/]+)%.lua$") .. (fl ~= "" and (" [" .. fl .. "]") or "")
    local n = select(2, text:gsub("\nok ", "")) + (text:match("^ok ") and 1 or 0)
    if bad then
      failed = failed + 1
      print("FAIL " .. label .. "\n" .. text)
    else
      print(("ok   %-40s %d checks"):format(label, n))
    end
  end
end
if failed > 0 then print(failed .. " scenario(s) failed"); os.exit(1) end
print("all scenarios passed")
