# Exevent

A service which stream text from a file and emit Server Sent Event (SSE) to the client when requested.

# APIs

## GET /stream/:filename
The system looks up a file with the given filename and starts streaming the content to the client. The client can then listen to the stream and receive the content as it is being streamed.

For web clients, the `EventSource` API can be used to listen to the stream.
For curl, the `curl -N` option can be used to listen to the stream.

## Development

Run `mix deps.get` to install dependencies and `mix test` to run the test suite. To start a dev server run `iex -S mix`.
