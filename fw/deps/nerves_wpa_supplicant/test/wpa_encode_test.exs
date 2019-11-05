defmodule WpaEncodeTest do
  use ExUnit.Case

  alias Nerves.WpaSupplicant.Messages

  test "interactive" do
    assert Messages.encode({:"CTRL-RSP-IDENTITY", 1, "response text"}) ==
             "CTRL-RSP-IDENTITY-1-response text"

    assert Messages.encode({:"CTRL-RSP-PASSWORD", 1, "response text"}) ==
             "CTRL-RSP-PASSWORD-1-response text"

    assert Messages.encode({:"CTRL-RSP-NEW_PASSWORD", 1, "response text"}) ==
             "CTRL-RSP-NEW_PASSWORD-1-response text"

    assert Messages.encode({:"CTRL-RSP-PIN", 1, "response text"}) ==
             "CTRL-RSP-PIN-1-response text"

    assert Messages.encode({:"CTRL-RSP-OTP", 1, "response text"}) ==
             "CTRL-RSP-OTP-1-response text"

    assert Messages.encode({:"CTRL-RSP-PASSPHRASE", 1, "response text"}) ==
             "CTRL-RSP-PASSPHRASE-1-response text"
  end

  test "commands" do
    assert Messages.encode(:PING) == "PING"
    assert Messages.encode(:MIB) == "MIB"
    assert Messages.encode(:STATUS) == "STATUS"
    assert Messages.encode(:"STATUS-VERBOSE") == "STATUS-VERBOSE"
    assert Messages.encode(:PMKSA) == "PMKSA"
    assert Messages.encode({:SET, :int_variable, 5}) == "SET int_variable 5"

    assert Messages.encode({:SET, :string_variable, "string"}) ==
             "SET string_variable \"string\""

    assert Messages.encode(:LOGON) == "LOGON"
    assert Messages.encode(:LOGOFF) == "LOGOFF"
    assert Messages.encode(:REASSOCIATE) == "REASSOCIATE"
    assert Messages.encode(:RECONNECT) == "RECONNECT"

    assert Messages.encode({:PREAUTH, "00:09:5b:95:e0:4e"}) ==
             "PREAUTH 00:09:5b:95:e0:4e"

    assert Messages.encode(:ATTACH) == "ATTACH"
    assert Messages.encode(:DETACH) == "DETACH"
    assert Messages.encode({:LEVEL, 4}) == "LEVEL 4"
    assert Messages.encode(:RECONFIGURE) == "RECONFIGURE"
    assert Messages.encode(:TERMINATE) == "TERMINATE"

    assert Messages.encode({:BSSID, 1, "00:09:5b:95:e0:4e"}) ==
             "BSSID 1 00:09:5b:95:e0:4e"

    assert Messages.encode(:LIST_NETWORKS) == "LIST_NETWORKS"
    assert Messages.encode(:DISCONNECT) == "DISCONNECT"
    assert Messages.encode(:SCAN) == "SCAN"
    assert Messages.encode(:SCAN_RESULTS) == "SCAN_RESULTS"
    assert Messages.encode({:BSS, 4}) == "BSS 4"
    assert Messages.encode({:SELECT_NETWORK, 1}) == "SELECT_NETWORK 1"
    assert Messages.encode({:ENABLE_NETWORK, 1}) == "ENABLE_NETWORK 1"
    assert Messages.encode({:DISABLE_NETWORK, 1}) == "DISABLE_NETWORK 1"
    assert Messages.encode(:ADD_NETWORK) == "ADD_NETWORK"

    assert Messages.encode({:SET_NETWORK, 1, :ssid, "SSID"}) ==
             "SET_NETWORK 1 ssid \"SSID\""

    assert Messages.encode({:SET_NETWORK, 1, :psk, "SSID"}) ==
             "SET_NETWORK 1 psk \"SSID\""

    assert Messages.encode({:SET_NETWORK, 1, :key_mgmt, "SSID"}) ==
             "SET_NETWORK 1 key_mgmt \"SSID\""

    assert Messages.encode({:SET_NETWORK, 1, :identity, "SSID"}) ==
             "SET_NETWORK 1 identity \"SSID\""

    assert Messages.encode({:SET_NETWORK, 1, :password, "SSID"}) ==
             "SET_NETWORK 1 password \"SSID\""

    assert Messages.encode({:GET_NETWORK, 1, :ssid}) == "GET_NETWORK 1 ssid"
    assert Messages.encode(:SAVE_CONFIG) == "SAVE_CONFIG"
    assert Messages.encode(:P2P_FIND) == "P2P_FIND"
    assert Messages.encode(:P2P_STOP_FIND) == "P2P_STOP_FIND"
    assert Messages.encode(:P2P_CONNECT) == "P2P_CONNECT"
    assert Messages.encode(:P2P_LISTEN) == "P2P_LISTEN"
    assert Messages.encode(:P2P_GROUP_REMOVE) == "P2P_GROUP_REMOVE"
    assert Messages.encode(:P2P_GROUP_ADD) == "P2P_GROUP_ADD"
    assert Messages.encode(:P2P_PROV_DISC) == "P2P_PROV_DISC"
    assert Messages.encode(:P2P_GET_PASSPHRASE) == "P2P_GET_PASSPHRASE"
    assert Messages.encode(:P2P_SERV_DISC_REQ) == "P2P_SERV_DISC_REQ"

    assert Messages.encode(:P2P_SERV_DISC_CANCEL_REQ) ==
             "P2P_SERV_DISC_CANCEL_REQ"

    assert Messages.encode(:P2P_SERV_DISC_RESP) == "P2P_SERV_DISC_RESP"
    assert Messages.encode(:P2P_SERVICE_UPDATE) == "P2P_SERVICE_UPDATE"
    assert Messages.encode(:P2P_SERV_DISC_EXTERNAL) == "P2P_SERV_DISC_EXTERNAL"
    assert Messages.encode(:P2P_REJECT) == "P2P_REJECT"
    assert Messages.encode(:P2P_INVITE) == "P2P_INVITE"
    assert Messages.encode(:P2P_PEER) == "P2P_PEER"
    assert Messages.encode(:P2P_EXT_LISTEN) == "P2P_EXT_LISTEN"
  end
end
