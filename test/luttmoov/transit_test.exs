defmodule Luttmoov.TransitTest do
  use Luttmoov.DataCase

  alias Luttmoov.Transit

  @jungfernstieg %{
    "id" => "Master:10950",
    "name" => "Jungfernstieg",
    "city" => "Hamburg",
    "vehicleTypes" => ["U_BAHN", "S_BAHN"],
    "coordinate" => %{"x" => 9.993, "y" => 53.552, "type" => "EPSG_4326"},
    "exists" => true
  }

  @hauptbahnhof %{
    "id" => "Master:9910",
    "name" => "Hauptbahnhof",
    "city" => "Hamburg",
    "vehicleTypes" => ["U_BAHN", "S_BAHN", "R_BAHN"],
    "coordinate" => %{"x" => 10.006, "y" => 53.553, "type" => "EPSG_4326"},
    "exists" => true
  }

  defp stub_stations(entries) do
    Req.Test.stub(Luttmoov.Geofox, fn conn ->
      assert conn.request_path == "/gti/public/listStations"

      Req.Test.json(conn, %{
        "returnCode" => "OK",
        "dataReleaseID" => "1",
        "stations" => entries
      })
    end)
  end

  describe "sync_stations/0" do
    test "stores stations with converted coordinates" do
      stub_stations([@jungfernstieg, @hauptbahnhof])

      assert {:ok, 2} = Transit.sync_stations()

      assert [
               %{id: "Master:10950", name: "Jungfernstieg", city: "Hamburg"} = jungfernstieg,
               %{id: "Master:9910", name: "Hauptbahnhof"}
             ] = Transit.list_stations()

      assert jungfernstieg.lat == 53.552
      assert jungfernstieg.lon == 9.993
      assert jungfernstieg.vehicle_types == ["U_BAHN", "S_BAHN"]
    end

    test "skips removed entries and entries without name or coordinate" do
      stub_stations([
        @jungfernstieg,
        %{@hauptbahnhof | "exists" => false},
        %{@hauptbahnhof | "id" => "Master:1", "coordinate" => nil},
        Map.delete(%{@hauptbahnhof | "id" => "Master:2"}, "name")
      ])

      assert {:ok, 1} = Transit.sync_stations()
      assert [%{id: "Master:10950"}] = Transit.list_stations()
    end

    test "a second sync removes stations that are no longer listed" do
      stub_stations([@jungfernstieg, @hauptbahnhof])
      assert {:ok, 2} = Transit.sync_stations()

      stub_stations([@hauptbahnhof])
      assert {:ok, 1} = Transit.sync_stations()

      assert [%{id: "Master:9910"}] = Transit.list_stations()
    end

    test "keeps existing stations when the API returns none" do
      stub_stations([@jungfernstieg])
      assert {:ok, 1} = Transit.sync_stations()

      stub_stations([])
      assert {:error, :no_stations} = Transit.sync_stations()

      assert [%{id: "Master:10950"}] = Transit.list_stations()
    end

    test "keeps existing stations when the API fails" do
      stub_stations([@jungfernstieg])
      assert {:ok, 1} = Transit.sync_stations()

      Req.Test.stub(Luttmoov.Geofox, fn conn ->
        conn
        |> Plug.Conn.put_status(401)
        |> Req.Test.json(%{"returnCode" => "ERROR_TEXT"})
      end)

      assert {:error, {:http_error, 401, _}} = Transit.sync_stations()
      assert [%{id: "Master:10950"}] = Transit.list_stations()
    end
  end
end
