import Config

config :plug, :validate_header_keys_during_test, false

Application.put_env(:exevent, :chunker, Exevent.ChunkerImpl)
