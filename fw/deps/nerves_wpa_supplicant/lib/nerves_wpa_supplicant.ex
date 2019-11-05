# Copyright 2016 Frank Hunleth
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

defmodule Nerves.WpaSupplicant do
  use GenServer
  require Logger

  alias Nerves.WpaSupplicant.Messages

  defstruct port: nil,
            ifname: nil,
            requests: []

  @doc """
  Start and link a Nerves.WpaSupplicant that uses the specified control
  socket.
  """
  def start_link(ifname, control_socket_path, opts \\ []) do
    GenServer.start_link(__MODULE__, {ifname, control_socket_path}, opts)
  end

  @doc """
  Stop the Nerves.WpaSupplicant control interface
  """
  def stop(pid) do
    GenServer.stop(pid)
  end

  @doc """
  Send a request to the wpa_supplicant.

  ## Example

      iex> Nerves.WpaSupplicant.request(pid, :PING)
      :PONG
  """
  def request(pid, command) do
    GenServer.call(pid, {:request, command})
  end

  @doc """
  Get the interface name from the wpa_supplicant state
  """
  def ifname(pid) do
    GenServer.call(pid, :ifname)
  end

  @doc """
  Return the current status of the wpa_supplicant. It wraps the
  STATUS command.
  """
  def status(pid) do
    request(pid, :STATUS)
  end

  @doc """
  Tell the wpa_supplicant to connect to the specified network. Invoke
  like this:

      iex> Nerves.WpaSupplicant.set_network(pid, ssid: "MyNetworkSsid", key_mgmt: :WPA_PSK, psk: "secret")

  or like this:

      iex> Nerves.WpaSupplicant.set_network(pid, %{ssid: "MyNetworkSsid", key_mgmt: :WPA_PSK, psk: "secret"})

  Many options are supported, but it is likely that `ssid` and `psk` are
  the most useful. The full list can be found in the wpa_supplicant
  documentation. Here's a list of some common ones:

      Option                | Description
      ----------------------|------------
      :ssid                 | Network name. This is mandatory.
      :key_mgmt             | The security in use. This is mandatory. Set to :NONE, :WPA_PSK
      :proto                | Protocol use use. E.g., :WPA2
      :psk                  | WPA preshared key. 8-63 chars or the 64 char one as processed by `wpa_passphrase`
      :bssid                | Optional BSSID. If set, only associate with the AP with a matching BSSID
      :mode                 | Mode: 0 = infrastructure (default), 1 = ad-hoc, 2 = AP
      :frequency            | Channel frequency. e.g., 2412 for 802.11b/g channel 1
      :wep_key0..3          | Static WEP key
      :wep_tx_keyidx        | Default WEP key index (0 to 3)
      :priority             | Integer priority of the network where higher number is higher priority

  Note that this is a helper function that wraps several low-level calls and
  is limited to specifying only one network at a time. If you'd
  like to register multiple networks with the supplicant, use add_network.

  Returns `:ok` or `{:error, key, reason}` if a key fails to set.
  """
  def set_network(pid, options) when is_map(options),
    do: set_network(pid, Map.to_list(options))

  def set_network(pid, options) do
    # Don't worry if the following fails. We just need to
    # make sure that no other networks registered with the
    # wpa_supplicant take priority over ours
    remove_all_networks(pid)

    case add_network(pid, options) do
      {:ok, netid} ->
        # Everything succeeded -> select the network
        request(pid, {:SELECT_NETWORK, netid})

      error ->
        # Something failed, so return the error
        error
    end
  end

  @doc """
  Tell the wpa_supplicant to add and enable the specified network. Invoke like
  this:

  iex> Nerves.WpaSupplicant.add_network(pid, ssid: "MyNetworkSsid", key_mgmt: :WPA_PSK, psk: "secret")

  or like this:

  iex> Nerves.WpaSupplicant.add_network(pid, %{ssid: "MyNetworkSsid", key_mgmt: :WPA_PSK, psk: "secret"})

  For common options, see `set_network/2`.

  Returns `{:ok, netid}` or `{:error, key, reason}` if a key fails to set.
  """
  def add_network(pid, options) when is_map(options),
    do: add_network(pid, Map.to_list(options))

  def add_network(pid, options) do
    netid = request(pid, :ADD_NETWORK)

    with :ok <- set_network_kvlist(pid, netid, options, {:none, :ok}),
         :ok <- request(pid, {:ENABLE_NETWORK, netid}) do
      {:ok, netid}
    else
      error -> error
    end
  end

  @doc """
  Removes all configured networks.

  Returns `:ok` or `{:error, key, reason}` if an error is encountered.
  """
  def remove_all_networks(pid) do
    request(pid, {:REMOVE_NETWORK, :all})
  end

  @doc """
  According to the docs, this forces a reassociation to the current access
  point, but in practice it causes the supplicant to go through the network list
  in priority order, connecting to the highest priority access point available.
  """
  def reassociate(pid) do
    request(pid, :REASSOCIATE)
  end

  defp set_network_kvlist(pid, netid, [{key, value} | tail], {_, :ok}) do
    rc = request(pid, {:SET_NETWORK, netid, key, value})
    set_network_kvlist(pid, netid, tail, {key, rc})
  end

  defp set_network_kvlist(_pid, _netid, [], {_, :ok}), do: :ok

  defp set_network_kvlist(_pid, _netid, _kvpairs, {key, rc}) do
    {:error, key, rc}
  end

  @doc """
  This is a helper function that will initiate a scan, wait for the
  scan to complete and return a list of all of the available access
  points. This can take a while if the wpa_supplicant hasn't scanned
  for access points recently.
  """
  def scan(pid) do
    ifname = ifname(pid)
    Logger.debug("Scanning: #{ifname}")
    {:ok, _} = Registry.register(Nerves.WpaSupplicant, ifname, [])

    case request(pid, :SCAN) do
      :ok ->
        :ok

      # If the wpa_supplicant is already scanning, FAIL-BUSY is
      # returned.
      "FAIL-BUSY" ->
        :ok
    end

    :ok = wait_for_scan(ifname)
    :ok = Registry.unregister(Nerves.WpaSupplicant, ifname)
    # Collect all BSSs
    all_bss(pid, 0, [])
  end

  defp wait_for_scan(ifname) do
    receive do
      {Nerves.WpaSupplicant, :"CTRL-EVENT-SCAN-RESULTS", %{ifname: ^ifname}} ->
        Logger.debug("Got all scan results")
        :ok

      other ->
        Logger.debug("Waiting for more scan results, got #{inspect(other)}")
        wait_for_scan(ifname)
    after
      5000 ->
        Logger.debug("Timed out scanning!")
        :timeout
    end
  end

  defp all_bss(pid, count, acc) do
    Logger.debug("Calling :BSS - #{count}")
    result = request(pid, {:BSS, count})
    Logger.debug(":BSS Result #{count}: #{inspect(result)}")

    if result do
      all_bss(pid, count + 1, [result | acc])
    else
      acc
    end
  end

  def init({ifname, control_socket_path}) do
    executable = :code.priv_dir(:nerves_wpa_supplicant) ++ '/wpa_ex'

    port =
      Port.open({:spawn_executable, executable}, [
        {:args, [control_socket_path]},
        {:packet, 2},
        :binary,
        :exit_status
      ])

    {:ok, %Nerves.WpaSupplicant{port: port, ifname: ifname}}
  end

  def handle_call({:request, command}, from, state) do
    payload = Messages.encode(command)
    Logger.info("Nerves.WpaSupplicant: sending '#{payload}'")
    send(state.port, {self(), {:command, payload}})
    state = %{state | :requests => state.requests ++ [{from, command}]}
    {:noreply, state}
  end

  def handle_call(:ifname, _from, state) do
    {:reply, state.ifname, state}
  end

  def handle_info({_, {:data, message}}, state) do
    handle_wpa(message, state)
  end

  def handle_info({_, {:exit_status, _}}, state) do
    {:stop, :unexpected_exit, state}
  end

  defp handle_wpa(<<"<", _priority::utf8, ">", notification::binary>>, state) do
    decoded_notif = Messages.decode_notif(notification)

    Registry.dispatch(Nerves.WpaSupplicant, state.ifname, fn entries ->
      for {pid, _} <- entries,
          do:
            send(
              pid,
              {Nerves.WpaSupplicant, decoded_notif, %{ifname: state.ifname}}
            )
    end)

    {:noreply, state}
  end

  defp handle_wpa(response, state) do
    [{client, command} | next_ones] = state.requests
    state = %{state | :requests => next_ones}

    decoded_response = Messages.decode_resp(command, response)
    GenServer.reply(client, decoded_response)
    {:noreply, state}
  end
end
