return {
  skip_compat53 = true,
  -- Execute the equivalent of `require('modulename')` before executing the script.
  preload_modules = {
    "types.index",
    "types.resty",
    "types.kong"
	}
}
