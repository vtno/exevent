defmodule ExeventTest do
  use ExUnit.Case
  doctest Exevent

  test "start_logging logs random message to an IO and return that IO" do
    assert {:ok} = Exevent.start_logging()
  end
end
