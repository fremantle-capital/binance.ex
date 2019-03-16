defmodule Binance.Rest.HTTPClient do
  @type header :: {key :: String.t(), value :: String.t()}
  @type config_error :: {:config_missing, String.t()}
  @type http_error :: {:http_error, any}
  @type poison_decode_error :: {:poison_decode_error, Poison.ParseError.t()}

  @endpoint "https://api.binance.com"
  @receive_window 5000

  @spec get_binance(String.t(), [header]) ::
          {:ok, any} | {:error, config_error | http_error | poison_decode_error}
  def get_binance(url, headers \\ []) do
    "#{@endpoint}#{url}"
    |> HTTPoison.get(headers)
    |> parse_get_response
  end

  def get_binance(_url, _params, nil, nil),
    do: {:error, {:config_missing, "Secret and API key missing"}}

  def get_binance(_url, _params, nil, _api_key),
    do: {:error, {:config_missing, "Secret key missing"}}

  def get_binance(_url, _params, _secret_key, nil),
    do: {:error, {:config_missing, "API key missing"}}

  def get_binance(url, params, secret_key, api_key) do
    headers = [{"X-MBX-APIKEY", api_key}]
    ts = DateTime.utc_now() |> DateTime.to_unix(:millisecond)

    params =
      Map.merge(params, %{
        timestamp: ts,
        recvWindow: @receive_window
      })

    argument_string = URI.encode_query(params)
    signature = sign(secret_key, argument_string)

    get_binance("#{url}?#{argument_string}&signature=#{signature}", headers)
  end

  @spec post_binance(String.t(), map) :: {:ok, any} | {:error, http_error | poison_decode_error}
  def post_binance(url, params) do
    argument_string =
      params
      |> Map.to_list()
      |> Enum.map(fn x -> Tuple.to_list(x) |> Enum.join("=") end)
      |> Enum.join("&")

    secret_key = Application.get_env(:binance, :secret_key)
    signature = sign(secret_key, argument_string)
    body = "#{argument_string}&signature=#{signature}"

    case HTTPoison.post("#{@endpoint}#{url}", body, [
           {"X-MBX-APIKEY", Application.get_env(:binance, :api_key)}
         ]) do
      {:ok, response} ->
        case Poison.decode(response.body) do
          {:ok, data} -> {:ok, data}
          {:error, err} -> {:error, {:poison_decode_error, err}}
        end

      {:error, err} ->
        {:error, {:http_error, err}}
    end
  end

  defp sign(secret_key, argument_string),
    do: :sha256 |> :crypto.hmac(secret_key, argument_string) |> Base.encode16()

  defp parse_get_response({:ok, response}) do
    response.body
    |> Poison.decode()
    |> parse_response_body
  end

  defp parse_get_response({:error, err}) do
    {:error, {:http_error, err}}
  end

  defp parse_response_body({:ok, data}) do
    case data do
      %{"code" => _c, "msg" => _m} = error -> {:error, error}
      _ -> {:ok, data}
    end
  end

  defp parse_response_body({:error, err}) do
    {:error, {:poison_decode_error, err}}
  end
end
