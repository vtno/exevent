defmodule Exevent.ChunkerImpl do
  @behaviour Exevent.ChunkerBehaviour

  def send_lines(conn, lines) do
    Plug.Conn.chunk(conn, to_event_stream(lines))
  end

  defp to_event_stream(lines) do
    Enum.map(lines, &("data: " <> &1 <> "\n"))
  end
end
