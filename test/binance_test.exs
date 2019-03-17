defmodule BinanceTest do
  use ExUnit.Case
  use ExVCR.Mock, adapter: ExVCR.Adapter.Hackney
  doctest Binance

  setup_all do
    HTTPoison.start()
  end

  test "ping returns an empty map" do
    use_cassette "ping_ok" do
      assert Binance.ping() == {:ok, %{}}
    end
  end

  test "get_server_time success return an ok, time tuple" do
    use_cassette "get_server_time_ok" do
      assert Binance.get_server_time() == {:ok, 1_521_781_361_467}
    end
  end

  test "get_exchange_info success returns the trading rules and symbol information" do
    use_cassette "get_exchange_info_ok" do
      assert {:ok, %Binance.ExchangeInfo{} = info} = Binance.get_exchange_info()
      assert info.timezone == "UTC"
      assert info.server_time != nil

      assert info.rate_limits == [
               %{"interval" => "MINUTE", "limit" => 1200, "rateLimitType" => "REQUESTS"},
               %{"interval" => "SECOND", "limit" => 10, "rateLimitType" => "ORDERS"},
               %{"interval" => "DAY", "limit" => 100_000, "rateLimitType" => "ORDERS"}
             ]

      assert info.exchange_filters == []
      assert [symbol | _] = info.symbols

      assert symbol == %{
               "baseAsset" => "ETH",
               "baseAssetPrecision" => 8,
               "filters" => [
                 %{
                   "filterType" => "PRICE_FILTER",
                   "maxPrice" => "100000.00000000",
                   "minPrice" => "0.00000100",
                   "tickSize" => "0.00000100"
                 },
                 %{
                   "filterType" => "LOT_SIZE",
                   "maxQty" => "100000.00000000",
                   "minQty" => "0.00100000",
                   "stepSize" => "0.00100000"
                 },
                 %{"filterType" => "MIN_NOTIONAL", "minNotional" => "0.00100000"}
               ],
               "icebergAllowed" => false,
               "orderTypes" => [
                 "LIMIT",
                 "LIMIT_MAKER",
                 "MARKET",
                 "STOP_LOSS_LIMIT",
                 "TAKE_PROFIT_LIMIT"
               ],
               "quoteAsset" => "BTC",
               "quotePrecision" => 8,
               "status" => "TRADING",
               "symbol" => "ETHBTC"
             }
    end
  end

  test "get_all_prices returns a list of prices for every symbol" do
    use_cassette "get_all_prices_ok" do
      assert {:ok, symbol_prices} = Binance.get_all_prices()
      assert [%Binance.SymbolPrice{price: "0.06137000", symbol: "ETHBTC"} | _tail] = symbol_prices
      assert symbol_prices |> Enum.count() == 288
    end
  end

  describe ".get_ticker" do
    test "returns a ticker struct with details for the given symbol" do
      use_cassette "get_ticker_ok" do
        assert {
                 :ok,
                 %Binance.Ticker{
                   ask_price: "0.01876000",
                   bid_price: "0.01875200",
                   close_time: 1_521_826_338_547,
                   count: 30612
                 }
               } = Binance.get_ticker("LTCBTC")
      end
    end

    test "returns an error tuple when the symbol doesn't exist" do
      use_cassette "get_ticker_error" do
        assert Binance.get_ticker("IDONTEXIST") == {:error, :bad_symbol}
      end
    end
  end

  describe ".get_depth" do
    test "returns the bids & asks up to the given depth" do
      use_cassette "get_depth_ok" do
        assert Binance.get_depth("BTCUSDT", 5) == {
                 :ok,
                 %Binance.OrderBook{
                   asks: [
                     ["8400.00000000", "2.04078100", []],
                     ["8405.35000000", "0.50354700", []],
                     ["8406.00000000", "0.32769800", []],
                     ["8406.33000000", "0.00239000", []],
                     ["8406.51000000", "0.03241000", []]
                   ],
                   bids: [
                     ["8393.00000000", "0.20453200", []],
                     ["8392.57000000", "0.02639000", []],
                     ["8392.00000000", "1.40893300", []],
                     ["8390.09000000", "0.07047100", []],
                     ["8388.72000000", "0.04577400", []]
                   ],
                   last_update_id: 113_634_395
                 }
               }
      end
    end

    test "returns an error tuple when the symbol doesn't exist" do
      use_cassette "get_depth_error" do
        assert Binance.get_depth("IDONTEXIST", 1000) == {:error, :bad_symbol}
      end
    end
  end

  [:buy, :sell]
  |> Enum.each(fn side ->
    @side side

    describe ".order_limit_#{side}" do
      test "creates an order with a duration of good til cancel by default" do
        use_cassette "order_limit_#{@side}_good_til_cancel_default_duration_success" do
          assert {:ok, %Binance.OrderResponse{} = response} =
                   apply(Binance, :"order_limit_#{@side}", ["LTCBTC", 0.1, 0.01])

          assert response.client_order_id != nil
          assert response.executed_qty == "0.00000000"
          assert response.order_id != nil
          assert response.orig_qty != nil
          assert response.price != nil
          assert response.side == @side |> Atom.to_string() |> String.upcase()
          assert response.status == "NEW"
          assert response.symbol != nil
          assert response.time_in_force == "GTC"
          assert response.transact_time != nil
          assert response.type == "LIMIT"
        end
      end

      test "can create an order with a fill or kill duration" do
        use_cassette "order_limit_#{@side}_fill_or_kill_success" do
          assert {:ok, %Binance.OrderResponse{} = response} =
                   apply(Binance, :"order_limit_#{@side}", ["LTCBTC", 0.1, 0.01, "FOK"])

          assert response.client_order_id != nil
          assert response.executed_qty == "0.00000000"
          assert response.order_id != nil
          assert response.orig_qty != nil
          assert response.price != nil
          assert response.side == @side |> Atom.to_string() |> String.upcase()
          assert response.status == "EXPIRED"
          assert response.symbol != nil
          assert response.time_in_force == "FOK"
          assert response.transact_time != nil
          assert response.type == "LIMIT"
        end
      end

      test "can create an order with am immediate or cancel duration" do
        use_cassette "order_limit_#{@side}_immediate_or_cancel_success" do
          assert {:ok, %Binance.OrderResponse{} = response} =
                   apply(Binance, :"order_limit_#{@side}", ["LTCBTC", 0.1, 0.01, "IOC"])

          assert response.client_order_id != nil
          assert response.executed_qty == "0.00000000"
          assert response.order_id != nil
          assert response.orig_qty != nil
          assert response.price != nil
          assert response.side == @side |> Atom.to_string() |> String.upcase()
          assert response.status == "EXPIRED"
          assert response.symbol != nil
          assert response.time_in_force == "IOC"
          assert response.transact_time != nil
          assert response.type == "LIMIT"
        end
      end

      test "returns an insufficient balance error tuple" do
        use_cassette "order_limit_#{@side}_error_insufficient_balance" do
          assert {:error, reason} =
                   apply(Binance, :"order_limit_#{@side}", ["LTCBTC", 10_000, 0.001, "FOK"])

          assert reason == %Binance.InsufficientBalanceError{
                   reason: %{
                     "code" => -2010,
                     "msg" => "Account has insufficient balance for requested action."
                   }
                 }
        end
      end
    end
  end)
end
