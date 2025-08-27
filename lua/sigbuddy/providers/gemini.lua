local M = {}

-- HTTP request function (will be overridden by tests)
function M._make_request(url, headers, body)
  -- Use curl for HTTP requests (simple but reliable)
  local curl_cmd = {
    "curl",
    "-s",
    "-X",
    "POST",
    url,
  }

  -- Add headers
  for key, value in pairs(headers) do
    table.insert(curl_cmd, "-H")
    table.insert(curl_cmd, key .. ": " .. value)
  end

  -- Add body (properly escaped)
  table.insert(curl_cmd, "-d")
  table.insert(curl_cmd, "'" .. body:gsub("'", "'\"'\"'") .. "'")

  -- Execute curl
  local handle = io.popen(table.concat(curl_cmd, " "))
  if not handle then
    return { status = 500, body = "Failed to execute curl command" }
  end

  local response_body = handle:read("*a")
  if not response_body then
    handle:close()
    return { status = 500, body = "Failed to read response" }
  end

  local success = handle:close()

  return {
    status = success and 200 or 500,
    body = response_body,
  }
end

function M.get_explanation(function_info, config)
  -- Validate inputs
  assert(function_info, "function_info is required")
  assert(function_info.function_name, "function_info.function_name is required")
  assert(function_info.language, "function_info.language is required")
  assert(config, "config is required")
  assert(config.api_key, "config.api_key is required")
  assert(config.model, "config.model is required")

  -- Build the prompt
  local prompt = string.format(
    "What does `%s` do in %s? Explain it simply in plain English, then show a basic example. If it's not a built-in function, just say 'Not a built-in function.'",
    function_info.function_name,
    function_info.language
  )

  -- Prepare request payload (Gemini API format)
  local payload = {
    contents = {
      {
        parts = {
          {
            text = prompt,
          },
        },
      },
    },
    generationConfig = {
      maxOutputTokens = 200,
      temperature = 0.1,
    },
  }

  -- Prepare headers
  local headers = {
    ["Content-Type"] = "application/json",
  }

  -- Build URL with API key as query parameter (Gemini style)
  local base_url = config.endpoint
    or (
      "https://generativelanguage.googleapis.com/v1beta/models/"
      .. config.model
      .. ":generateContent"
    )
  local url = base_url .. "?key=" .. config.api_key

  -- Make the request
  local success, response = pcall(function()
    return M._make_request(url, headers, vim.fn.json_encode(payload))
  end)

  if not success then
    return {
      status = "error",
      error = "Network error: " .. tostring(response),
    }
  end

  -- Handle HTTP errors
  if response.status ~= 200 then
    local error_msg = "HTTP " .. response.status

    -- Try to parse error details
    local ok, error_data = pcall(vim.fn.json_decode, response.body)
    if ok and error_data.error and error_data.error.message then
      error_msg = error_msg .. ": " .. error_data.error.message
    end

    return {
      status = "error",
      error = error_msg,
    }
  end

  -- Parse response
  local ok, response_data = pcall(vim.fn.json_decode, response.body)
  if not ok then
    return {
      status = "error",
      error = "Failed to parse response JSON",
    }
  end

  -- Extract explanation (Gemini response format)
  if
    response_data.candidates
    and response_data.candidates[1]
    and response_data.candidates[1].content
    and response_data.candidates[1].content.parts
    and response_data.candidates[1].content.parts[1]
    and response_data.candidates[1].content.parts[1].text
  then
    local explanation =
      response_data.candidates[1].content.parts[1].text:gsub("^%s+", ""):gsub("%s+$", "")

    return {
      status = "success",
      explanation = explanation,
    }
  else
    return {
      status = "error",
      error = "Invalid response format",
    }
  end
end

return M
