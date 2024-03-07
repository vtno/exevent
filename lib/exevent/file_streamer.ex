defmodule Exevent.FileStreamer do
  def file_stream(parent_pid, filename, lines_to_wait_for) do
    spawn(fn -> loop_read(parent_pid, filename, lines_to_wait_for) end)

    receive do
      {:ok, lines} -> {:ok, lines}
    after
      1_000 * lines_to_wait_for ->
        {:error, "timeout"}
    end
  end

  defp loop_read(parent_pid, filename, lines_to_wait_for, lines \\ [], processed_lines \\ 0) do
    new_lines = readlines(filename, processed_lines)
    total_lines = Enum.concat(lines, new_lines)

    case Enum.count(total_lines) do
      ^lines_to_wait_for ->
        send(parent_pid, {:ok, total_lines})

      _ ->
        Process.sleep(300)
        loop_read(parent_pid, filename, lines_to_wait_for, total_lines, Enum.count(total_lines))
    end
  end

  defp readlines(filename, processed_lines) do
    filename
    |> File.stream!()
    |> Stream.drop(processed_lines)
    |> Enum.to_list()
  end
end
