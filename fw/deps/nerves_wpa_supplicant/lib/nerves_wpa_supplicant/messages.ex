# Copyright 2014 LKC Technologies, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

defmodule Nerves.WpaSupplicant.Messages do
  require Logger

  def encode(cmd) when is_atom(cmd) do
    to_string(cmd)
  end

  def encode({:"CTRL-RSP-IDENTITY", network_id, string}) do
    "CTRL-RSP-IDENTITY-#{network_id}-#{string}"
  end

  def encode({:"CTRL-RSP-PASSWORD", network_id, string}) do
    "CTRL-RSP-PASSWORD-#{network_id}-#{string}"
  end

  def encode({:"CTRL-RSP-NEW_PASSWORD", network_id, string}) do
    "CTRL-RSP-NEW_PASSWORD-#{network_id}-#{string}"
  end

  def encode({:"CTRL-RSP-PIN", network_id, string}) do
    "CTRL-RSP-PIN-#{network_id}-#{string}"
  end

  def encode({:"CTRL-RSP-OTP", network_id, string}) do
    "CTRL-RSP-OTP-#{network_id}-#{string}"
  end

  def encode({:"CTRL-RSP-PASSPHRASE", network_id, string}) do
    "CTRL-RSP-PASSPHRASE-#{network_id}-#{string}"
  end

  def encode({cmd, arg}) when is_atom(cmd) do
    to_string(cmd) <> " " <> encode_arg(arg)
  end

  def encode({cmd, arg, arg2}) when is_atom(cmd) do
    to_string(cmd) <> " " <> encode_arg(arg) <> " " <> encode_arg(arg2)
  end

  def encode({cmd, arg, arg2, arg3}) when is_atom(cmd) do
    to_string(cmd) <>
      " " <>
      encode_arg(arg) <> " " <> encode_arg(arg2) <> " " <> encode_arg(arg3)
  end

  defp encode_arg(arg) when is_binary(arg) do
    if String.length(arg) == 17 &&
         Regex.match?(
           ~r/[\da-fA-F][\da-fA-F]:[\da-fA-F][\da-fA-F]:[\da-fA-F][\da-fA-F]:[\da-fA-F][\da-fA-F]:[\da-fA-F][\da-fA-F]:[\da-fA-F][\da-fA-F]/,
           arg
         ) do
      # This is a MAC address
      arg
    else
      # This is a string
      "\"" <> arg <> "\""
    end
  end

  defp encode_arg(arg) do
    to_string(arg)
  end

  @doc """
  Decode notifications from the wpa_supplicant
  """
  def decode_notif(<<"CTRL-REQ-", rest::binary>>) do
    [field, net_id, text] = String.split(rest, "-", parts: 3, trim: true)
    {String.to_atom("CTRL-REQ-" <> field), String.to_integer(net_id), text}
  end

  def decode_notif(<<"CTRL-EVENT-BSS-ADDED", rest::binary>>) do
    [entry_id, bssid] = String.split(rest, " ", trim: true)
    {:"CTRL-EVENT-BSS-ADDED", String.to_integer(entry_id), bssid}
  end

  def decode_notif(<<"CTRL-EVENT-BSS-REMOVED", rest::binary>>) do
    [entry_id, bssid] = String.split(rest, " ", trim: true)
    {:"CTRL-EVENT-BSS-REMOVED", String.to_integer(entry_id), bssid}
  end

  # This message is just not shaped the same as others for some reason.
  def decode_notif(<<"CTRL-EVENT-CONNECTED", rest::binary>>) do
    ["-", "Connection", "to", bssid, status | info] = String.split(rest)

    info =
      Regex.scan(~r(\w+=[a-zA-Z0-9:\"_]+), Enum.join(info, " "))
      |> Map.new(fn [str] ->
        [key, val] = String.split(str, "=")
        {String.to_atom(key), kv_value(val)}
      end)

    {:"CTRL-EVENT-CONNECTED", bssid, String.to_atom(status), info}
  end

  def decode_notif(<<"CTRL-EVENT-DISCONNECTED", rest::binary>>) do
    decode_notif_info(:"CTRL-EVENT-DISCONNECTED", rest)
  end

  # "CTRL-EVENT-REGDOM-CHANGE init=CORE"
  def decode_notif(<<"CTRL-EVENT-REGDOM-CHANGE", rest::binary>>) do
    decode_notif_info(:"CTRL-EVENT-REGDOM-CHANGE", rest)
  end

  # "CTRL-EVENT-ASSOC-REJECT bssid=00:00:00:00:00:00 status_code=16"
  def decode_notif(<<"CTRL-EVENT-ASSOC-REJECT", rest::binary>>) do
    decode_notif_info(:"CTRL-EVENT-ASSOC-REJECT", rest)
  end

  # "CTRL-EVENT-SSID-TEMP-DISABLED id=1 ssid=\"FarmbotConnect\" auth_failures=1 duration=10 reason=CONN_FAILED"
  def decode_notif(<<"CTRL-EVENT-SSID-TEMP-DISABLED", rest::binary>>) do
    decode_notif_info(:"CTRL-EVENT-SSID-TEMP-DISABLED", rest)
  end

  # "CTRL-EVENT-SUBNET-STATUS-UPDATE status=0"
  def decode_notif(<<"CTRL-EVENT-SUBNET-STATUS-UPDATE", rest::binary>>) do
    decode_notif_info(:"CTRL-EVENT-SUBNET-STATUS-UPDATE", rest)
  end

  # CTRL-EVENT-SSID-REENABLED id=1 ssid=\"FarmbotConnect\""
  def decode_notif(<<"CTRL-EVENT-SSID-REENABLED", rest::binary>>) do
    decode_notif_info(:"CTRL-EVENT-SSID-REENABLED", rest)
  end

  def decode_notif(<<"CTRL-EVENT-EAP-PEER-CERT", rest::binary>>) do
    info =
      rest
      |> String.trim()
      |> String.split(" ")
      |> Map.new(fn str ->
        [key, val] = String.split(str, "=", parts: 2)
        {String.to_atom(key), kv_value(val)}
      end)

    {:"CTRL-EVENT-EAP-PEER-CERT", info}
  end

  def decode_notif(<<"CTRL-EVENT-EAP-STATUS", rest::binary>>) do
    info =
      Regex.scan(~r/\w+=(["'])(?:(?=(\\?))\2.)*?\1/, rest)
      |> Map.new(fn [str | _] ->
        [key, val] = String.split(str, "=", parts: 2)
        {String.to_atom(key), kv_value(val)}
      end)

    {:"CTRL-EVENT-EAP-STATUS", info}
  end

  def decode_notif(<<"CTRL-EVENT-EAP-FAILURE", rest::binary>>) do
    {:"CTRL-EVENT-EAP-FAILURE", String.trim(rest)}
  end

  def decode_notif(<<"CTRL-EVENT-EAP-METHOD", rest::binary>>) do
    {:"CTRL-EVENT-EAP-METHOD", String.trim(rest)}
  end

  def decode_notif(<<"CTRL-EVENT-EAP-PROPOSED-METHOD", rest::binary>>) do
    decode_notif_info(:"CTRL-EVENT-EAP-PROPOSED-METHOD", rest)
  end

  def decode_notif(<<"CTRL-EVENT-", _type::binary>> = event) do
    event |> String.trim_trailing() |> String.to_atom()
  end

  def decode_notif(<<"WPS-", _type::binary>> = event) do
    event |> String.trim_trailing() |> String.to_atom()
  end

  def decode_notif(<<"AP-STA-CONNECTED ", mac::binary>>) do
    {:"AP-STA-CONNECTED", String.trim_trailing(mac)}
  end

  def decode_notif(<<"AP-STA-DISCONNECTED ", mac::binary>>) do
    {:"AP-STA-DISCONNECTED", String.trim_trailing(mac)}
  end

  def decode_notif(string) do
    {:INFO, String.trim_trailing(string)}
  end

  defp decode_notif_info(event, rest) do
    info =
      Regex.scan(~r(\w+=[\S*]+), rest)
      |> Map.new(fn [str] ->
        str = String.replace(str, "\'", "")
        [key, val] = String.split(str, "=", parts: 2)
        {String.to_atom(key), kv_value(val)}
      end)

    case Map.split(info, [:bssid]) do
      {%{bssid: bssid}, info} when is_binary(bssid) -> {event, bssid, info}
      {_, info} -> {event, info}
    end
  end

  @doc """
  Decode responses from the wpa_supplicant

  The decoding of a response depends on the request, so pass the request as
  the first argument and the response as the second one.
  """
  def decode_resp(req, resp) do
    # Strip the response of whitespace before trying to parse it.
    tresp(req, String.trim(resp))
  end

  defp tresp(:PING, "PONG"), do: :PONG
  defp tresp(:MIB, resp), do: kv_resp(resp)
  defp tresp(:STATUS, resp), do: kv_resp(resp)
  defp tresp(:"STATUS-VERBOSE", resp), do: kv_resp(resp)
  defp tresp({:BSS, _}, ""), do: nil
  defp tresp({:BSS, _}, resp), do: kv_resp(resp)
  defp tresp(:INTERFACES, resp), do: String.split(resp, "\n")
  defp tresp(:ADD_NETWORK, netid), do: String.to_integer(netid)
  defp tresp(_, "OK"), do: :ok
  defp tresp(_, "FAIL"), do: :FAIL

  defp tresp(_, <<"\"", string::binary>>),
    do: String.trim_trailing(string, "\"")

  defp tresp(_, resp), do: resp

  defp kv_resp(resp) do
    resp
    |> String.split("\n", trim: true)
    |> List.foldl(%{}, fn pair, acc ->
      case String.split(pair, "=") do
        [key, value] ->
          acc
          |> Map.put(String.to_atom(key), kv_value(String.trim_trailing(value)))

        _ ->
          Logger.debug([
            "Failed to decode response: ",
            inspect(resp, limit: :infinity)
          ])

          acc
      end
    end)
  end

  defp kv_value("TRUE"), do: true
  defp kv_value("FALSE"), do: false
  defp kv_value(""), do: nil
  defp kv_value(<<"\"", _::binary>> = msg), do: String.trim(msg, "\"")
  defp kv_value(<<"\'", _::binary>> = msg), do: String.trim(msg, "\'")
  defp kv_value(<<"0x", hex::binary>>), do: kv_value(hex, 16)
  defp kv_value(str), do: kv_value(str, 10)

  defp kv_value(value, base) do
    try do
      String.to_integer(value, base)
    rescue
      ArgumentError -> value
    end
  end
end
