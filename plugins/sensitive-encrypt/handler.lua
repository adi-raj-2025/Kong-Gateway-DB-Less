local SensitiveEncryptHandler = {
    VERSION = "1.0.0",
    PRIORITY = 800,
}

local function encode_base64(data)
    local encoded = ngx.encode_base64(data)
    encoded = encoded:gsub('+', '-'):gsub('/', '_'):gsub('=', '')
    return encoded
end

local function encrypt_sensitive_data(value)
    if type(value) ~= "string" then
        return value
    end
    
    local patterns = {
        -- Patterns for key-value pairs (like in query strings or form data)
        { pattern = 'password%s*=%s*([^%s,.;!?]+)', replace_with_quotes = false },
        { pattern = 'pwd%s*=%s*([^%s,.;!?]+)', replace_with_quotes = false },
        { pattern = 'username%s*=%s*([^%s,.;!?]+)', replace_with_quotes = false },
        { pattern = 'user%s*=%s*([^%s,.;!?]+)', replace_with_quotes = false },
        { pattern = 'msisdn%s*=%s*([^%s,.;!?]+)', replace_with_quotes = false },
        { pattern = 'phone%s*=%s*([^%s,.;!?]+)', replace_with_quotes = false },
        { pattern = 'email%s*=%s*([^%s,.;!?]+)', replace_with_quotes = false },
        
        -- Patterns for standalone values (direct field values)
        { pattern = '^[%w%.%%%+%-]+@[%w%.%-]+%.[%w]+$', is_standalone = true }, -- email regex
        { pattern = '^%+?[%d%-%s%(%)]+$', min_length = 8, is_standalone = true }, -- phone regex
    }

    local modified = value
    
    -- First, handle key-value patterns in strings
    for _, p in ipairs(patterns) do
        if not p.is_standalone then
            local matches = {}
            -- Find all matches
            for match in modified:gmatch(p.pattern) do
                table.insert(matches, match)
            end
            
            -- Replace each match
            for _, match_value in ipairs(matches) do
                local encoded = encode_base64(match_value)
                if p.replace_with_quotes then
                    modified = modified:gsub(
                        '([\'"])' .. match_value:gsub('([^%w])', '%%%1') .. '([\'"])',
                        '%1' .. encoded .. '%2'
                    )
                else
                    modified = modified:gsub(
                        match_value:gsub('([^%w])', '%%%1'),
                        encoded
                    )
                end
                kong.log.info("Encrypted sensitive data in pattern: " .. match_value .. " -> " .. encoded)
            end
        end
    end
    
    return modified
end

-- Recursive function to traverse and encrypt JSON data
local function traverse_and_encrypt(data, parent_key)
    if type(data) == "table" then
        for key, value in pairs(data) do
            if type(value) == "string" then
                -- Check if this is a sensitive field based on key name
                local sensitive_keys = {
                    password = true, pwd = true, passwd = true,
                    username = true, user = true, 
                    email = true, mail = true,
                    phone = true, telephone = true, mobile = true, msisdn = true,
                    secret = true, token = true, api_key = true, apikey = true,
                    credit_card = true, card_number = true, cvv = true,
                    ssn = true, social_security = true
                }
                
                local key_lower = tostring(key):lower()
                
                if sensitive_keys[key_lower] then
                    local original_value = value
                    data[key] = encode_base64(value)
                    kong.log.info("Encrypted sensitive field '" .. tostring(key) .. "': " .. original_value .. " -> " .. data[key])
                else
                    -- Also check if the value itself looks like sensitive data
                    local encrypted_value = encrypt_sensitive_data(value)
                    if encrypted_value ~= value then
                        data[key] = encrypted_value
                    end
                end
            elseif type(value) == "table" then
                traverse_and_encrypt(value, key)
            end
        end
    elseif type(data) == "string" then
        return encrypt_sensitive_data(data)
    end
    
    return data
end

function SensitiveEncryptHandler:access(conf)
    kong.service.request.enable_buffering()
    
    local headers = kong.request.get_headers()
    local content_type = headers["content-type"]
    
    kong.log.info("Checking request for sensitive data...")
    
    if content_type and string.find(content_type:lower(), "application/json") then
        local raw_body = kong.request.get_raw_body()
        if raw_body and #raw_body > 0 then
            kong.log.info("Original raw body: " .. raw_body)
            
            local cjson = require("cjson")
            local success, data = pcall(cjson.decode, raw_body)
            if success and data then
                kong.log.info("Successfully parsed JSON, traversing for sensitive data...")
                
                -- Store original for comparison
                local original_data = cjson.encode(data)
                
                -- Traverse and encrypt the entire JSON structure
                traverse_and_encrypt(data)
                
                local encode_success, new_body = pcall(cjson.encode, data)
                if encode_success then
                    if new_body ~= original_data then
                        kong.log.info("New body: " .. new_body)
                        kong.log.info("Original body length: " .. #raw_body)
                        kong.log.info("New body length: " .. #new_body)
                        
                        kong.service.request.set_raw_body(new_body)
                        kong.log.info("Sensitive data encrypted in JSON payload")
                    else
                        kong.log.info("No sensitive data found to encrypt")
                    end
                else
                    kong.log.err("Failed to encode modified JSON")
                end
            else
                kong.log.err("Failed to parse JSON. Success: " .. tostring(success))
                if not success then
                    kong.log.err("JSON parse error: " .. tostring(data))
                end
            end
        else
            kong.log.info("No request body found")
        end
    else
        kong.log.info("Content-Type is not application/json: " .. (content_type or "nil"))
    end
end

return SensitiveEncryptHandler