defmodule Exevent.Plug do
  import Plug.Conn
  use Plug.Router

  plug(Plug.Logger)
  plug(:match)
  plug(:dispatch)

  def init(opts) do
    streaming_dir = Application.fetch_env!(:exevent, :streaming_dir)
    :ets.new(:app, [:named_table, read_concurrency: true])
    :ets.insert(:app, {:html_content, File.read!("index.html")})
    :ets.insert(:app, {:streaming_dir, streaming_dir})
    opts
  end

  get "/" do
    case :ets.lookup(:app, :html_content) do
      [{:html_content, content}] ->
        conn
        |> send_resp(200, content)

      _ ->
        "Not found"
    end
  end

  get "/stream/:filename" do
    parent_pid = self()

    case :ets.lookup(:app, :streaming_dir) do
      [{:streaming_dir, streaming_dir}] ->
        chunked_conn =
          conn
          |> put_resp_header("Content-Type", "text/event-stream")
          |> put_resp_header("Cache-Control", "no-cache")
          |> put_resp_header("Transfer-Encoding", "chunked")
          |> send_chunked(200)

        spawn(fn ->
          loop_read(parent_pid, chunked_conn, Path.join([streaming_dir, filename]), 10)
        end)

        # wait for any message from the read
        receive do
          :done ->
            IO.puts("Done reading")
            chunked_conn
        end

        chunked_conn

      _ ->
        conn |> send_resp(500, "Internal server error")
    end
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
      Exevent.ChunkerBehaviour.send_lines(conn, new_lines)
      send(parent_pid, :done)
    else
      Process.sleep(300)

      if Enum.count(new_lines) > 0 do
        case Exevent.ChunkerBehaviour.send_lines(conn, new_lines) do
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

  defp readlines(filename, processed_lines) do
    filename
    |> File.stream!()
    |> Stream.drop(processed_lines)
    |> Enum.to_list()
  end
end
