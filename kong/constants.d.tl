local type UUID = string

local record constants
  record HEADERS
    CONSUMER_ID: UUID
    CONSUMER_CUSTOM_ID: UUID
    CONSUMER_USERNAME: string
    AUTHENTICATED_GROUPS: string
    ANONYMOUS: string
    CREDENTIAL_IDENTIFIER: string
  end
end

return constants
