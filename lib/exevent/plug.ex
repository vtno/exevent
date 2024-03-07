defmodule Exevent.Plug do
  import Plug.Conn
  use Plug.Router

  plug(Plug.Logger)
  plug(:match)
  plug(:dispatch)

  def init(opts) do
    :ets.new(:index_html, [:named_table, read_concurrency: true])
    :ets.insert(:index_html, {:content, File.read!("index.html")})
    opts
  end

  get "/" do
    case :ets.lookup(:index_html, :content) do
      [{:content, content}] ->
        conn
        |> send_resp(200, content)

      _ ->
        "Not found"
    end
  end

  get "/stream/:filename" do
    case File.rm(filename) do
      :ok -> IO.puts("File removed")
      _ -> IO.puts("File not removed")
    end

    File.touch(filename)
    spawn(fn -> loop_write(filename, 10) end)

    chunked_conn =
      conn
      |> put_resp_header("Content-Type", "text/event-stream")
      |> put_resp_header("Cache-Control", "no-cache")
      |> put_resp_header("Transfer-Encoding", "chunked")
      |> send_chunked(200)

    parent_pid = self()

    spawn(fn ->
      loop_read(parent_pid, chunked_conn, filename, 10)
    end)

    # wait for any message from the read
    receive do
      :done ->
        IO.puts("Done reading")
        chunked_conn
    end

    chunked_conn
  end

  match _ do
    conn
    |> send_resp(404, "Not found")
  end

  defp loop_read(parent_pid, conn, filename, lines_to_wait_for, lines \\ [], processed_lines \\ 0) do
    new_lines = readlines(filename, processed_lines)
    total_lines = Enum.concat(lines, new_lines)

    IO.inspect(Enum.count(total_lines), label: "Total lines")
    IO.inspect(new_lines, label: "New lines")

    if Enum.count(total_lines) >= lines_to_wait_for do
      send_lines(conn, new_lines)
      send(parent_pid, :done)
    else
      Process.sleep(300)

      if Enum.count(new_lines) > 0 do
        case send_lines(conn, new_lines) do
          {:ok, conn} ->
            loop_read(
              parent_pid,
              conn,
              filename,
              lines_to_wait_for,
              total_lines,
              processed_lines + Enum.count(new_lines)
            )

          {:error, reason} ->
            IO.inspect(reason, label: "Error reason")
            send(parent_pid, :done)
        end
      else
        loop_read(
          parent_pid,
          conn,
          filename,
          lines_to_wait_for,
          total_lines,
          processed_lines
        )
      end
    end
  end

  defp send_lines(conn, lines) do
    chunk(conn, to_event_stream(lines))
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
