defmodule Binance.Rest.HTTPClientTest do
  use ExUnit.Case
  use ExVCR.Mock, adapter: ExVCR.Adapter.Hackney
  import Mock

  setup_all do
    HTTPoison.start()
  end

  test ".get_binance returns an error tuple and passes through the binance error when unhandled" do
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

  test ".get_binance bubbles other errors" do
    with_mock HTTPoison,
      get: fn _url, _headers -> {:error, %HTTPoison.Error{reason: :timeout}} end do
      assert Binance.Rest.HTTPClient.get_binance(
               "/api/v1/time",
               %{},
               "invalid-secret-key",
               "invalid-api-key"
             ) == {:error, :timeout}
    end
  end
end
