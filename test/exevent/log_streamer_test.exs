defmodule Exevent.LogStreamerTest do
  use ExUnit.Case

  @test_log_file "test.log"

  setup do
    on_exit(fn -> File.rm(@test_log_file) end)
  end

  test "readlines should read with configurable offset" do
    File.write!(@test_log_file, random_line(30), [:append, :utf8])
    File.write!(@test_log_file, random_line(30), [:append, :utf8])
    File.write!(@test_log_file, random_line(30), [:append, :utf8])
    assert Enum.count(readlines(@test_log_file)) == 3

    File.write!(@test_log_file, random_line(30), [:append, :utf8])
    File.write!(@test_log_file, random_line(30), [:append, :utf8])
    assert Enum.count(readlines(@test_log_file, 3)) == 2

    File.write!(@test_log_file, random_line(30), [:append, :utf8])
    File.write!(@test_log_file, random_line(30), [:append, :utf8])
    File.write!(@test_log_file, random_line(30), [:append, :utf8])
    File.write!(@test_log_file, random_line(30), [:append, :utf8])
    File.write!(@test_log_file, random_line(30), [:append, :utf8])
    assert Enum.count(readlines(@test_log_file, 5)) == 5
  end

  test "readline should work with file that is being written by other process" do
    parent_pid = self()
    lines_to_process = 20
    spawn(fn -> loop_write(@test_log_file, lines_to_process) end)
    spawn(fn ->
      loop_read(parent_pid, @test_log_file, lines_to_process)
    end)
    receive do
      {:ok, lines} ->
        assert Enum.count(lines) == lines_to_process
    after
      1_000 * lines_to_process ->
        assert false
    end
    lines = readlines(@test_log_file)
    assert Enum.count(lines) == lines_to_process
  end

  defp loop_write(filename, lines_to_write) do
    for _ <- 1..lines_to_write do
      File.write!(filename, random_line(30), [:append, :utf8])
      Process.sleep(Enum.random([100, 500, 1000]))
    end
  end

  defp loop_read(parent_pid, filename, line_to_wait_for, lines \\ [], processed_line \\ 0) do
    new_lines = readlines(filename, processed_line)
    total_lines = Enum.concat(lines, new_lines)
    case Enum.count(total_lines) do
      ^line_to_wait_for ->
        send(parent_pid, {:ok, total_lines})
      _ ->
        Process.sleep(300)
        loop_read(parent_pid, filename, line_to_wait_for, total_lines, Enum.count(total_lines))
    end
  end

  defp readlines(filename, processed_line \\ 0) do
    filename
      |> File.stream!()
      |> Stream.drop(processed_line)
      |> Enum.to_list()
  end

  defp random_line(length) do
    (:crypto.strong_rand_bytes(length) |> Base.encode64 |> binary_part(0, length)) <> "\n"
  end
end
