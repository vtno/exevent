defmodule Exevent.FileStreamerTest do
  use ExUnit.Case

  @test_log_file "exevent_test.log"
  setup do
    on_exit(fn -> File.rm(@test_log_file) end)
  end

  test "#file_stream should read from file and return the exact number of line as lines_to_wait_for" do
    spawn(fn -> loop_write(@test_log_file, 20) end)
    {:ok, lines} = Exevent.FileStreamer.file_stream(@test_log_file, 20)
    assert Enum.count(lines) == 20
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
