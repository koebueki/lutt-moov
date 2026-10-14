defmodule Mix.Tasks.Transit.SyncTest do
  use Luttmoov.DataCase

  setup do
    Mix.shell(Mix.Shell.Process)
    on_exit(fn -> Mix.shell(Mix.Shell.IO) end)
  end

  defp stub_stations(entries) do
    Req.Test.stub(Luttmoov.Geofox, fn conn ->
      Req.Test.json(conn, %{"returnCode" => "OK", "stations" => entries})
    end)
  end

  test "syncs stations and reports the count" do
    stub_stations([
      %{
        "id" => "Master:10950",
        "name" => "Jungfernstieg",
        "coordinate" => %{"x" => 9.993, "y" => 53.552},
        "exists" => true
      }
    ])

    Mix.Tasks.Transit.Sync.run([])

    assert_received {:mix_shell, :info, ["Synced 1 stations."]}
    assert [%{id: "Master:10950"}] = Luttmoov.Transit.list_stations()
  end

  test "raises when the sync fails" do
    stub_stations([])

    assert_raise Mix.Error, ~r/Station sync failed: :no_stations/, fn ->
      Mix.Tasks.Transit.Sync.run([])
    end
  end
end
