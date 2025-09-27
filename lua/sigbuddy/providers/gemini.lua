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
      maxOutputTokens = config.max_tokens,
      temperature = config.temperature,
    },
  }

  -- Build URL (no API key in query parameter - using header instead)
  local base_url = config.endpoint
    or (
      "https://generativelanguage.googleapis.com/v1beta/models/"
      .. config.model
      .. ":generateContent"
    )

  -- Use plenary.curl for async request
  local curl = require("plenary.curl")

  curl.post(base_url, {
    body = vim.fn.json_encode(payload),
    headers = {
      ["Content-Type"] = "application/json",
      ["x-goog-api-key"] = config.api_key,
    },
    callback = function(response)
      -- Move all processing to main thread to avoid fast event context issues
      vim.schedule(function()
        local result

        if response.status ~= 200 then
          local error_msg = "Gemini API Error"
          if response.status == 401 then
            error_msg = "Invalid API key. Please check your Gemini API configuration."
          elseif response.status == 429 then
            error_msg = "Rate limit exceeded. Please try again later."
          elseif response.status == 403 then
            error_msg = "API access forbidden. Check your API key permissions."
          else
            error_msg = "Gemini API returned HTTP " .. response.status
          end

          vim.notify("Sigbuddy: " .. error_msg, vim.log.levels.ERROR)
          result = {
            status = "error",
            error = error_msg,
          }
        else
          -- Parse response
          local ok, response_data = pcall(vim.fn.json_decode, response.body)
          if not ok then
            vim.notify("Sigbuddy: Failed to parse Gemini API response", vim.log.levels.ERROR)
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
              local error_msg = "Gemini API Error"
              if response_data.error.message then
                error_msg = error_msg .. ": " .. response_data.error.message
              end
              vim.notify("Sigbuddy: " .. error_msg, vim.log.levels.ERROR)
              result = {
                status = "error",
                error = error_msg,
              }
            else
              vim.notify(
                "Sigbuddy: Received unexpected response format from Gemini API",
                vim.log.levels.ERROR
              )
              result = {
                status = "error",
                error = "Invalid response format from Gemini API",
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
