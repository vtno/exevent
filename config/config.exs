import Config

config :plug, :validate_header_keys_during_test, false
config :exevent, :streaming_dir, "log"

Application.put_env(:exevent, :chunker, Exevent.ChunkerImpl)
