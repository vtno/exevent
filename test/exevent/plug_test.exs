defmodule Exevent.PlugTest do
  use ExUnit.Case
  use Plug.Test

  import Mox

  doctest Exevent.Plug

  setup do
    Exevent.Plug.init([])
    :ok
  end

  setup :set_mox_from_context
  setup :verify_on_exit!

  test "GET / renders page with streaming button" do
    conn = conn(:get, "/")
    conn = Exevent.Plug.call(conn, [])
    assert conn.state == :sent
    assert conn.status == 200
    assert String.contains?(conn.resp_body, "Exevent")
    assert String.contains?(conn.resp_body, "Start Streaming")
  end

  test "GET /streams/:filename live stream the content of the file as chunked response" do
    Agent.start_link(fn -> [] end, name: :test_agent)

    Exevent.ChunkerMock
    |> stub(:send_lines, fn conn, lines ->
      Agent.update(:test_agent, fn state -> state ++ lines end)
      {:ok, conn}
    end)

    {:ok, streaming_dir} = Application.fetch_env(:exevent, :streaming_dir)
    filename = "test.txt"
    filepath = Path.join([streaming_dir, filename])
    File.touch(filepath)
    on_exit(fn -> File.rm(filepath) end)
    spawn(fn -> loop_write(filepath, 10) end)

    conn = conn(:get, "/stream/test.txt")
    conn = Exevent.Plug.call(conn, [])
    assert conn.state == :chunked
    assert conn.status == 200
    assert Plug.Conn.get_resp_header(conn, "Content-Type") == ["text/event-stream"]
    assert Plug.Conn.get_resp_header(conn, "Cache-Control") == ["no-cache"]
    assert Plug.Conn.get_resp_header(conn, "Transfer-Encoding") == ["chunked"]

    wait_lines(self())

    receive do
      {:ok, lines} -> assert Enum.count(lines) == 10
    after
      10_000 -> flunk("Expected :done message")
    end
  end

  defp wait_lines(parent_pid) do
    lines = Agent.get(:test_agent, & &1)

    case Enum.count(lines) do
      10 -> send(parent_pid, {:ok, lines})
      _ -> wait_lines(parent_pid)
    end
  end

  defp loop_write(filename, lines_to_write) do
    for _ <- 1..lines_to_write do
      File.write!(filename, random_line(30), [:append, :utf8])
      Process.sleep(Enum.random([100, 500, 1000]))
    end
  end

  defp random_line(length) do
    (:crypto.strong_rand_bytes(length) |> Base.encode64() |> binary_part(0, length)) <> "\n"
  end
end
