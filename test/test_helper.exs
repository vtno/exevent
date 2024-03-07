Mox.defmock(Exevent.ChunkerMock, for: Exevent.ChunkerBehaviour)
Application.ensure_all_started(:mox)
Application.put_env(:exevent, :chunker, Exevent.ChunkerMock)
ExUnit.start()
