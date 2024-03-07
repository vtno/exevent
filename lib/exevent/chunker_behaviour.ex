defmodule Exevent.ChunkerBehaviour do
  @callback send_lines(map(), list()) :: {:ok, map()} | {:error, term()} | no_return()

  def send_lines(conn, lines), do: impl().send_lines(conn, lines)

  defp impl, do: Application.get_env(:exevent, :chunker)
end
