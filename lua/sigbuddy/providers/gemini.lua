local M = {}

function M.get_explanation(function_info, config, callback)
  -- Validate inputs
  assert(function_info, "function_info is required")
  assert(function_info.function_name, "function_info.function_name is required")
  assert(function_info.language, "function_info.language is required")
  assert(config, "config is required")
  assert(config.api_key, "config.api_key is required")
  assert(config.model, "config.model is required")

  -- Build the prompt
  local prompt = string.format(
    "What does `%s` do in %s? Explain it simply in plain English, no more than 3 sentences then show a basic example. If it's not a built-in function, just say 'Not a built-in function.'",
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

  -- Build URL with API key as query parameter (Gemini style)
  local base_url = config.endpoint
    or (
      "https://generativelanguage.googleapis.com/v1beta/models/"
      .. config.model
      .. ":generateContent"
    )
  local url = base_url .. "?key=" .. config.api_key

  -- Use plenary.curl for async request
  local curl = require("plenary.curl")

  curl.post(url, {
    body = vim.fn.json_encode(payload),
    headers = {
      ["Content-Type"] = "application/json",
    },
    callback = function(response)
      -- Move all processing to main thread to avoid fast event context issues
      vim.schedule(function()
        local result

        if response.status ~= 200 then
          result = {
            status = "error",
            error = "HTTP " .. response.status .. ": " .. (response.body or "Unknown error"),
          }
        else
          -- Parse response
          local ok, response_data = pcall(vim.fn.json_decode, response.body)
          if not ok then
            result = {
              status = "error",
              error = "Failed to parse response JSON",
            }
          else
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

              result = {
                status = "success",
                explanation = explanation,
              }
            elseif response_data.error then
              -- Handle API errors
              local error_msg = "API Error"
              if response_data.error.message then
                error_msg = error_msg .. ": " .. response_data.error.message
              end
              result = {
                status = "error",
                error = error_msg,
              }
            else
              result = {
                status = "error",
                error = "Invalid response format",
              }
            end
          end
        end

        -- Call callback
        if callback then
          callback(result)
        end
      end)
    end,
  })
end

return M
