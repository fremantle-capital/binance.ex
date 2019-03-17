defmodule Binance.Rest.HTTPClientTest do
  use ExUnit.Case
  use ExVCR.Mock, adapter: ExVCR.Adapter.Hackney

  setup_all do
    HTTPoison.start()
  end

  test "get_binance returns an error tuple and passes through the binance error when unhandled" do
    use_cassette "unhandled_error_code" do
      assert {:error, {:binance_error, reason}} =
               Binance.Rest.HTTPClient.get_binance(
                 "/api/v1/time",
                 %{},
                 "invalid-secret-key",
                 "invalid-api-key"
               )

      assert %{"code" => _, "msg" => _} = reason
    end
  end
end
