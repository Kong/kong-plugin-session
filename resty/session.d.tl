local type TODO = any

local record resty_session
  enum Samesite
    "Lax"
    "Strict"
    'None'
    'off'
  end

  enum OnOff
    "on"
    "off"
  end

  enum SessionStrategies
    "default"
    "regenerate"
  end

  record RestySessionOptions
    name: string
    secret: string
    storage: any
    strategy: SessionStrategies
    cookie: TODO -- can't type this as record for some reason
    -- record cookie
      -- lifetime: number
      -- idletime: number
      -- path: string
      -- domain: string
      -- samesite: resty_session.Samesite
      -- httponly: resty_session.OnOff
      -- secure: resty_session.OnOff
      -- samesite: string
      -- httponly: string
      -- secure: string
      -- renew: string
      -- discard: string
    -- end
  end

  record Session<Data>
    data: Data
    present: boolean
    save: function(Session)
    destroy: function(Session)
    start: function(Session)
  end

  open: function<T>(opts: resty_session.RestySessionOptions): Session<T>
end

return resty_session
