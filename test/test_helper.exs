ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(TrySyndicate.Repo, :manual)
Mox.defmock(TrySyndicate.MockSessionManager, for: TrySyndicate.SessionManager)
Application.put_env(:try_syndicate, :session_manager, TrySyndicate.MockSessionManager)
