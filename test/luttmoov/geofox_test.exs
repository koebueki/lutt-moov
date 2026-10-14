defmodule Luttmoov.GeofoxTest do
  use ExUnit.Case, async: true

  alias Luttmoov.Geofox, as: LG

  # doctest Luttmoov.Geofox

  describe "to_latlng/1" do
    test "swaps x/y into [lat, lng]" do
      assert LG.to_latlng(%{"x" => 10.0, "y" => 53.5}) == [53.5, 10.0]
    end
  end

  describe "bbox/2" do
    test "round-trips through to_latlng/1" do
      sw = [53.4, 9.7]
      ne = [53.7, 10.3]
      box = LG.bbox(sw, ne)

      assert LG.to_latlng(box["lowerLeft"]) == sw
      assert LG.to_latlng(box["upperRight"]) == ne
    end
  end

  describe "client/0" do
    test "sends requests through the configured Req.Test stub" do
      Req.Test.stub(LG, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/gti/public/init"
        Req.Test.json(conn, %{"returnCode" => "OK", "dataId" => "test-data"})
      end)

      assert {:ok, %{"dataId" => "test-data"}} = Geofox.init(LG.client())
    end

    test "returns API errors" do
      Req.Test.stub(LG, fn conn ->
        conn
        |> Plug.Conn.put_status(401)
        |> Req.Test.json(%{
          "returnCode" => "ERROR_TEXT",
          "errorDevInfo" => "Authentication failed!"
        })
      end)

      assert {:error, {:http_error, 401, _body}} = Geofox.init(LG.client())
    end
  end
end
