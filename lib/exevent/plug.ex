defmodule Exevent.Plug do
  import Plug.Conn

  def init(options) do
    options
  end

  def call(conn, _opts) do
    case conn.path_info do
      ["stream", filename] ->
        File.touch(filename)
        spawn(fn -> loop_write(filename, 10) end)

        chunked_conn =
          conn
          |> put_resp_header("Content-Type", "text/event-stream")
          |> put_resp_header("Cache-Control", "no-cache")
          |> put_resp_header("Transfer-Encoding", "chunked")
          |> send_chunked(200)
          |> loop_read(filename, 10)

        case File.rm!(filename) do
          _ -> chunked_conn
        end

      [] ->
        conn
        |> send_resp(200, "Welcome to Exevent")

      _ ->
        conn
        |> send_resp(404, "Not found")
    end
  end

  defp loop_read(conn, filename, lines_to_wait_for, lines \\ [], processed_lines \\ 0) do
    new_lines = readlines(filename, processed_lines)
    total_lines = Enum.concat(lines, new_lines)

    IO.inspect(conn, label: "conn")
    IO.inspect(new_lines, label: "new_lines")
    IO.inspect(total_lines, label: "total_lines")

    next = fn conn ->
      loop_read(conn, filename, lines_to_wait_for, total_lines, Enum.count(total_lines))
    end

    case Enum.count(total_lines) do
      ^lines_to_wait_for ->
        conn

      _ ->
        if Enum.count(total_lines) >= lines_to_wait_for do
          conn
        else
          Process.sleep(300)
          send_lines(conn, new_lines, next)
        end
    end
  end

  defp send_lines(conn, lines, next) do
    case chunk(conn, to_event_stream(lines)) do
      {:ok, conn} ->
        next.(conn)

      {:error, reason} ->
        IO.inspect(reason)
        conn
    end
  end

  defp readlines(filename, processed_lines) do
    filename
    |> File.stream!()
    |> Stream.drop(processed_lines)
    |> Enum.to_list()
  end

  defp to_event_stream(lines) do
    Enum.map(lines, &("data: " <> &1 <> "\n"))
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
