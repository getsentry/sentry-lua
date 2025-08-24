-- example calling function:
local ok, status, body, headers = net.http_post(
  "https://httpbin.org/post",
  '{"hello":"world"}',
  {["Content-Type"]="application/json"},
  { timeout_ms = 5000 }
)

if not ok then
  print("POST failed:", status)
else
  print("Status:", status)
  print("Body:", body)
end